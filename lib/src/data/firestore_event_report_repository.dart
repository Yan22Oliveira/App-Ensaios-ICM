import 'package:cloud_firestore/cloud_firestore.dart';

import '../src.dart';

class FirestoreEventReportRepository implements IEventReportRepository {
  final FirebaseFirestore _db;

  FirestoreEventReportRepository({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('eventReports');

  EventReport _fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return EventReport(
      id: doc.id,
      eventId: (d['eventId'] as String?) ?? doc.id,
      title: (d['title'] as String?) ?? '',
      responsible: d['responsible'] as String?,
      overview: (d['overview'] as String?) ?? '',
      conclusion: (d['conclusion'] as String?) ?? '',
      notes: d['notes'] as String?,
      status: eventReportStatusFromString(d['status'] as String?),
      createdAt: tsToDate(d['createdAt'] as Timestamp?) ?? DateTime.now(),
      updatedAt: tsToDate(d['updatedAt'] as Timestamp?) ?? DateTime.now(),
      updatedByName: d['updatedByName'] as String?,
    );
  }

  Map<String, dynamic> _toMap(EventReport r, {required DateTime createdAt}) => {
        'eventId': r.eventId,
        'title': r.title,
        'responsible': r.responsible,
        'overview': r.overview,
        'conclusion': r.conclusion,
        'notes': r.notes,
        'status': eventReportStatusToString(r.status),
        'createdAt': dateToTs(createdAt),
        'updatedAt': dateToTs(r.updatedAt),
        'updatedByName': r.updatedByName,
      };

  @override
  Future<EventReport?> getByEventId(String eventId) async {
    if (eventId.trim().isEmpty) return null;
    final snap = await _col.doc(eventId).get();
    if (!snap.exists) return null;
    return _fromDoc(snap);
  }

  @override
  Future<EventReport> upsert(EventReport report) async {
    final ref = _col.doc(report.eventId);
    final existing = await ref.get();
    final createdAt = existing.exists
        ? (tsToDate(existing.data()?['createdAt'] as Timestamp?) ?? report.createdAt)
        : report.createdAt;
    final now = DateTime.now();
    final toSave = report.copyWith(updatedAt: now);
    await ref.set(_toMap(toSave, createdAt: createdAt), SetOptions(merge: true));
    final snap = await ref.get();
    return _fromDoc(snap);
  }
}
