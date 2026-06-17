import 'package:cloud_firestore/cloud_firestore.dart';

class RoleGroup {
  final String id;
  final String name;
  final List<String> items;
  final int order;

  const RoleGroup({
    required this.id,
    required this.name,
    required this.items,
    this.order = 999,
  });
}
abstract class IRolesRepository {
  Future<List<RoleGroup>> listGroups();
}

class FirestoreRolesRepository implements IRolesRepository {
  final FirebaseFirestore _db;
  FirestoreRolesRepository({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  /// Grupos padrão quando a coleção `roles` está vazia ou inacessível.
  static List<RoleGroup> get _defaultGroups => [
    const RoleGroup(
      id: 'default',
      name: 'Papéis',
      order: 0,
      items: [
        'Secretário de Polo',
        'Secretário de Área',
        'Secretário de Região',
        'Secretário de Maanaim',
        'Líder',
        'Músico',
        'Voz',
        'Outro',
      ],
    ),
  ];

  @override
  Future<List<RoleGroup>> listGroups() async {
    try {
      final res = await _db.collection('roles').orderBy('order').get();
      if (res.docs.isEmpty) return _defaultGroups;
      return res.docs.map((d) {
        final data = d.data();
        final name = data['name'] as String? ?? d.id;
        final rawItems = data['items'];
        final items = rawItems is List
            ? rawItems.map((e) => e.toString()).toList()
            : <String>[];
        return RoleGroup(
          id: d.id,
          name: name,
          items: items,
          order: data['order'] as int? ?? 999,
        );
      }).toList();
    } catch (_) {
      return _defaultGroups;
    }
  }
}
