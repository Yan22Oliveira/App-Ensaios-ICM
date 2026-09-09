import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../src.dart';

class FirestorePeopleRepository implements IPersonRepository {
  final _col = FirebaseFirestore.instance.collection('people');

  Person _fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return Person(
      id: doc.id,
      fullName: (d['fullName'] as String?) ?? '',
      regionId: d['regionId'] as String,
      areaId: d['areaId'] as String?,
      poloId: d['poloId'] as String?,
      email: d['email'] as String?,
      phone: d['phone'] as String?,
      roles: (d['roles'] as List?)?.cast<String>() ?? const [],
      active: (d['active'] as bool?) ?? true,
      worshipLevel: _levelFromString(d['worshipLevel'] as String?),
    );
  }

  Map<String, dynamic> _toMap(Person p) => {
    'fullName': p.fullName,
    'fullNameLower': p.fullName.trim().toLowerCase(),
    'regionId': p.regionId,
    'areaId': p.areaId,
    'poloId': p.poloId,
    'email': p.email?.trim(),
    'phone': p.phone?.trim(),
    'roles': p.roles,
    'active': p.active,
    'worshipLevel': _levelToString(p.worshipLevel),
  };

  String _levelToString(RehearsalLevel l) => switch (l) {
    RehearsalLevel.polo => 'polo',
    RehearsalLevel.area => 'area',
    RehearsalLevel.region => 'region',
    RehearsalLevel.maanaim => 'maanaim',
  };

  RehearsalLevel _levelFromString(String? s) {
    final key = (s ?? '').trim().toLowerCase();
    switch (key) {
      case 'maanaim':
        return RehearsalLevel.maanaim;
      case 'region':
        return RehearsalLevel.region;
      case 'area':
        return RehearsalLevel.area;
      case 'polo':
        return RehearsalLevel.polo;
      default:
        return RehearsalLevel.polo;
    }
  }

  String _normalizePhone(String phone) {
    return phone.replaceAll(RegExp(r'\D'), '');
  }

  Query<Map<String, dynamic>> _buildQuery({
    String? regionId,
    List<String>? regionIds,
    String? areaId,
    String? poloId,
    List<String>? roles,
  }) {
    Query<Map<String, dynamic>> q = _col.where('active', isEqualTo: true);
    if (regionIds != null && regionIds.isNotEmpty) {
      final ids = regionIds.length > 30 ? regionIds.take(30).toList() : regionIds;
      q = q.where('regionId', whereIn: ids);
    } else if (regionId != null) {
      q = q.where('regionId', isEqualTo: regionId);
    }
    if (areaId != null) q = q.where('areaId', isEqualTo: areaId);
    if (poloId != null) q = q.where('poloId', isEqualTo: poloId);
    if (roles != null && roles.isNotEmpty) {
      final r = roles.length == 1 ? roles : roles.take(10).toList();
      q = r.length == 1
          ? q.where('roles', arrayContains: r.first)
          : q.where('roles', arrayContainsAny: r);
    }
    return q;
  }

  @override
  Stream<List<Person>> watchList({
    String? regionId,
    List<String>? regionIds,
    String? areaId,
    String? poloId,
    List<String>? roles,
  }) {
    return _buildQuery(
      regionId: regionId,
      regionIds: regionIds,
      areaId: areaId,
      poloId: poloId,
      roles: roles,
    ).snapshots().map((snap) {
      final list = snap.docs.map(_fromDoc).toList();
      list.sort((a, b) => a.fullName.compareTo(b.fullName));
      return list;
    });
  }

  @override
  Future<Person> create(Person p) async {
    // 1) Se tiver email, usa email como ID (idempotente)
    final email = p.email?.trim().toLowerCase();
    if (email != null && email.isNotEmpty) {
      final ref = _col.doc(email);
      await ref.set(_toMap(p), SetOptions(merge: true));
      return _fromDoc(await ref.get());
    }

    // 2) Se tiver phone, usa phone normalizado como ID (idempotente)
    final phone = p.phone?.trim();
    if (phone != null && phone.isNotEmpty) {
      final normalized = _normalizePhone(phone);
      if (normalized.isNotEmpty) {
        final ref = _col.doc('phone:$normalized');
        await ref.set(_toMap(p), SetOptions(merge: true));
        return _fromDoc(await ref.get());
      }
    }

    // 3) Sem email/phone: tenta deduplicar por (fullNameLower + região/área/polo)
    final fullLower = p.fullName.trim().toLowerCase();
    final q = await _col
        .where('fullNameLower', isEqualTo: fullLower)
        .where('regionId', isEqualTo: p.regionId)
        .where('areaId', isEqualTo: p.areaId)
        .where('poloId', isEqualTo: p.poloId)
        .limit(1)
        .get();

    if (q.docs.isNotEmpty) {
      // Já existe — atualiza
      final ref = q.docs.first.reference;
      await ref.set(_toMap(p), SetOptions(merge: true));
      return _fromDoc(await ref.get());
    } else {
      // Não existe — cria novo doc (ID aleatório)
      final doc = await _col.add(_toMap(p));
      final snap = await doc.get();
      return _fromDoc(snap);
    }
  }

  @override
  Future<List<Person>> list({
    String? regionId,
    List<String>? regionIds,
    String? areaId,
    String? poloId,
    List<String>? roles,
    String? search,
    RehearsalLevel? worshipLevel,
  }) async {
    if (kDebugMode) {
      debugPrint('[PeopleRepo] list(regionId=$regionId, regionIds=${regionIds?.length}, areaId=$areaId, poloId=$poloId, worshipLevel=${worshipLevel?.name})');
    }

    Query<Map<String, dynamic>> q = _buildQuery(
      regionId: regionId,
      regionIds: regionIds,
      areaId: areaId,
      poloId: poloId,
      roles: roles,
    );

    if (worshipLevel != null) {
      final levelStr = _levelToString(worshipLevel);
      q = q.where('worshipLevel', isEqualTo: levelStr);
      if (kDebugMode) debugPrint('[PeopleRepo] Query com worshipLevel no Firestore: "$levelStr"');
    }

    List<Person> result;
    try {
      final res = await q.get();
      result = res.docs.map(_fromDoc).toList();
      if (kDebugMode) {
        debugPrint('[PeopleRepo] Query OK: ${result.length} documento(s).');
        if (worshipLevel != null && result.isNotEmpty) {
          for (final p in result) {
            debugPrint('[PeopleRepo]   - "${p.fullName}" worshipLevel=${p.worshipLevel.name} regionId=${p.regionId}');
          }
        }
      }
    } on FirebaseException catch (e) {
      if (kDebugMode) debugPrint('[PeopleRepo] FirebaseException: code=${e.code} message=${e.message}');
      // Índice composto ainda "Criando..." ou inexistente: busca sem worshipLevel e filtra em memória.
      if ((e.code == 'failed-precondition' || e.code == 'unavailable') && worshipLevel != null) {
        if (kDebugMode) debugPrint('[PeopleRepo] Fallback: buscando sem worshipLevel e filtrando em memória por ${worshipLevel.name}');
        final all = await list(
          regionId: regionId,
          regionIds: regionIds,
          areaId: areaId,
          poloId: poloId,
          roles: roles,
          search: search,
          worshipLevel: null,
        );
        if (kDebugMode) {
          debugPrint('[PeopleRepo] Fallback: list(regionId only) retornou ${all.length} pessoa(s). worshipLevel de cada uma:');
          for (final p in all) {
            debugPrint('[PeopleRepo]   - "${p.fullName}" worshipLevel=${p.worshipLevel.name} (esperado ${worshipLevel.name}) regionId=${p.regionId}');
          }
        }
        final filtered = all.where((p) => p.worshipLevel == worshipLevel).toList();
        if (kDebugMode) debugPrint('[PeopleRepo] Fallback: após filtro worshipLevel==${worshipLevel.name} => ${filtered.length} pessoa(s)');
        if (search != null && search.trim().isNotEmpty) {
          final t = search.trim().toLowerCase();
          return filtered.where((p) {
            final name = p.fullName.toLowerCase();
            final email = (p.email ?? '').toLowerCase();
            final phone = (p.phone ?? '').toLowerCase();
            final hasRole = p.roles.any((r) => r.toLowerCase().contains(t));
            return name.contains(t) || email.contains(t) || phone.contains(t) || hasRole;
          }).toList()
            ..sort((a, b) => a.fullName.compareTo(b.fullName));
        }
        filtered.sort((a, b) => a.fullName.compareTo(b.fullName));
        return filtered;
      }
      rethrow;
    }

    if (search != null && search.trim().isNotEmpty) {
      final t = search.trim().toLowerCase();
      result = result.where((p) {
        final name = p.fullName.toLowerCase();
        final email = (p.email ?? '').toLowerCase();
        final phone = (p.phone ?? '').toLowerCase();
        final hasRole = p.roles.any((r) => r.toLowerCase().contains(t));
        return name.contains(t) || email.contains(t) || phone.contains(t) || hasRole;
      }).toList();
    }

    result.sort((a, b) => a.fullName.compareTo(b.fullName));
    return result;
  }

  @override
  Future<Person?> getById(String id) async {
    final doc = await _col.doc(id).get();
    if (!doc.exists) return null;
    return _fromDoc(doc);
  }

  @override
  Future<List<Person>> listByIds(List<String> ids) async {
    final unique = ids.map((e) => e.trim()).where((e) => e.isNotEmpty).toSet().toList();
    if (unique.isEmpty) return const [];
    final out = <Person>[];
    const chunkSize = 10;
    for (var i = 0; i < unique.length; i += chunkSize) {
      final end = (i + chunkSize < unique.length) ? i + chunkSize : unique.length;
      final chunk = unique.sublist(i, end);
      final snaps = await Future.wait(chunk.map((id) => _col.doc(id).get()));
      for (final snap in snaps) {
        if (snap.exists) out.add(_fromDoc(snap));
      }
    }
    out.sort((a, b) => a.fullName.compareTo(b.fullName));
    return out;
  }

  @override
  Future<List<Person>> bulkCreate(List<Person> people) async {
    if (people.isEmpty) return const [];
    final created = <Person>[];
    for (final p in people) {
      created.add(await create(p)); // usa lógica idempotente acima
    }
    created.sort((a, b) => a.fullName.compareTo(b.fullName));
    return created;
  }

  @override
  Future<Person> update(Person p) async {
    await _col.doc(p.id).set(_toMap(p), SetOptions(merge: true));
    final snap = await _col.doc(p.id).get();
    return _fromDoc(snap);
  }
}
