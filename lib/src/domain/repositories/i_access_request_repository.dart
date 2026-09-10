import '../models/access_request.dart';
import '../models/user_profile.dart';

/// Contrato para ler/criar/decidir solicitações de acesso.
abstract class IAccessRequestRepository {
  // ====== Solicitante (usuário comum) ======

  /// Envia/atualiza a solicitação de acesso do usuário.
  /// Sugestão: usar `requestId == requesterUid` como docId.
  Future<void> submit({
    required String requesterUid,
    required String email,
    required String displayName,
    String? phone,
  });

  /// Busca a solicitação do próprio usuário (se existir).
  Future<AccessRequest?> findByRequesterUid(String requesterUid);

  /// Observa em tempo real a solicitação do próprio usuário.
  Stream<AccessRequest?> watchMine(String requesterUid);

  // ====== Admin / Maanaim ======

  /// Stream com as solicitações pendentes (para admin/maanaim).
  Stream<List<AccessRequest>> watchPending({int? limit});

  /// Solicitações já aprovadas (para reconciliar com `users`).
  Future<List<AccessRequest>> listApproved();

  /// Todas as solicitações (qualquer status).
  Future<List<AccessRequest>> listAll();

  /// Contador reativo de pendências (para badge na Home).
  Stream<int> watchPendingCount();

  /// Aprova a solicitação e cria/atualiza users/{uid} com papel/escopo.
  /// `decidedBy` deve ser preenchido com quem aprovou (uid/email do admin).
  Future<void> approve({
    required String requestId,
    required UserRole role,
    String? regionId,
    String? areaId,
    String? poloId,
    String? decidedBy,
  });

  /// Reprova a solicitação com um motivo opcional.
  /// `decidedBy` deve ser preenchido com quem rejeitou.
  Future<void> reject({
    required String requestId,
    String? reason,
    String? decidedBy,
  });
}
