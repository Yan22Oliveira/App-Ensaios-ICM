import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:flutter/foundation.dart';
import 'package:equatable/equatable.dart';

import '../../src.dart';

class _Omit {
  const _Omit();
}

const _omit = _Omit();

class RehearsalListState extends Equatable {
  final bool loading;
  final List<Rehearsal> items;
  final String? search;
  /// Filtro por tipo de evento (multi-seleção). Vazio = todos os tipos.
  final Set<EventType> eventTypesFilter;
  /// Filtro por níveis (multi-seleção). Vazio = "todos os níveis permitidos".
  final Set<RehearsalLevel> levelsFilter;
  final RehearsalLevel? levelFilter;
  /// Armazena o regionId (ex.: "divinopolis")
  final String? regionFilter;
  /// Armazena o areaId (quando filtra por Área)
  final String? areaFilter;
  /// Armazena o poloId (quando filtra por Polo)
  final String? poloFilter;
  /// Quando definido, lista apenas ensaios do dia selecionado (00:00–23:59).
  final DateTime? dayFilter;
  /// Status do relatório por eventId. Ausência da chave = não iniciado.
  final Map<String, EventReportStatus> reportStatusByEventId;
  /// true = mostrar apenas ensaios encerrados; false = próximos
  final bool showClosed;

  const RehearsalListState({
    required this.loading,
    required this.items,
    this.search,
    this.eventTypesFilter = const {},
    this.levelsFilter = const {},
    this.levelFilter,
    this.regionFilter,
    this.areaFilter,
    this.poloFilter,
    this.dayFilter,
    this.reportStatusByEventId = const {},
    this.showClosed = false,
  });

  factory RehearsalListState.initial() =>
      const RehearsalListState(loading: false, items: []);

  RehearsalListState copyWith({
    bool? loading,
    List<Rehearsal>? items,
    Object? search = _omit,
    Set<EventType>? eventTypesFilter,
    Set<RehearsalLevel>? levelsFilter,
    Object? levelFilter = _omit,
    Object? regionFilter = _omit,
    Object? areaFilter = _omit,
    Object? poloFilter = _omit,
    Object? dayFilter = _omit,
    Map<String, EventReportStatus>? reportStatusByEventId,
    bool? showClosed,
  }) {
    return RehearsalListState(
      loading: loading ?? this.loading,
      items: items ?? this.items,
      search: identical(search, _omit) ? this.search : search as String?,
      eventTypesFilter: eventTypesFilter ?? this.eventTypesFilter,
      levelsFilter: levelsFilter ?? this.levelsFilter,
      levelFilter: identical(levelFilter, _omit) ? this.levelFilter : levelFilter as RehearsalLevel?,
      regionFilter: identical(regionFilter, _omit) ? this.regionFilter : regionFilter as String?,
      areaFilter: identical(areaFilter, _omit) ? this.areaFilter : areaFilter as String?,
      poloFilter: identical(poloFilter, _omit) ? this.poloFilter : poloFilter as String?,
      dayFilter: identical(dayFilter, _omit) ? this.dayFilter : dayFilter as DateTime?,
      reportStatusByEventId: reportStatusByEventId ?? this.reportStatusByEventId,
      showClosed: showClosed ?? this.showClosed,
    );
  }

  @override
  List<Object?> get props => [
    loading,
    items,
    search,
    eventTypesFilter,
    levelsFilter,
    levelFilter,
    regionFilter,
    areaFilter,
    poloFilter,
    dayFilter,
    reportStatusByEventId,
    showClosed,
  ];
}

class RehearsalListController extends Cubit<RehearsalListState> {
  final IRehearsalRepository repo;
  final IEventReportRepository reportRepo;
  StreamSubscription<List<Rehearsal>>? _subscription;

  RehearsalListController(this.repo, this.reportRepo) : super(RehearsalListState.initial());

  /// Inicia o stream em tempo real (lista atualiza sozinha).
  void startWatch() {
    debugPrint('[RehearsalList] startWatch() _subscription=${_subscription != null}');
    if (_subscription != null) return;
    _subscribe();
  }

  void _subscribe() {
    _subscription?.cancel();
    final showClosed = state.showClosed;
    debugPrint('[RehearsalList] _subscribe() showClosed=$showClosed');
    emit(state.copyWith(loading: true));
    final stream = showClosed ? repo.watchClosed() : repo.watchUpcoming();
    _subscription = stream.listen(
      (items) {
        debugPrint('[RehearsalList] stream.listen DATA: items.length=${items.length} isClosed=$isClosed');
        if (isClosed) return;
        // Firestore pode emitir rapidamente em sequência; garantimos lista sem duplicatas por id.
        final byId = <String, Rehearsal>{};
        for (final r in items) {
          byId[r.id] = r;
        }
        emit(state.copyWith(loading: false, items: byId.values.toList()));
        _loadReportStatuses(byId.keys.toList());
      },
      onError: (e, st) {
        debugPrint('[RehearsalList] stream.listen ERROR: $e');
        debugPrint('[RehearsalList] $st');
        // Não zera a lista: mantém o que já veio (ex.: do cache) quando o índice falta no Firestore.
        if (!isClosed) emit(state.copyWith(loading: false));
      },
    );
  }

  /// Alterna entre "Próximos" e "Encerrados".
  void setShowClosed(bool value) {
    debugPrint('[RehearsalList] setShowClosed($value) current=${state.showClosed}');
    if (state.showClosed == value) return;
    emit(state.copyWith(showClosed: value));
    _subscribe();
  }

  /// Recarrega a lista (pull-to-refresh).
  Future<void> refresh() async {
    final items = state.showClosed
        ? await repo.listClosed()
        : await repo.listUpcoming();
    emit(state.copyWith(loading: false, items: items));
    await _loadReportStatuses(items.map((e) => e.id).toList());
  }

  Future<void> load() async {
    emit(state.copyWith(loading: true));
    final items = state.showClosed
        ? await repo.listClosed()
        : await repo.listUpcoming();
    emit(state.copyWith(loading: false, items: items));
    await _loadReportStatuses(items.map((e) => e.id).toList());
  }

  Future<void> refreshReportStatuses() async {
    await _loadReportStatuses(state.items.map((e) => e.id).toList());
  }

  Future<void> _loadReportStatuses(List<String> eventIds) async {
    if (eventIds.isEmpty) {
      emit(state.copyWith(reportStatusByEventId: const {}));
      return;
    }
    final map = <String, EventReportStatus>{};
    const chunkSize = 20;
    for (var i = 0; i < eventIds.length; i += chunkSize) {
      final end = (i + chunkSize).clamp(0, eventIds.length);
      final chunk = eventIds.sublist(i, end);
      await Future.wait(chunk.map((id) async {
        try {
          final report = await reportRepo.getByEventId(id);
          if (report != null) map[id] = report.status;
        } catch (_) {}
      }));
    }
    if (isClosed) return;
    emit(state.copyWith(reportStatusByEventId: map));
  }

  @override
  Future<void> close() {
    debugPrint('[RehearsalList] close() controller sendo fechado');
    _subscription?.cancel();
    return super.close();
  }

  void search(String term) => emit(state.copyWith(search: term));

  void clearFilters() {
    emit(state.copyWith(
      search: '',
      eventTypesFilter: const {},
      levelsFilter: const {},
      levelFilter: null,
      regionFilter: null,
      areaFilter: null,
      poloFilter: null,
      dayFilter: null,
      showClosed: false,
    ));
  }

  void setEventTypesFilter(Set<EventType> types) {
    emit(state.copyWith(eventTypesFilter: {...types}));
  }

  void setLevelsFilter(Set<RehearsalLevel> levels) {
    // Normaliza para evitar alterações semânticas (ordem/instância).
    emit(state.copyWith(levelsFilter: {...levels}));
  }

  void setLevelFilter(RehearsalLevel? level) {
    if (state.levelFilter == level) return;
    // Ao mudar nível, limpamos os filtros dependentes para evitar estado inválido.
    emit(state.copyWith(
      levelFilter: level,
      levelsFilter: const {},
      regionFilter: null,
      areaFilter: null,
      poloFilter: null,
    ));
  }

  void setGeoFilters({String? regionId, String? areaId, String? poloId}) {
    emit(state.copyWith(
      regionFilter: regionId,
      areaFilter: areaId,
      poloFilter: poloId,
    ));
  }

  void setDayFilter(DateTime? day) {
    if (day == null) {
      emit(state.copyWith(dayFilter: null));
      return;
    }
    final d = DateTime(day.year, day.month, day.day);
    emit(state.copyWith(dayFilter: d));
  }

  /// Inserir novo item localmente (após criação) sem esperar nova consulta
  void insert(Rehearsal r) {
    // Evita duplicar quando o stream já trouxe o mesmo ensaio.
    final list = [...state.items];
    final i = list.indexWhere((e) => e.id == r.id);
    if (i >= 0) {
      list[i] = r;
    } else {
      list.add(r);
    }
    emit(state.copyWith(items: list));
  }

  List<Rehearsal> get filtered {
    var r = List<Rehearsal>.from(state.items);
    final s = (state.search ?? '').trim().toLowerCase();
    if (s.isNotEmpty) {
      r = r
          .where((e) =>
              e.displayTitle.toLowerCase().contains(s) ||
              e.eventType.label.toLowerCase().contains(s) ||
              e.regionId.toLowerCase().contains(s) ||
              (e.place ?? '').toLowerCase().contains(s) ||
              (e.description ?? '').toLowerCase().contains(s))
          .toList();
    }
    if (state.eventTypesFilter.isNotEmpty) {
      r = r.where((e) => state.eventTypesFilter.contains(e.eventType)).toList();
    }
    if (state.levelFilter != null) {
      r = r.where((e) => e.level == state.levelFilter).toList();
    }
    if (state.levelsFilter.isNotEmpty) {
      r = r.where((e) => state.levelsFilter.contains(e.level)).toList();
    }
    if (state.regionFilter != null && state.regionFilter!.isNotEmpty) {
      r = r.where((e) => e.regionId == state.regionFilter).toList();
    }
    if (state.areaFilter != null && state.areaFilter!.isNotEmpty) {
      r = r.where((e) => e.areaId == state.areaFilter).toList();
    }
    if (state.poloFilter != null && state.poloFilter!.isNotEmpty) {
      r = r.where((e) => e.poloId == state.poloFilter).toList();
    }
    if (state.dayFilter != null) {
      final d = state.dayFilter!;
      r = r.where((e) =>
          e.dateTime.year == d.year &&
          e.dateTime.month == d.month &&
          e.dateTime.day == d.day).toList();
    }
    r.sort((a, b) => state.showClosed
        ? b.dateTime.compareTo(a.dateTime)
        : a.dateTime.compareTo(b.dateTime));
    return r;
  }

  void replace(Rehearsal r) {
    final list = [...state.items];
    final i = list.indexWhere((e) => e.id == r.id);
    if (i >= 0) list[i] = r;
    emit(state.copyWith(items: list));
  }

  void remove(String id) {
    final list = state.items.where((e) => e.id != id).toList();
    emit(state.copyWith(items: list));
  }

}
