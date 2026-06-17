import 'package:cloud_firestore/cloud_firestore.dart';

import '../src.dart';

class FirestoreGeoRepository implements IGeoRepository {
  final FirebaseFirestore _db;
  FirestoreGeoRepository({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  /// Documento em `maanains`: campo Nome (com N maiúsculo).
  Maanaim _maanaimFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    final name = (d['Nome'] as String?) ?? (d['name'] as String?) ?? doc.id;
    return Maanaim(id: doc.id, name: name);
  }

  Region _regionFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return Region(id: doc.id, name: (d['name'] as String?) ?? doc.id);
  }

  Area _areaFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return Area(
      id: doc.id,
      name: (d['name'] as String?) ?? doc.id,
      regionId: (d['regionId'] as String?) ?? '',
    );
  }

  Polo _poloFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return Polo(
      id: doc.id,
      name: (d['name'] as String?) ?? doc.id,
      areaId: (d['areaId'] as String?) ?? '',
    );
  }

  @override
  Future<List<Maanaim>> maanaims() async {
    final res = await _db.collection('maanains').get();
    final list = res.docs.map(_maanaimFromDoc).toList();
    list.sort((a, b) => a.name.compareTo(b.name));
    return list;
  }

  @override
  Future<List<Region>> regionsByMaanaim(String maanaimId) async {
    // Regiões ficam na coleção "regions" com campo maanaimId
    final res = await _db
        .collection('regions')
        .where('maanaimId', isEqualTo: maanaimId)
        .get();
    final list = res.docs.map(_regionFromDoc).toList();
    list.sort((a, b) => a.name.compareTo(b.name));
    return list;
  }

  @override
  Future<List<Region>> regions() async {
    // Sem orderBy; ordena em memória
    final res = await _db.collection('regions').get();
    final list = res.docs.map(_regionFromDoc).toList();
    list.sort((a, b) => a.name.compareTo(b.name));
    return list;
  }

  @override
  Future<List<Area>> areasByRegion(String regionId) async {
    // Sem orderBy para evitar índice composto
    final res = await _db
        .collection('areas')
        .where('regionId', isEqualTo: regionId)
        .get();
    final list = res.docs.map(_areaFromDoc).toList();
    list.sort((a, b) => a.name.compareTo(b.name));
    return list;
  }

  @override
  Future<List<Polo>> polosByArea(String areaId) async {
    // Sem orderBy para evitar índice composto
    final res =
    await _db.collection('polos').where('areaId', isEqualTo: areaId).get();
    final list = res.docs.map(_poloFromDoc).toList();
    list.sort((a, b) => a.name.compareTo(b.name));
    return list;
  }
}
