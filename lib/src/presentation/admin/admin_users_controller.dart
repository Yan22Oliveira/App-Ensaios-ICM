import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../src.dart';

class AdminUsersState extends Equatable {
  final bool loading;
  final List<UserProfile> users;
  final Set<String> missingProfileUids;
  final String search;
  final String? errorMessage;

  const AdminUsersState({
    required this.loading,
    required this.users,
    required this.missingProfileUids,
    required this.search,
    this.errorMessage,
  });

  factory AdminUsersState.initial() => const AdminUsersState(
        loading: true,
        users: [],
        missingProfileUids: {},
        search: '',
      );

  List<UserProfile> get visible {
    final q = search.trim().toLowerCase();
    if (q.isEmpty) return users;
    return users.where((u) {
      return u.displayName.toLowerCase().contains(q) ||
          u.email.toLowerCase().contains(q) ||
          u.role.label.toLowerCase().contains(q);
    }).toList();
  }

  bool isMissingProfile(String uid) => missingProfileUids.contains(uid);

  AdminUsersState copyWith({
    bool? loading,
    List<UserProfile>? users,
    Set<String>? missingProfileUids,
    String? search,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AdminUsersState(
      loading: loading ?? this.loading,
      users: users ?? this.users,
      missingProfileUids: missingProfileUids ?? this.missingProfileUids,
      search: search ?? this.search,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [loading, users, missingProfileUids, search, errorMessage];
}

class AdminUsersController extends Cubit<AdminUsersState> {
  final IUserProfileRepository profiles;
  final IAccessRequestRepository requests;

  AdminUsersController({
    required this.profiles,
    required this.requests,
  }) : super(AdminUsersState.initial());

  Future<void> load() async {
    emit(state.copyWith(loading: true, clearError: true));
    try {
      List<UserProfile> fromCollection = const [];
      try {
        fromCollection = await profiles.listAll();
      } catch (_) {}

      List<AccessRequest> accessRequests = const [];
      try {
        accessRequests = await requests.listAll();
      } catch (_) {
        try {
          accessRequests = await requests.listApproved();
        } catch (_) {}
      }

      final byUid = {for (final u in fromCollection) u.uid: u};
      final missing = <String>{};

      for (final req in accessRequests) {
        final uid = req.requesterUid.isNotEmpty ? req.requesterUid : req.id;
        if (uid.isEmpty || byUid.containsKey(uid)) continue;
        final existing = await profiles.getById(uid);
        if (existing != null) {
          byUid[uid] = existing;
        } else if (req.isApproved) {
          missing.add(uid);
          byUid[uid] = UserProfile(
            uid: uid,
            displayName: req.displayName,
            email: req.email,
            role: UserRole.readonly,
            active: false,
            phone: req.phone,
          );
        }
      }

      emit(state.copyWith(
        loading: false,
        users: byUid.values.toList()..sort(_byName),
        missingProfileUids: missing,
        clearError: true,
      ));
    } catch (e) {
      emit(state.copyWith(
        loading: false,
        errorMessage: 'Não foi possível carregar os usuários.',
      ));
    }
  }

  void search(String value) => emit(state.copyWith(search: value));

  void replace(UserProfile profile) {
    final next = state.users.map((u) => u.uid == profile.uid ? profile : u).toList()
      ..sort(_byName);
    final missing = Set<String>.from(state.missingProfileUids)..remove(profile.uid);
    emit(state.copyWith(users: next, missingProfileUids: missing));
  }

  int _byName(UserProfile a, UserProfile b) {
    final an = (a.displayName.isEmpty ? a.email : a.displayName).toLowerCase();
    final bn = (b.displayName.isEmpty ? b.email : b.displayName).toLowerCase();
    return an.compareTo(bn);
  }
}
