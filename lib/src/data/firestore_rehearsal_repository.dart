import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../src.dart';

class FirestoreRehearsalRepository implements IRehearsalRepository {
  final FirebaseFirestore _db;
  final IUserProfileRepository _profiles;
  final IGeoRepository _geo;

  late final CollectionReference<Map<String, dynamic>> _col;

  FirestoreRehearsalRepository({
    FirebaseFirestore? db,
    required IUserProfileRepository profiles,
    required IGeoRepository geo,
    UserProfile? currentUser,
  })  : _db = db ?? FirebaseFirestore.instance,
        _profiles = profiles,
        _geo = geo,
        _me = currentUser {
    // Usa a mesma instância de Firestore passada ao repo
    _col = _db.collection('rehearsals');
  }

  UserProfile? _me;
  void setScope(UserProfile me) => _me = me;

  // Espera o perfil chegar (sem travar)
  Future<UserProfile?> _waitProfile() async {
    if (_me != null) return _me;

    final got = await _profiles.getCurrent();
    if (got != null) return (_me = got);

    try {
      final first = await _profiles
          .watchCurrent()
          .first
          .timeout(const Duration(milliseconds: 1200), onTimeout: () => null);
      if (first != null) _me = first;
    } catch (_) {}
    return _me;
  }

  // Perfil tem escopo válido para o papel?
  bool _hasValidScope(UserProfile me) {
    if (!me.active) return false;
    switch (me.role) {
      case UserRole.admin:
        return true;
      case UserRole.maanaim:
        return (me.regionId ?? '').isNotEmpty;
      case UserRole.region:
        return (me.regionId ?? '').isNotEmpty;
      case UserRole.area:
        return (me.areaId ?? '').isNotEmpty;
      case UserRole.polo:
        return (me.poloId ?? '').isNotEmpty;
      case UserRole.readonly:
        return (me.poloId ?? me.areaId ?? me.regionId ?? '').isNotEmpty;
    }
  }

  bool _isRecoverableQueryError(FirebaseException e) =>
      e.code == 'permission-denied' || e.code == 'failed-precondition';

  /// Executa as queries uma a uma. Uma query negada/sem índice não derruba as demais.
  Future<List<QuerySnapshot<Map<String, dynamic>>>> _getQueries(
    List<Query<Map<String, dynamic>>> queries,
  ) async {
    if (queries.isEmpty) return const [];
    final snaps = await Future.wait(queries.map((q) async {
      try {
        return await q.get();
      } on FirebaseException catch (e) {
        if (_isRecoverableQueryError(e)) return null;
        rethrow;
      }
    }));
    return [
      for (final s in snaps)
        if (s != null) s,
    ];
  }

  // ===== Map =====
  Rehearsal _fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    final rawRegion = d['regionId'];
    final regionId = (rawRegion is String ? rawRegion.trim() : rawRegion?.toString()) ?? '';
    final rawTitle = (d['title'] as String?)?.trim();
    return Rehearsal(
      id: doc.id,
      eventType: eventTypeFromString(d['eventType'] as String?),
      title: (rawTitle == null || rawTitle.isEmpty) ? null : rawTitle,
      dateTime: tsToDate(d['dateTime'] as Timestamp)!,
      level: levelFromStr((d['level'] as String?) ?? 'polo'),
      regionId: regionId,
      areaId: d['areaId'] as String?,
      poloId: d['poloId'] as String?,
      place: d['place'] as String?,
      description: d['description'] as String?,
      participantMode: eventParticipantModeFromString(d['participantMode'] as String?),
      expectedParticipants: _stringList(d['expectedParticipants']),
      participantsSnapshot: d.containsKey('participantsSnapshot')
          ? _stringList(d['participantsSnapshot'])
          : null,
      closed: (d['closed'] as bool?) ?? false,
      closedAt: (d['closedAt'] as Timestamp?)?.toDate(),
    );
  }

  List<String> _stringList(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .map((e) => e?.toString().trim() ?? '')
        .where((e) => e.isNotEmpty)
        .toList();
  }

  Map<String, dynamic> _toMap({
    required DateTime dateTime,
    required RehearsalLevel level,
    required String regionId,
    required EventType eventType,
    String? title,
    String? areaId,
    String? poloId,
    String? place,
    String? description,
    EventParticipantMode participantMode = EventParticipantMode.all,
    List<String> expectedParticipants = const [],
    bool closed = false,
    DateTime? closedAt,
  }) =>
      {
        'dateTime': dateToTs(dateTime),
        'level': levelToStr(level),
        'eventType': eventTypeToString(eventType),
        'title': title,
        'regionId': regionId,
        'areaId': areaId,
        'poloId': poloId,
        'place': place,
        'description': description,
        'participantMode': eventParticipantModeToString(participantMode),
        'expectedParticipants': participantMode == EventParticipantMode.selected
            ? expectedParticipants
            : const <String>[],
        'closed': closed,
        if (closedAt != null) 'closedAt': Timestamp.fromDate(closedAt),
      };

  // ===== Escopo (ALINHADO ÀS RULES) =====
  Query<Map<String, dynamic>> _applyScope(Query<Map<String, dynamic>> q, UserProfile me) {
    switch (me.role) {
      case UserRole.admin:
        return q; // rules liberam
      case UserRole.maanaim:
      // suas rules: role == 'maanaim' && data.level == 'maanaim'
        return q.where('level', isEqualTo: 'maanaim');
      case UserRole.region:
      // rules exigem level == 'region' && regionId == userRegionId()
        return q
            .where('level', isEqualTo: 'region')
            .where('regionId', isEqualTo: me.regionId);
      case UserRole.area:
      // rules: level == 'area' && areaId == userAreaId()
        return q
            .where('level', isEqualTo: 'area')
            .where('areaId', isEqualTo: me.areaId);
      case UserRole.polo:
      // rules: level == 'polo' && poloId == userPoloId()
        return q
            .where('level', isEqualTo: 'polo')
            .where('poloId', isEqualTo: me.poloId);
      case UserRole.readonly:
      // rules readonly aceitam QUALQUER um dos 3 escopos, mas SEMPRE com level correspondente.
        if ((me.poloId ?? '').isNotEmpty) {
          return q.where('level', isEqualTo: 'polo').where('poloId', isEqualTo: me.poloId);
        }
        if ((me.areaId ?? '').isNotEmpty) {
          return q.where('level', isEqualTo: 'area').where('areaId', isEqualTo: me.areaId);
        }
        if ((me.regionId ?? '').isNotEmpty) {
          return q.where('level', isEqualTo: 'region').where('regionId', isEqualTo: me.regionId);
        }
        // sem escopo → o caller já bloqueia antes
        return q.where('level', isEqualTo: '__none__');
    }
  }

  // ===== Escopo para LISTAGEM (hierarquia) =====
  //
  // Aqui aplicamos o que o usuário pediu:
  // - polo: só polo
  // - area: area + polos da area
  // - region: region + areas + polos da region
  // - maanaim: maanaim + regions + areas + polos do maanaim
  //
  // OBS: Isso pressupõe que suas Firestore Rules permitam essa leitura.
  Future<List<Query<Map<String, dynamic>>>> _queriesForScope(
    UserProfile me, {
    required DateTime minDate,
    required bool descending,
    required int limit,
  }) async {
    final base = _col
        .where('dateTime', isGreaterThanOrEqualTo: Timestamp.fromDate(minDate))
        .orderBy('dateTime', descending: descending)
        .limit(limit);

    switch (me.role) {
      case UserRole.admin:
        return [base];
      case UserRole.polo:
        return [
          // Rules exigem level == 'polo'
          base.where('level', isEqualTo: 'polo').where('poloId', isEqualTo: me.poloId),
        ];
      case UserRole.area:
        return [
          // Rules: area pode ver level in ['area','polo'] com areaId == userAreaId()
          base.where('level', isEqualTo: 'area').where('areaId', isEqualTo: me.areaId),
          base.where('level', isEqualTo: 'polo').where('areaId', isEqualTo: me.areaId),
        ];
      case UserRole.region:
        return [
          // Rules: region pode ver level in ['region','area','polo'] com regionId == userRegionId()
          base.where('level', isEqualTo: 'region').where('regionId', isEqualTo: me.regionId),
          base.where('level', isEqualTo: 'area').where('regionId', isEqualTo: me.regionId),
          base.where('level', isEqualTo: 'polo').where('regionId', isEqualTo: me.regionId),
        ];
      case UserRole.maanaim:
        final maanaimId = me.regionId ?? '';
        if (maanaimId.isEmpty) return const [];

        // Rehearsal nível maanaim: usa regionId como id do maanaim (padrão atual do app).
        final maanaimQuery = base.where('level', isEqualTo: 'maanaim').where('regionId', isEqualTo: maanaimId);

        // Níveis abaixo: regionId ∈ regions do maanaim (whereIn limitado a 10).
        final regions = await _geo.regionsByMaanaim(maanaimId);
        final ids = regions.map((e) => e.id).where((e) => e.trim().isNotEmpty).toList();
        if (ids.isEmpty) return [maanaimQuery];

        final chunks = <List<String>>[];
        for (var i = 0; i < ids.length; i += 10) {
          chunks.add(ids.sublist(i, (i + 10).clamp(0, ids.length)));
        }

        // Listagem abaixo: whereIn(regionId) das regiões do maanaim.
        // A rule de list permite level in [region,area,polo] para maanaim (sem exists()).
        final below = <Query<Map<String, dynamic>>>[];
        for (final c in chunks) {
          below.add(base.where('level', isEqualTo: 'region').where('regionId', whereIn: c));
          below.add(base.where('level', isEqualTo: 'area').where('regionId', whereIn: c));
          below.add(base.where('level', isEqualTo: 'polo').where('regionId', whereIn: c));
        }
        return [maanaimQuery, ...below];
      case UserRole.readonly:
        // Mantém o comportamento mais restrito (um único escopo/nível).
        if ((me.poloId ?? '').isNotEmpty) {
          return [base.where('level', isEqualTo: 'polo').where('poloId', isEqualTo: me.poloId)];
        }
        if ((me.areaId ?? '').isNotEmpty) {
          return [base.where('level', isEqualTo: 'area').where('areaId', isEqualTo: me.areaId)];
        }
        if ((me.regionId ?? '').isNotEmpty) {
          return [base.where('level', isEqualTo: 'region').where('regionId', isEqualTo: me.regionId)];
        }
        return const [];
    }
  }

  Future<List<Query<Map<String, dynamic>>>> _openQueriesForScope(
    UserProfile me, {
    required bool descending,
    required int limit,
  }) async {
    final base = _col
        .where('closed', isEqualTo: false)
        .orderBy('dateTime', descending: descending)
        .limit(limit);

    switch (me.role) {
      case UserRole.admin:
        return [base];
      case UserRole.polo:
        return [
          base.where('level', isEqualTo: 'polo').where('poloId', isEqualTo: me.poloId),
        ];
      case UserRole.area:
        return [
          base.where('level', isEqualTo: 'area').where('areaId', isEqualTo: me.areaId),
          base.where('level', isEqualTo: 'polo').where('areaId', isEqualTo: me.areaId),
        ];
      case UserRole.region:
        return [
          base.where('level', isEqualTo: 'region').where('regionId', isEqualTo: me.regionId),
          base.where('level', isEqualTo: 'area').where('regionId', isEqualTo: me.regionId),
          base.where('level', isEqualTo: 'polo').where('regionId', isEqualTo: me.regionId),
        ];
      case UserRole.maanaim:
        final maanaimId = me.regionId ?? '';
        if (maanaimId.isEmpty) return const [];

        final maanaimQuery = base.where('level', isEqualTo: 'maanaim').where('regionId', isEqualTo: maanaimId);

        final regions = await _geo.regionsByMaanaim(maanaimId);
        final ids = regions.map((e) => e.id).where((e) => e.trim().isNotEmpty).toList();
        if (ids.isEmpty) return [maanaimQuery];

        final chunks = <List<String>>[];
        for (var i = 0; i < ids.length; i += 10) {
          chunks.add(ids.sublist(i, (i + 10).clamp(0, ids.length)));
        }

        final below = <Query<Map<String, dynamic>>>[];
        for (final c in chunks) {
          below.add(base.where('level', isEqualTo: 'region').where('regionId', whereIn: c));
          below.add(base.where('level', isEqualTo: 'area').where('regionId', whereIn: c));
          below.add(base.where('level', isEqualTo: 'polo').where('regionId', whereIn: c));
        }
        return [maanaimQuery, ...below];
      case UserRole.readonly:
        if ((me.poloId ?? '').isNotEmpty) {
          return [base.where('level', isEqualTo: 'polo').where('poloId', isEqualTo: me.poloId)];
        }
        if ((me.areaId ?? '').isNotEmpty) {
          return [base.where('level', isEqualTo: 'area').where('areaId', isEqualTo: me.areaId)];
        }
        if ((me.regionId ?? '').isNotEmpty) {
          return [base.where('level', isEqualTo: 'region').where('regionId', isEqualTo: me.regionId)];
        }
        return const [];
    }
  }

  bool _inScopeHierarchy(UserProfile me, Rehearsal r) {
    switch (me.role) {
      case UserRole.admin:
        return true;
      case UserRole.polo:
        return r.poloId == me.poloId;
      case UserRole.area:
        return r.areaId == me.areaId;
      case UserRole.region:
        return r.regionId == me.regionId;
      case UserRole.maanaim:
        // Para maanaim, a query abaixo já é limitada por whereIn das regions;
        // e o próprio ensaio do nível maanaim vem pelo query específico.
        return true;
      case UserRole.readonly:
        if ((me.poloId ?? '').isNotEmpty) return r.level == RehearsalLevel.polo && r.poloId == me.poloId;
        if ((me.areaId ?? '').isNotEmpty) return r.level == RehearsalLevel.area && r.areaId == me.areaId;
        if ((me.regionId ?? '').isNotEmpty) return r.level == RehearsalLevel.region && r.regionId == me.regionId;
        return false;
    }
  }

  Stream<List<Rehearsal>> _watchMerged(List<Query<Map<String, dynamic>>> queries, bool Function(Rehearsal) keep) {
    if (queries.isEmpty) return Stream.value(const []);

    return Stream.multi((controller) {
      final latest = <int, List<Rehearsal>>{};
      final subs = <StreamSubscription>[];

      void emitMerged() {
        final byId = <String, Rehearsal>{};
        for (final list in latest.values) {
          for (final r in list) {
            byId[r.id] = r;
          }
        }
        final merged = byId.values.where(keep).toList();
        controller.add(merged);
      }

      for (var i = 0; i < queries.length; i++) {
        final q = queries[i];
        subs.add(q.snapshots().listen(
          (snap) {
            latest[i] = snap.docs.map(_fromDoc).toList();
            emitMerged();
          },
          onError: (Object e, StackTrace st) {
            if (e is FirebaseException && _isRecoverableQueryError(e)) {
              latest[i] = const [];
              emitMerged();
              return;
            }
            controller.addError(e, st);
          },
        ));
      }

      controller.onCancel = () async {
        for (final s in subs) {
          await s.cancel();
        }
      };
    });
  }

  Future<List<Query<Map<String, dynamic>>>> _betweenQueriesForScope(
    UserProfile me, {
    required DateTime start,
    required DateTime end,
    required bool descending,
    required int limit,
  }) async {
    final base = _col
        .where('dateTime', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('dateTime', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .orderBy('dateTime', descending: descending)
        .limit(limit);

    switch (me.role) {
      case UserRole.admin:
        return [base];
      case UserRole.polo:
        return [
          base.where('level', isEqualTo: 'polo').where('poloId', isEqualTo: me.poloId),
        ];
      case UserRole.area:
        return [
          base.where('level', isEqualTo: 'area').where('areaId', isEqualTo: me.areaId),
          base.where('level', isEqualTo: 'polo').where('areaId', isEqualTo: me.areaId),
        ];
      case UserRole.region:
        return [
          base.where('level', isEqualTo: 'region').where('regionId', isEqualTo: me.regionId),
          base.where('level', isEqualTo: 'area').where('regionId', isEqualTo: me.regionId),
          base.where('level', isEqualTo: 'polo').where('regionId', isEqualTo: me.regionId),
        ];
      case UserRole.maanaim:
        final maanaimId = me.regionId ?? '';
        if (maanaimId.isEmpty) return const [];

        final maanaimQuery = base.where('level', isEqualTo: 'maanaim').where('regionId', isEqualTo: maanaimId);

        final regions = await _geo.regionsByMaanaim(maanaimId);
        final ids = regions.map((e) => e.id).where((e) => e.trim().isNotEmpty).toList();
        if (ids.isEmpty) return [maanaimQuery];

        final chunks = <List<String>>[];
        for (var i = 0; i < ids.length; i += 10) {
          chunks.add(ids.sublist(i, (i + 10).clamp(0, ids.length)));
        }

        final below = <Query<Map<String, dynamic>>>[];
        for (final c in chunks) {
          below.add(base.where('level', isEqualTo: 'region').where('regionId', whereIn: c));
          below.add(base.where('level', isEqualTo: 'area').where('regionId', whereIn: c));
          below.add(base.where('level', isEqualTo: 'polo').where('regionId', whereIn: c));
        }

        return [maanaimQuery, ...below];
      case UserRole.readonly:
        if ((me.poloId ?? '').isNotEmpty) {
          return [base.where('level', isEqualTo: 'polo').where('poloId', isEqualTo: me.poloId)];
        }
        if ((me.areaId ?? '').isNotEmpty) {
          return [base.where('level', isEqualTo: 'area').where('areaId', isEqualTo: me.areaId)];
        }
        if ((me.regionId ?? '').isNotEmpty) {
          return [base.where('level', isEqualTo: 'region').where('regionId', isEqualTo: me.regionId)];
        }
        return const [];
    }
  }

  // ===== CRUD =====
  @override
  Future<Rehearsal> create({
    required DateTime dateTime,
    required RehearsalLevel level,
    required String regionId,
    required EventType eventType,
    String? title,
    String? areaId,
    String? poloId,
    String? place,
    String? description,
    EventParticipantMode participantMode = EventParticipantMode.all,
    List<String> expectedParticipants = const [],
  }) async {
    final doc = await _col.add(_toMap(
      dateTime: dateTime,
      level: level,
      regionId: regionId,
      eventType: eventType,
      title: title,
      areaId: areaId,
      poloId: poloId,
      place: place,
      description: description,
      participantMode: participantMode,
      expectedParticipants: expectedParticipants,
      closed: false,
    ));
    final snap = await doc.get();
    return _fromDoc(snap);
  }

  @override
  Future<List<Rehearsal>> listUpcoming() async {
    final me = await _waitProfile();
    if (me == null || !_hasValidScope(me)) return const [];

    final queries = await _openQueriesForScope(
      me,
      descending: false,
      limit: 500,
    );

    try {
      final res = await _getQueries(queries);
      final byId = <String, Rehearsal>{};
      for (final snap in res) {
        for (final d in snap.docs) {
          final r = _fromDoc(d);
          if (!r.closed && _inScopeHierarchy(me, r)) {
            byId[r.id] = r;
          }
        }
      }
      final list = byId.values.toList()..sort((a, b) => a.dateTime.compareTo(b.dateTime));
      return list;
    } on FirebaseException catch (e) {
      if (!_isRecoverableQueryError(e) || me.role != UserRole.admin) return const [];

      // Fallback só para admin (rules permitem listagem sem filtro de escopo).
      try {
        final fb = await _col
            .where('closed', isEqualTo: false)
            .orderBy('dateTime')
            .limit(500)
            .get();
        return fb.docs
            .map(_fromDoc)
            .where((r) => !r.closed && _inScopeHierarchy(me, r))
            .toList()
          ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
      } on FirebaseException {
        return const [];
      }
    }
  }

  @override
  Stream<List<Rehearsal>> watchUpcoming() {
    return Stream.fromFuture(_waitProfile()).asyncExpand((UserProfile? me) async* {
      if (me == null || !_hasValidScope(me)) {
        yield const <Rehearsal>[];
        return;
      }
      final queries = await _openQueriesForScope(
        me,
        descending: false,
        limit: 500,
      );

      yield* _watchMerged(
        queries,
        (r) => !r.closed && _inScopeHierarchy(me, r),
      ).map((list) => list..sort((a, b) => a.dateTime.compareTo(b.dateTime)));
    });
  }

  @override
  Future<List<Rehearsal>> listClosed() async {
    final me = await _waitProfile();
    if (me == null || !_hasValidScope(me)) return const [];

    final now = DateTime.now();
    final limitDate = DateTime(now.year - 2, now.month, now.day);
    try {
      final queries = await _queriesForScope(
        me,
        minDate: limitDate,
        descending: true,
        limit: 500,
      );
      final res = await _getQueries(queries);
      final byId = <String, Rehearsal>{};
      for (final snap in res) {
        for (final d in snap.docs) {
          final r = _fromDoc(d);
          if (r.closed && _inScopeHierarchy(me, r)) {
            byId[r.id] = r;
          }
        }
      }
      final list = byId.values.toList()..sort((a, b) => b.dateTime.compareTo(a.dateTime));
      return list;
    } on FirebaseException catch (e) {
      if (!_isRecoverableQueryError(e) || me.role != UserRole.admin) return const [];

      try {
        final fb = await _col
            .where('dateTime', isGreaterThanOrEqualTo: Timestamp.fromDate(limitDate))
            .orderBy('dateTime', descending: true)
            .limit(500)
            .get();

        return fb.docs
            .map(_fromDoc)
            .where((r) => r.closed && _inScopeHierarchy(me, r))
            .toList()
          ..sort((a, b) => b.dateTime.compareTo(a.dateTime));
      } on FirebaseException {
        return const [];
      }
    }
  }

  @override
  Stream<List<Rehearsal>> watchClosed() {
    return Stream.fromFuture(_waitProfile()).asyncExpand((UserProfile? me) async* {
      if (me == null || !_hasValidScope(me)) {
        // ignore: avoid_print
        print('[RehearsalRepo] watchClosed: perfil null ou sem escopo, emitindo []');
        yield const <Rehearsal>[];
        return;
      }
      final now = DateTime.now();
      final limitDate = DateTime(now.year - 2, now.month, now.day);
      final queries = await _queriesForScope(
        me,
        minDate: limitDate,
        descending: true,
        limit: 500,
      );

      yield* _watchMerged(
        queries,
        (r) => r.closed && _inScopeHierarchy(me, r),
      ).map((list) => list..sort((a, b) => b.dateTime.compareTo(a.dateTime)));
    });
  }

  @override
  Future<List<Rehearsal>> listBetween(DateTime start, DateTime end) async {
    final me = await _waitProfile();
    if (me == null || !_hasValidScope(me)) return const [];

    try {
      final queries = await _betweenQueriesForScope(
        me,
        start: start,
        end: end,
        descending: false,
        limit: 1000,
      );
      final res = await _getQueries(queries);

      final byId = <String, Rehearsal>{};
      for (final snap in res) {
        for (final d in snap.docs) {
          final r = _fromDoc(d);
          if (_inScopeHierarchy(me, r)) byId[r.id] = r;
        }
      }

      final list = byId.values.toList()..sort((a, b) => a.dateTime.compareTo(b.dateTime));
      return list;
    } on FirebaseException catch (e) {
      if (!_isRecoverableQueryError(e) || me.role != UserRole.admin) return const [];

      // Fallback sem filtros de escopo: só admin passa nas rules.
      late final QuerySnapshot<Map<String, dynamic>> fb;
      try {
        fb = await _col
            .where('dateTime', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
            .where('dateTime', isLessThanOrEqualTo: Timestamp.fromDate(end))
            .orderBy('dateTime')
            .get();
      } on FirebaseException {
        return const [];
      }

      final all = fb.docs.map(_fromDoc).toList();

      // Filtra localmente pelo escopo/hierarquia.
      Set<String> maanaimRegionIds = const {};
      final maanaimId = me.regionId ?? '';
      if (me.role == UserRole.maanaim && maanaimId.isNotEmpty) {
        final regions = await _geo.regionsByMaanaim(maanaimId);
        maanaimRegionIds = regions.map((e) => e.id).toSet();
      }

      bool inScopeLocal(Rehearsal r) {
        switch (me.role) {
          case UserRole.admin:
            return true;
          case UserRole.polo:
            return r.level == RehearsalLevel.polo && r.poloId == me.poloId;
          case UserRole.area:
            return (r.level == RehearsalLevel.area || r.level == RehearsalLevel.polo) && r.areaId == me.areaId;
          case UserRole.region:
            return (r.level == RehearsalLevel.region || r.level == RehearsalLevel.area || r.level == RehearsalLevel.polo) &&
                r.regionId == me.regionId;
          case UserRole.maanaim:
            return (r.level == RehearsalLevel.maanaim && r.regionId == maanaimId) ||
                (r.level != RehearsalLevel.maanaim && maanaimRegionIds.contains(r.regionId));
          case UserRole.readonly:
            if ((me.poloId ?? '').isNotEmpty) {
              return r.level == RehearsalLevel.polo && r.poloId == me.poloId;
            }
            if ((me.areaId ?? '').isNotEmpty) {
              return r.level == RehearsalLevel.area && r.areaId == me.areaId;
            }
            if ((me.regionId ?? '').isNotEmpty) {
              return r.level == RehearsalLevel.region && r.regionId == me.regionId;
            }
            return false;
        }
      }

      final filtered = all.where(inScopeLocal).toList()
        ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
      return filtered;
    }
  }


  @override
  Future<Rehearsal> getById(String id) async {
    final doc = await _col.doc(id).get();
    if (!doc.exists) throw StateError('Rehearsal $id not found');
    return _fromDoc(doc);
  }

  @override
  Future<Rehearsal?> nextUpcoming() async {
    final me = await _waitProfile();
    if (me == null || !_hasValidScope(me)) return null;

    final now = DateTime.now();

    Query<Map<String, dynamic>> q = _applyScope(
      _col
          .where('closed', isEqualTo: false)
          .where('dateTime', isGreaterThanOrEqualTo: Timestamp.fromDate(now))
          .orderBy('dateTime')
          .limit(1),
      me,
    );

    try {
      final snap = await q.get();
      if (snap.docs.isEmpty) return null;
      return _fromDoc(snap.docs.first);
    } on FirebaseException catch (e) {
      if (!_isRecoverableQueryError(e)) rethrow;
      if (e.code != 'failed-precondition') return null;
      try {
        final snap = await _applyScope(
          _col
              .where('dateTime', isGreaterThanOrEqualTo: Timestamp.fromDate(now))
              .orderBy('dateTime')
              .limit(10),
          me,
        ).get();
        for (final d in snap.docs) {
          final r = _fromDoc(d);
          if (!r.closed) return r;
        }
      } on FirebaseException {
        return null;
      }
      return null;
    }
  }

  @override
  Future<void> close(String id) async {
    await _col.doc(id).update({
      'closed': true,
      'closedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  @override
  Future<Rehearsal> update({
    required String id,
    required DateTime dateTime,
    required RehearsalLevel level,
    required String regionId,
    required EventType eventType,
    String? title,
    String? areaId,
    String? poloId,
    String? place,
    String? description,
    EventParticipantMode participantMode = EventParticipantMode.all,
    List<String> expectedParticipants = const [],
    bool? closed,
    DateTime? closedAt,
  }) async {
    final data = _toMap(
      dateTime: dateTime,
      level: level,
      regionId: regionId,
      eventType: eventType,
      title: title,
      areaId: areaId,
      poloId: poloId,
      place: place,
      description: description,
      participantMode: participantMode,
      expectedParticipants: expectedParticipants,
      closed: closed ?? false,
      closedAt: closedAt,
    );
    await _col.doc(id).set(data, SetOptions(merge: true));
    final snap = await _col.doc(id).get();
    return _fromDoc(snap);
  }

  @override
  Future<void> setParticipantsSnapshot(String id, List<String> personIds) async {
    await _col.doc(id).update({'participantsSnapshot': personIds});
  }

  @override
  Future<void> delete(String id) async {
    await _col.doc(id).delete();
  }
}
