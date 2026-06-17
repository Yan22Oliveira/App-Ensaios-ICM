abstract class IAuthRepository {
  /// Fluxo com mudanças no estado de autenticação (userId ou null).
  Stream<String?> authStateChanges();

  /// Retorna o userId atual ou null.
  String? get currentUserId;

  /// Login com e-mail/senha.
  Future<String> signInWithEmail({
    required String email,
    required String password,
  });

  /// Cadastro com e-mail/senha.
  Future<String> signUpWithEmail({
    required String email,
    required String password,
  });

  /// Envia e-mail de redefinição de senha (não falha se o e-mail não existir).
  Future<void> sendPasswordResetEmail(String email);

  /// Logout.
  Future<void> signOut();

}