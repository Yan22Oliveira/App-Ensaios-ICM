part of 'auth_controller.dart';

class AuthState extends Equatable {
  final bool loading;
  final UserProfile? profile;
  final bool isSignedOut;
  final bool isAwaitingApproval;
  final String? errorMessage;

  const AuthState({
    required this.loading,
    required this.profile,
    required this.isSignedOut,
    required this.isAwaitingApproval,
    this.errorMessage,
  });

  const AuthState.unknown()
      : loading = false,
        profile = null,
        isSignedOut = true,
        isAwaitingApproval = false,
        errorMessage = null;

  const AuthState.loading()
      : loading = true,
        profile = null,
        isSignedOut = false,
        isAwaitingApproval = false,
        errorMessage = null;

  const AuthState.signedOut()
      : loading = false,
        profile = null,
        isSignedOut = true,
        isAwaitingApproval = false,
        errorMessage = null;

  const AuthState.awaitingApproval()
      : loading = false,
        profile = null,
        isSignedOut = false,
        isAwaitingApproval = true,
        errorMessage = null;

  const AuthState.signedIn(this.profile)
      : loading = false,
        isSignedOut = false,
        isAwaitingApproval = false,
        errorMessage = null;

  const AuthState.error(this.errorMessage)
      : loading = false,
        profile = null,
        isSignedOut = true,
        isAwaitingApproval = false;

  @override
  List<Object?> get props =>
      [loading, profile?.uid, isSignedOut, isAwaitingApproval, errorMessage];
}
