import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../domain/models/access_request.dart';
import '../domain/models/user_profile.dart'; // UserRole
import '../domain/repositories/i_access_request_repository.dart';

class FirestoreAccessRequestRepository implements IAccessRequestRepository {
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  FirestoreAccessRequestRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('accessRequests');

  // ---------- mapeamento ----------
  AccessRequest _fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    final statusStr = (d['status'] as String?) ?? 'pending';
    final status = switch (statusStr) {
      'approved' => AccessStatus.approved,
      'rejected' => AccessStatus.rejected,
      _ => AccessStatus.pending,
    };

    return AccessRequest(
      id: doc.id,
      requesterUid: (d['requesterUid'] as String? ?? '').trim(),
      email: (d['email'] as String? ?? '').trim(),
      displayName: (d['displayName'] as String? ?? '').trim(),
      phone: d['phone'] as String?,
      status: status,
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

  // =========================================================
  // Solicitante (usuário comum)
  // =========================================================

  @override
  Future<void> submit({
    required String requesterUid,
    required String email,
    required String displayName,
    String? phone,
  }) async {
    final ref = _col.doc(requesterUid); // docId = requesterUid
    await ref.set({
      'requesterUid': requesterUid,
      'email': email.trim(),
      'displayName': displayName.trim(),
      'phone': (phone ?? '').trim().isEmpty ? null : phone!.trim(),
      'status': 'pending',
      'reason': null,
      'decidedBy': null,
      'decidedAt': null,
      // createdAt só na criação (merge mantém o valor existente)
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Future<AccessRequest?> findByRequesterUid(String requesterUid) async {
    final snap = await _col.doc(requesterUid).get();
    if (!snap.exists || snap.data() == null) return null;
    return _fromDoc(snap);
  }

  @override
  Stream<AccessRequest?> watchMine(String requesterUid) {
    return _col.doc(requesterUid).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return _fromDoc(doc);
    });
  }

  // =========================================================
  // Admin / Maanaim
  // =========================================================

  @override
  Stream<List<AccessRequest>> watchPending({int? limit}) {
    Query<Map<String, dynamic>> q =
    _col.where('status', isEqualTo: 'pending'); // sem orderBy p/ evitar índice
    if (limit != null && limit > 0) q = q.limit(limit);

    return q.snapshots().map((snap) {
      final list = snap.docs.map(_fromDoc).toList();
      // ordena desc por createdAt em memória
      list.sort((a, b) {
        final ad = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bd = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bd.compareTo(ad);
      });
      return list;
    });
  }

  @override
  Stream<int> watchPendingCount() {
    return _col.where('status', isEqualTo: 'pending').snapshots().map((s) => s.size);
  }

  @override
  Future<void> approve({
    required String requestId,
    required UserRole role,
    String? regionId,
    String? areaId,
    String? poloId,
    String? decidedBy,
  }) async {
    _validateScope(role, regionId: regionId, areaId: areaId, poloId: poloId);

    await _db.runTransaction((tx) async {
      final reqRef = _col.doc(requestId);
      final reqSnap = await tx.get(reqRef);
      if (!reqSnap.exists) throw StateError('Solicitação não encontrada.');

      final data = reqSnap.data()!;
      if ((data['status'] as String?) != 'pending') {
        throw StateError('Solicitação já processada.');
      }

      final requesterUid = (data['requesterUid'] as String?)?.trim();
      final email = (data['email'] as String? ?? '').trim();
      final displayName = (data['displayName'] as String? ?? '').trim();
      final phone = data['phone'] as String?;

      if (requesterUid == null || requesterUid.isEmpty) {
        throw StateError('Solicitação sem requesterUid.');
      }

      final userRef = _db.collection('users').doc(requesterUid);

      // Cria/merge o perfil do usuário aprovado
      tx.set(userRef, {
        'displayName': displayName,
        'email': email,
        'role': role.name, // admin|maanaim|region|area|polo|readonly
        'active': true,
        'regionId': regionId,
        'areaId': areaId,
        'poloId': poloId,
        'phone': phone,
        'photoUrl': null,
        'scopeKey': _buildScopeKey(role, regionId, areaId, poloId),
        'createdAt': FieldValue.serverTimestamp(), // preserva se já existir
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Fecha a solicitação como aprovada
      tx.update(reqRef, {
        'status': 'approved',
        'decidedAt': FieldValue.serverTimestamp(),
        'decidedBy': decidedBy ?? _auth.currentUser?.uid,
        'reason': null,
      });
    });
  }

  @override
  Future<void> reject({
    required String requestId,
    String? reason,
    String? decidedBy,
  }) async {
    await _db.runTransaction((tx) async {
      final reqRef = _col.doc(requestId);
      final reqSnap = await tx.get(reqRef);
      if (!reqSnap.exists) throw StateError('Solicitação não encontrada.');
      final data = reqSnap.data()!;
      if ((data['status'] as String?) != 'pending') {
        throw StateError('Solicitação já processada.');
      }

      tx.update(reqRef, {
        'status': 'rejected',
        'reason': (reason ?? '').trim().isEmpty ? null : reason!.trim(),
        'decidedAt': FieldValue.serverTimestamp(),
        'decidedBy': decidedBy ?? _auth.currentUser?.uid,
      });
    });
  }

  // ---------- helpers ----------
  void _validateScope(
      UserRole role, {
        String? regionId,
        String? areaId,
        String? poloId,
      }) {
    switch (role) {
      case UserRole.admin:
      case UserRole.maanaim:
      case UserRole.readonly:
        return;
      case UserRole.region:
        if ((regionId ?? '').isEmpty) {
          throw ArgumentError('regionId é obrigatório para role region.');
        }
        return;
      case UserRole.area:
        if ((areaId ?? '').isEmpty) {
          throw ArgumentError('areaId é obrigatório para role area.');
        }
        return;
      case UserRole.polo:
        if ((poloId ?? '').isEmpty) {
          throw ArgumentError('poloId é obrigatório para role polo.');
        }
        return;
    }
  }

  String? _buildScopeKey(
      UserRole role,
      String? regionId,
      String? areaId,
      String? poloId,
      ) {
    return switch (role) {
      UserRole.region => (regionId == null ? null : 'region:$regionId'),
      UserRole.area => (areaId == null ? null : 'area:$areaId'),
      UserRole.polo => (poloId == null ? null : 'polo:$poloId'),
      UserRole.maanaim => 'maanaim',
      UserRole.admin => 'admin',
      UserRole.readonly => 'readonly',
    };
  }
}
