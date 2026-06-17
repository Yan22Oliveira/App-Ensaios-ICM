import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../domain/models/user_profile.dart';
import '../../domain/repositories/i_auth_repository.dart';
import '../../domain/repositories/i_user_profile_repository.dart';

part 'auth_state.dart';

class AuthController extends Cubit<AuthState> {
  final IAuthRepository _authRepo;
  final IUserProfileRepository _profiles;

  StreamSubscription<String?>? _authSub;            // <- uid stream
  StreamSubscription<UserProfile?>? _profileSub;

  AuthController({
    required IAuthRepository authRepo,
    required IUserProfileRepository profiles,
  })  : _authRepo = authRepo,
        _profiles = profiles,
        super(const AuthState.unknown()) {
    _observeAuth();
  }

  void _observeAuth() {
    _authSub?.cancel();
    _authSub = _authRepo.authStateChanges().listen((uid) {
      _profileSub?.cancel();

      if (uid == null) {
        emit(const AuthState.signedOut());
        return;
      }

      emit(const AuthState.loading());

      _profileSub = _profiles.watchCurrent().listen((profile) {
        if (profile == null || !profile.active) {
          emit(const AuthState.awaitingApproval());
        } else {
          emit(AuthState.signedIn(profile));
        }
      }, onError: (e) {
        emit(AuthState.error(e.toString()));
      });
    });
  }

  Future<void> signInWithEmail(String email, String password) async {
    emit(const AuthState.loading());
    try {
      await _authRepo.signInWithEmail(email: email, password: password);
      // Após login, o fluxo continua pelo stream de auth.
    } on FirebaseAuthException catch (e) {
      final msg = _authErrorMessage(e);
      emit(AuthState.error(msg));
    } catch (e) {
      emit(AuthState.error(e.toString()));
    }
  }

  static String _authErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-credential':
      case 'invalid-email':
      case 'user-not-found':
      case 'wrong-password':
        return 'E-mail ou senha incorretos. Verifique e tente novamente.';
      case 'user-disabled':
        return 'Esta conta foi desativada.';
      case 'too-many-requests':
        return 'Muitas tentativas. Tente novamente mais tarde.';
      case 'network-request-failed':
        return 'Sem conexão. Verifique sua internet.';
      default:
        return e.message ?? e.code;
    }
  }

  /// Mantém o nome usado na UI, delegando para o método do repositório.
  Future<void> sendPasswordReset(String email) {
    return _authRepo.sendPasswordResetEmail(email);
  }

  Future<void> signOut() => _authRepo.signOut();

  @override
  Future<void> close() {
    _authSub?.cancel();
    _profileSub?.cancel();
    return super.close();
  }
}
