import 'package:cloud_firestore/cloud_firestore.dart';

/// Status de uma solicitação de acesso.
enum AccessStatus { pending, approved, rejected }

String accessStatusToString(AccessStatus s) {
  switch (s) {
    case AccessStatus.pending:  return 'pending';
    case AccessStatus.approved: return 'approved';
    case AccessStatus.rejected: return 'rejected';
  }
}

AccessStatus accessStatusFromString(String? s) {
  switch ((s ?? '').toLowerCase()) {
    case 'approved': return AccessStatus.approved;
    case 'rejected': return AccessStatus.rejected;
    default:         return AccessStatus.pending;
  }
}

class AccessRequest {
  final String id;                // docId (ideal = requesterUid)
  final String requesterUid;      // uid do usuário solicitante
  final String email;
  final String displayName;
  final String? phone;

  final AccessStatus status;      // pending | approved | rejected
  final DateTime? createdAt;
  final DateTime? decidedAt;      // quando foi aprovada/rejeitada
  final String? decidedBy;        // quem decidiu (email/uid do admin)
  final String? reason;           // motivo (para rejeição, opcional)

  AccessRequest({
    required this.id,
    required this.requesterUid,
    required this.email,
    required this.displayName,
    this.phone,
    required this.status,
    this.createdAt,
    this.decidedAt,
    this.decidedBy,
    this.reason,
  });

  // Conveniências
  bool get isPending  => status == AccessStatus.pending;
  bool get isApproved => status == AccessStatus.approved;
  bool get isRejected => status == AccessStatus.rejected;

  // ---------- Firestore mappers ----------

  factory AccessRequest.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const <String, dynamic>{};
    return AccessRequest(
      id: doc.id,
      requesterUid: (d['requesterUid'] as String? ?? '').trim(),
      email:        (d['email']        as String? ?? '').trim(),
      displayName:  (d['displayName']  as String? ?? '').trim(),
      phone: d['phone'] as String?,
      status: accessStatusFromString(d['status'] as String?),
      createdAt: (d['createdAt'] is Timestamp)
          ? (d['createdAt'] as Timestamp).toDate()
          : null,
      decidedAt: (d['decidedAt'] is Timestamp)
          ? (d['decidedAt'] as Timestamp).toDate()
          : null,
      decidedBy: d['decidedBy'] as String?,
      reason: d['reason'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'requesterUid': requesterUid,
      'email': email.trim(),
      'displayName': displayName.trim(),
      if (phone != null) 'phone': phone,
      'status': accessStatusToString(status),
      if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
      if (decidedAt != null) 'decidedAt': Timestamp.fromDate(decidedAt!),
      if (decidedBy != null) 'decidedBy': decidedBy,
      if (reason != null && reason!.trim().isNotEmpty) 'reason': reason!.trim(),
    };
  }

  AccessRequest copyWith({
    String? id,
    String? requesterUid,
    String? email,
    String? displayName,
    String? phone,
    AccessStatus? status,
    DateTime? createdAt,
    DateTime? decidedAt,
    String? decidedBy,
    String? reason,
  }) {
    return AccessRequest(
      id: id ?? this.id,
      requesterUid: requesterUid ?? this.requesterUid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      phone: phone ?? this.phone,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      decidedAt: decidedAt ?? this.decidedAt,
      decidedBy: decidedBy ?? this.decidedBy,
      reason: reason ?? this.reason,
    );
  }
}
