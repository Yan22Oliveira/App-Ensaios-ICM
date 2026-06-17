import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../domain/models/access_request.dart';
import '../../domain/models/user_profile.dart';
import '../../domain/repositories/i_access_request_repository.dart';

part 'access_requests_state.dart';

class AccessRequestsController extends Cubit<AccessRequestsState> {
  final IAccessRequestRepository _repo;
  StreamSubscription<List<AccessRequest>>? _sub;

  AccessRequestsController({required IAccessRequestRepository repo})
      : _repo = repo,
        super(const AccessRequestsState.loading()) {
    _watch();
  }

  void _watch() {
    _sub?.cancel();
    _sub = _repo.watchPending().listen((list) {
      emit(AccessRequestsState.loaded(requests: list));
    }, onError: (e) {
      emit(AccessRequestsState.error(e.toString()));
    });
  }

  Future<void> approve({
    required String requestId,
    required UserRole role,
    String? regionId,
    String? areaId,
    String? poloId,
  }) async {
    emit(state.copy(working: true));
    try {
      await _repo.approve(
        requestId: requestId,
        role: role,
        regionId: regionId,
        areaId: areaId,
        poloId: poloId,
      );
      emit(state.copy(working: false));
    } catch (e) {
      emit(state.copy(working: false, errorMessage: e.toString()));
    }
  }

  Future<void> reject({required String requestId, String? reason}) async {
    emit(state.copy(working: true));
    try {
      await _repo.reject(requestId: requestId, reason: reason);
      emit(state.copy(working: false));
    } catch (e) {
      emit(state.copy(working: false, errorMessage: e.toString()));
    }
  }

  @override
  Future<void> close() {
    _sub?.cancel();
    return super.close();
  }
}
