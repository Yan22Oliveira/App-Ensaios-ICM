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
  late final EventParticipantsResolver _participantsResolver;

  AttendanceController({
    required this.rehearsalRepo,
    required this.personRepo,
    required this.attendanceRepo,
    required this.rehearsalId,
    required this.currentUserId,
  }) : super(AttendanceState.initial()) {
    _participantsResolver = EventParticipantsResolver(personRepo);
  }

  /// Carrega o ensaio, lista de pessoas (filtrada por nível) e registros existentes
  Future<void> load() async {
    emit(state.copyWith(loading: true, clearError: true));

    try {
      final rehearsal = await rehearsalRepo.getById(rehearsalId);

      debugPrint('[Chamada] Ensaio carregado: id=${rehearsal.id} level=${rehearsal.level.name} regionId=${rehearsal.regionId} areaId=${rehearsal.areaId} poloId=${rehearsal.poloId} mode=${rehearsal.participantMode.name}');

      final persons = await _participantsResolver.resolve(rehearsal);

      debugPrint('[Chamada] Participantes resolvidos: ${persons.length}. snapshot=${rehearsal.participantsSnapshot != null} mode=${rehearsal.participantMode.name}');

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
    await _ensureSnapshot();
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

  int get unmarkedCount => state.participants.where((p) {
        final status = state.records[p.id]?.status ?? AttendanceStatus.unmarked;
        return status == AttendanceStatus.unmarked;
      }).length;

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
    await _ensureSnapshot();
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
    await _ensureSnapshot();
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

  Future<void> _ensureSnapshot() async {
    final rehearsal = state.rehearsal;
    if (rehearsal == null || rehearsal.participantsSnapshot != null) return;
    final ids = state.participants.map((p) => p.id).toList();
    await rehearsalRepo.setParticipantsSnapshot(rehearsal.id, ids);
    emit(state.copyWith(rehearsal: rehearsal.copyWith(participantsSnapshot: ids)));
  }
}
