import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../domain/models/user_profile.dart';
import '../domain/repositories/i_user_profile_repository.dart';

class FirestoreUserProfileRepository implements IUserProfileRepository {
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  FirestoreUserProfileRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  DocumentReference<Map<String, dynamic>> _meRef(String uid) =>
      _db.collection('users').doc(uid);

  UserProfile? _fromDoc(String uid, Map<String, dynamic>? m) {
    if (m == null) return null;
    final role = roleFromString(m['role'] as String?);
    return UserProfile(
      uid: uid,
      displayName: (m['displayName'] as String? ?? '').trim(),
      email: (m['email'] as String? ?? '').trim(),
      role: role,
      active: (m['active'] as bool?) ?? false,
      regionId: m['regionId'] as String?,
      areaId: m['areaId'] as String?,
      poloId: m['poloId'] as String?,
      phone: m['phone'] as String?,
      photoUrl: m['photoUrl'] as String?,
      createdAt: (m['createdAt'] is Timestamp)
          ? (m['createdAt'] as Timestamp).toDate()
          : null,
      updatedAt: (m['updatedAt'] is Timestamp)
          ? (m['updatedAt'] as Timestamp).toDate()
          : null,
    );
  }

  @override
  Future<UserProfile?> getCurrent() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;
    final doc = await _meRef(uid).get();
    if (!doc.exists) return null;
    return _fromDoc(uid, doc.data());
  }

  @override
  Stream<UserProfile?> watchCurrent() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return const Stream.empty();
    return _meRef(uid).snapshots().map((snap) {
      if (!snap.exists) return null;
      return _fromDoc(uid, snap.data());
    });
  }

  @override
  Future<void> updateCurrent(Map<String, dynamic> patch) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    await _meRef(uid).update({
      ...patch,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> createAccessRequest({
    required String email,
    required String displayName,
    String? phone,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw StateError('Usuário não autenticado.');
    }

    final trimmedEmail = email.trim();
    final trimmedName = displayName.trim();
    final trimmedPhone =
    (phone ?? '').trim().isEmpty ? null : phone!.trim();

    // Se já existe perfil, não cria request.
    final me = await _meRef(uid).get();
    if (me.exists) return;

    // Evita duplicar: se já houver pendente para o mesmo uid, apenas atualiza.
    final pending = await _db
        .collection('accessRequests')
        .where('requesterUid', isEqualTo: uid)
        .where('status', isEqualTo: 'pending')
        .limit(1)
        .get();

    if (pending.docs.isNotEmpty) {
      await pending.docs.first.reference.update({
        'email': trimmedEmail,
        'displayName': trimmedName,
        'phone': trimmedPhone,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return;
    }

    // Cria a solicitação com o requesterUid (necessário para aprovação).
    await _db.collection('accessRequests').add({
      'requesterUid': uid, // 👈 importante para o fluxo de aprovação
      'email': trimmedEmail,
      'displayName': trimmedName,
      'phone': trimmedPhone,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
