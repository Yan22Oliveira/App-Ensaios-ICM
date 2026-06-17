import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../src.dart' show IUserProfileRepository, IAuthRepository, UserProfile;

part 'profile_state.dart';

class ProfileController extends Cubit<ProfileState> {
  final IUserProfileRepository _profiles;
  final IAuthRepository _auth;

  StreamSubscription<UserProfile?>? _profileSub;

  ProfileController({
    required IUserProfileRepository profiles,
    required IAuthRepository auth,
  })  : _profiles = profiles,
        _auth = auth,
        super(const ProfileState.loading()) {
    _watch();
  }

  void _watch() {
    emit(const ProfileState.loading());
    _profileSub?.cancel();
    _profileSub = _profiles.watchCurrent().listen((profile) {
      if (profile == null) {
        emit(const ProfileState.error('Perfil não encontrado ou inativo.'));
      } else {
        emit(ProfileState.loaded(profile));
      }
    }, onError: (e) {
      emit(ProfileState.error(e.toString()));
    });
  }

  Future<void> saveEdits({required String displayName, String? phone}) async {
    emit(state.copy(working: true));
    try {
      await _profiles.updateCurrent({
        'displayName': displayName.trim(),
        'phone': (phone ?? '').trim().isEmpty ? null : phone!.trim(),
      });
      emit(state.copy(working: false));
    } catch (e) {
      emit(state.copy(working: false, errorMessage: e.toString()));
    }
  }

  /// Usa o metodo padronizado do IAuthRepository.
  Future<void> sendPasswordReset() async {
    final email = state.profile?.email;
    if (email == null || email.isEmpty) return;
    await _auth.sendPasswordResetEmail(email);
  }

  Future<void> signOut() => _auth.signOut();

  @override
  Future<void> close() {
    _profileSub?.cancel();
    return super.close();
  }
}
