import 'package:cloud_firestore/cloud_firestore.dart';

import '../src.dart';

class FirestoreAttendanceRepository implements IAttendanceRepository {
  // Coleção única para attendance
  final _col = FirebaseFirestore.instance.collection('attendance');

  AttendanceRecord _fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return AttendanceRecord(
      id: doc.id,
      rehearsalId: d['rehearsalId'] as String,
      personId: d['personId'] as String,
      status: AttendanceStatus.values[(d['statusIndex'] as int?) ?? 0],
      justification: d['justification'] as String?,
      markedByUserId: d['markedByUserId'] as String,
      markedAt: tsToDate(d['markedAt'] as Timestamp)!,
      pendingSync: (d['pendingSync'] as bool?) ?? false,
    );
  }

  Map<String, dynamic> _toMap(AttendanceRecord r) => {
    'rehearsalId': r.rehearsalId,
    'personId': r.personId,
    'statusIndex': r.status.index,
    'justification': r.justification,
    'markedByUserId': r.markedByUserId,
    'markedAt': dateToTs(r.markedAt),
    'pendingSync': r.pendingSync,
  };

  @override
  Future<List<AttendanceRecord>> listByRehearsal(String rehearsalId) async {
    final res = await _col.where('rehearsalId', isEqualTo: rehearsalId).get();
    return res.docs.map(_fromDoc).toList();
  }

  @override
  Future<AttendanceRecord> upsert(AttendanceRecord record) async {
    await _col.doc(record.id).set(_toMap(record), SetOptions(merge: true));
    final snap = await _col.doc(record.id).get();
    return _fromDoc(snap);
  }

  @override
  Future<void> upsertMany(List<AttendanceRecord> records) async {
    if (records.isEmpty) return;
    final batch = FirebaseFirestore.instance.batch();
    for (final r in records) {
      batch.set(_col.doc(r.id), _toMap(r), SetOptions(merge: true));
    }
    await batch.commit();
  }

  @override
  Future<void> delete(String id) async {
    await _col.doc(id).delete();
  }
}
