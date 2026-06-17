import '../models/user_profile.dart';

abstract class IUserProfileRepository {
  /// Lê uma vez o perfil do usuário logado (ou null se ausente).
  Future<UserProfile?> getCurrent();

  /// Stream do perfil do usuário logado (null se doc inexistente/inativo).
  Stream<UserProfile?> watchCurrent();

  /// Atualiza campos do perfil do usuário logado (admin pode atualizar outros via data layer dedicado).
  Future<void> updateCurrent(Map<String, dynamic> patch);

  /// (Opcional) Cria pedido de acesso para onboarding por aprovação.
  Future<void> createAccessRequest({
    required String email,
    required String displayName,
    String? phone,
  });
}
