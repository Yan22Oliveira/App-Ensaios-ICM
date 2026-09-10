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
    try {
      return UserProfile(
        uid: uid,
        displayName: (_asString(m['displayName']) ?? '').trim(),
        email: (_asString(m['email']) ?? '').trim(),
        role: roleFromString(_asString(m['role'])),
        active: _asBool(m['active']),
        regionId: _asString(m['regionId']),
        areaId: _asString(m['areaId']),
        poloId: _asString(m['poloId']),
        phone: _asString(m['phone']),
        photoUrl: _asString(m['photoUrl']),
        createdAt: _asDate(m['createdAt']),
        updatedAt: _asDate(m['updatedAt']),
      );
    } catch (_) {
      return UserProfile(
        uid: uid,
        displayName: (_asString(m['displayName']) ?? uid).trim(),
        email: (_asString(m['email']) ?? '').trim(),
        role: UserRole.readonly,
        active: _asBool(m['active']),
      );
    }
  }

  String? _asString(dynamic v) {
    if (v == null) return null;
    if (v is String) return v;
    return v.toString();
  }

  bool _asBool(dynamic v) {
    if (v is bool) return v;
    if (v is num) return v != 0;
    if (v is String) {
      final s = v.toLowerCase().trim();
      return s == 'true' || s == '1';
    }
    return false;
  }

  DateTime? _asDate(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return null;
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
  Future<List<UserProfile>> listAll() async {
    QuerySnapshot<Map<String, dynamic>> snap;
    try {
      snap = await _db.collection('users').get();
    } on FirebaseException catch (e) {
      if (e.code != 'permission-denied' && e.code != 'unavailable') {
        return [];
      }
      try {
        snap = await _db.collection('users').get(const GetOptions(source: Source.cache));
      } catch (_) {
        return [];
      }
    } catch (_) {
      return [];
    }
    final list = <UserProfile>[];
    for (final d in snap.docs) {
      final profile = _fromDoc(d.id, d.data());
      if (profile != null) list.add(profile);
    }
    list.sort((a, b) => a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));
    return list;
  }

  @override
  Future<UserProfile?> getById(String uid) async {
    try {
      final doc = await _db.collection('users').doc(uid).get();
      if (!doc.exists) return null;
      return _fromDoc(uid, doc.data());
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> updateById(UserProfile profile) async {
    await _db.collection('users').doc(profile.uid).set({
      'displayName': profile.displayName.trim(),
      'email': profile.email.trim(),
      'role': roleToString(profile.role),
      'active': profile.active,
      'regionId': profile.regionId,
      'areaId': profile.areaId,
      'poloId': profile.poloId,
      'phone': (profile.phone ?? '').trim().isEmpty ? null : profile.phone!.trim(),
      'scopeKey': _scopeKey(profile),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  String? _scopeKey(UserProfile p) {
    switch (p.role) {
      case UserRole.region:
        return (p.regionId == null ? null : 'region:${p.regionId}');
      case UserRole.area:
        return (p.areaId == null ? null : 'area:${p.areaId}');
      case UserRole.polo:
        return (p.poloId == null ? null : 'polo:${p.poloId}');
      case UserRole.maanaim:
        return 'maanaim';
      case UserRole.admin:
        return 'admin';
      case UserRole.readonly:
        return 'readonly';
    }
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
