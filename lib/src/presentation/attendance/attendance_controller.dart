import 'package:bloc/bloc.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../src.dart';

class AttendanceController extends Cubit<AttendanceState> {
  final IRehearsalRepository rehearsalRepo;
  final IPersonRepository personRepo;
  final IAttendanceRepository attendanceRepo;

  final String rehearsalId;
  final String currentUserId;

  final _uuid = const Uuid();

  AttendanceController({
    required this.rehearsalRepo,
    required this.personRepo,
    required this.attendanceRepo,
    required this.rehearsalId,
    required this.currentUserId,
  }) : super(AttendanceState.initial());

  /// Carrega o ensaio, lista de pessoas (filtrada por nível) e registros existentes
  Future<void> load() async {
    emit(state.copyWith(loading: true, clearError: true));

    try {
      final rehearsal = await rehearsalRepo.getById(rehearsalId);

      debugPrint('[Chamada] Ensaio carregado: id=${rehearsal.id} level=${rehearsal.level.name} regionId=${rehearsal.regionId} areaId=${rehearsal.areaId} poloId=${rehearsal.poloId}');

      // 1) primeiro limitamos por escopo geográfico via Firestore
      List<Person> scoped;
      switch (rehearsal.level) {
        case RehearsalLevel.maanaim: {
          final regionId = rehearsal.regionId.trim().isEmpty ? null : rehearsal.regionId;
          // Se o ensaio não tem região definida (regionId vazio no Firestore), busca todas as pessoas maanaim.
          if (regionId == null) {
            debugPrint('[Chamada] Maanaim com regionId vazio no ensaio: buscando todas as pessoas worshipLevel=maanaim (sem filtro de região).');
          }
          scoped = await personRepo.list(
            regionId: regionId,
            worshipLevel: RehearsalLevel.maanaim,
          );
          debugPrint('[Chamada] Maanaim: personRepo.list(regionId=$regionId, worshipLevel=maanaim) retornou ${scoped.length} pessoa(s)');
          break;
        }
        case RehearsalLevel.region:
          scoped = await personRepo.list(regionId: rehearsal.regionId);
          break;
        case RehearsalLevel.area:
          scoped = await personRepo.list(
            regionId: rehearsal.regionId,
            areaId: rehearsal.areaId,
          );
          break;
        case RehearsalLevel.polo:
          scoped = await personRepo.list(
            regionId: rehearsal.regionId,
            areaId: rehearsal.areaId,
            poloId: rehearsal.poloId,
          );
          break;
      }

      // 2) Regras de pertencimento: Maanaim só maanaim da região; Região = região ou maanaim; Área = área/região/maanaim; Polo = todos do polo.
      bool include(Person p) {
        switch (rehearsal.level) {
          case RehearsalLevel.maanaim: {
            // Se o ensaio não tem região, inclui todas as pessoas maanaim já trazidas pelo repo.
            final rehearsalRegion = rehearsal.regionId.trim();
            final ok = p.worshipLevel == RehearsalLevel.maanaim &&
                (rehearsalRegion.isEmpty || p.regionId == rehearsal.regionId);
            if (kDebugMode) {
              debugPrint('[Chamada] include(maanaim): "${p.fullName}" | worshipLevel=${p.worshipLevel.name} regionId="${p.regionId}" (ensaio regionId="${rehearsal.regionId}") => $ok');
            }
            return ok;
          }

          case RehearsalLevel.region:
          // Region/ Maanaim da MESMA região
            return (p.regionId == rehearsal.regionId) &&
                (p.worshipLevel == RehearsalLevel.region ||
                    p.worshipLevel == RehearsalLevel.maanaim);

          case RehearsalLevel.area:
          // Area/Region/Maanaim da MESMA área
            return (p.areaId != null &&
                p.areaId == rehearsal.areaId) &&
                (p.worshipLevel == RehearsalLevel.area ||
                    p.worshipLevel == RehearsalLevel.region ||
                    p.worshipLevel == RehearsalLevel.maanaim);

          case RehearsalLevel.polo:
          // Qualquer nível (inclui superiores) do MESMO polo
            return (p.poloId != null &&
                p.poloId == rehearsal.poloId) &&
                (p.worshipLevel == RehearsalLevel.polo ||
                    p.worshipLevel == RehearsalLevel.area ||
                    p.worshipLevel == RehearsalLevel.region ||
                    p.worshipLevel == RehearsalLevel.maanaim);
        }
      }

      final persons = scoped.where(include).toList()..sort((a,b)=>a.fullName.compareTo(b.fullName));

      debugPrint('[Chamada] Após filtro include(): ${persons.length} participante(s) na lista final. Nível do ensaio: ${rehearsal.level.name}');

    // Registros existentes
      final list = await attendanceRepo.listByRehearsal(rehearsalId);
      final recordsMap = {for (final r in list) r.personId: r};

      emit(state.copyWith(
        loading: false,
        rehearsal: rehearsal,
        participants: persons,
        records: recordsMap,
        clearError: true,
      ));
    } catch (e) {
      emit(state.copyWith(
        loading: false,
        errorMessage: 'Falha ao carregar chamada: ${e.toString()}',
      ));
    }
  }

  Future<void> finalize() async {
    if (state.rehearsal == null || state.isClosed) return;
    await rehearsalRepo.close(state.rehearsal!.id);
    await load(); // recarrega para refletir closed=true
  }

  // ======== Busca e filtragem local ========

  void searchByName(String term) => emit(state.copyWith(search: term));

  List<Person> get filteredParticipants {
    final term = (state.search ?? '').trim().toLowerCase();
    if (term.isEmpty) return state.participants;
    return state.participants.where((p) {
      final inName = p.fullName.toLowerCase().contains(term);
      final inEmail = (p.email ?? '').toLowerCase().contains(term);
      final inPhone = (p.phone ?? '').toLowerCase().contains(term);
      final inRoles = p.roles.any((r) => r.toLowerCase().contains(term));
      return inName || inEmail || inPhone || inRoles;
    }).toList();
  }

  // ======== Métricas rápidas (P/F/J) ========

  int get presentCount =>
      state.records.values.where((r) => r.status == AttendanceStatus.present).length;

  int get unjustifiedCount =>
      state.records.values.where((r) => r.status == AttendanceStatus.unjustifiedAbsence).length;

  int get justifiedCount =>
      state.records.values.where((r) => r.status == AttendanceStatus.justifiedAbsence).length;

  // ======== Ações de marcação ========

  Future<void> setStatus(
      Person person,
      AttendanceStatus status, {
        String? justification,
      }) async {
    await _saveStatus(person, status, justification: justification);
  }

  Future<void> toggleStatus(Person person) async {
    final current = state.records[person.id]?.status ?? AttendanceStatus.unmarked;
    final next = _next(current);
    await _saveStatus(person, next);
  }

  Future<void> saveJustification(Person person, String text) async {
    await _saveStatus(person, AttendanceStatus.justifiedAbsence, justification: text);
  }

  /// Marca todos os participantes **visíveis** (após busca/filtro local)
  Future<void> markAll(AttendanceStatus status) async {
    final now = DateTime.now();
    final toUpdate = <AttendanceRecord>[];
    final nextMap = Map<String, AttendanceRecord>.from(state.records);

    for (final p in filteredParticipants) {
      final existing = nextMap[p.id];
      final newId = existing?.id ?? _uuid.v4();
      final rec = AttendanceRecord(
        id: newId,
        rehearsalId: rehearsalId,
        personId: p.id,
        status: status,
        justification: status == AttendanceStatus.justifiedAbsence
            ? (existing?.justification) // mantém a justificativa existente (se houver)
            : null,
        markedAt: now,
        markedByUserId: currentUserId,
      );
      toUpdate.add(rec);
      nextMap[p.id] = rec;
    }

    // Persiste em lote (mock aceita ids gerados; não usamos 'TEMP' para evitar troca de id)
    await attendanceRepo.upsertMany(toUpdate);

    emit(state.copyWith(records: nextMap));
  }

  /// Indica se um participante marcado como Justificado está sem texto de justificativa
  bool needsJustification(Person person) {
    final rec = state.records[person.id];
    return rec?.status == AttendanceStatus.justifiedAbsence &&
        ((rec?.justification ?? '').trim().isEmpty);
  }

  // ======== Internos ========

  AttendanceStatus _next(AttendanceStatus s) {
    switch (s) {
      case AttendanceStatus.unmarked:
        return AttendanceStatus.present;
      case AttendanceStatus.present:
        return AttendanceStatus.justifiedAbsence;
      case AttendanceStatus.justifiedAbsence:
        return AttendanceStatus.unjustifiedAbsence;
      case AttendanceStatus.unjustifiedAbsence:
        return AttendanceStatus.unmarked;
    }
  }

  Future<void> _saveStatus(
      Person person,
      AttendanceStatus status, {
        String? justification,
      }) async {
    final existing = state.records[person.id];
    final record = AttendanceRecord(
      id: existing?.id ?? _uuid.v4(),
      rehearsalId: rehearsalId,
      personId: person.id,
      status: status,
      justification: status == AttendanceStatus.justifiedAbsence
          ? (justification ?? existing?.justification)
          : null,
      markedAt: DateTime.now(),
      markedByUserId: currentUserId,
    );

// salva e atualiza o estado
    await attendanceRepo.upsert(record);
    final list = await attendanceRepo.listByRehearsal(rehearsalId);
    final map = { for (final r in list) r.personId : r };
    emit(state.copyWith(records: map));
  }
}
