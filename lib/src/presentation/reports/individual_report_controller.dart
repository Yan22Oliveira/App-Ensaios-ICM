import 'package:flutter/material.dart';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../src.dart';

class IndividualReportState extends Equatable {
  final bool loading;
  final PersonSummary summary;
  final ReportFilters filters;
  final List<Region> regions;
  final List<Area> areas;
  final List<Polo> polos;
  final bool lockRegion;
  final bool lockArea;
  final bool lockPolo;
  final String? errorMessage;

  const IndividualReportState({
    required this.loading,
    required this.summary,
    required this.filters,
    this.regions = const [],
    this.areas = const [],
    this.polos = const [],
    this.lockRegion = false,
    this.lockArea = false,
    this.lockPolo = false,
    this.errorMessage,
  });

  bool get isEmpty => summary.events.isEmpty;

  IndividualReportState copyWith({
    bool? loading,
    PersonSummary? summary,
    ReportFilters? filters,
    List<Region>? regions,
    List<Area>? areas,
    List<Polo>? polos,
    bool? lockRegion,
    bool? lockArea,
    bool? lockPolo,
    String? errorMessage,
    bool clearError = false,
  }) {
    return IndividualReportState(
      loading: loading ?? this.loading,
      summary: summary ?? this.summary,
      filters: filters ?? this.filters,
      regions: regions ?? this.regions,
      areas: areas ?? this.areas,
      polos: polos ?? this.polos,
      lockRegion: lockRegion ?? this.lockRegion,
      lockArea: lockArea ?? this.lockArea,
      lockPolo: lockPolo ?? this.lockPolo,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [
        loading,
        summary,
        filters,
        regions,
        areas,
        polos,
        lockRegion,
        lockArea,
        lockPolo,
        errorMessage,
      ];
}

class IndividualReportController extends Cubit<IndividualReportState> {
  final IAttendanceRepository attendanceRepo;
  final IRehearsalRepository rehearsalRepo;
  final IGeoRepository geoRepo;
  final UserProfile? profile;

  IndividualReportController({
    required PersonSummary initialSummary,
    required ReportFilters initialFilters,
    required this.attendanceRepo,
    required this.rehearsalRepo,
    required this.geoRepo,
    this.profile,
    List<Region> regions = const [],
    List<Area> areas = const [],
    List<Polo> polos = const [],
    bool lockRegion = false,
    bool lockArea = false,
    bool lockPolo = false,
  }) : super(IndividualReportState(
          loading: false,
          summary: initialSummary,
          filters: initialFilters,
          regions: regions,
          areas: areas,
          polos: polos,
          lockRegion: lockRegion,
          lockArea: lockArea,
          lockPolo: lockPolo,
        ));

  Future<void> setFilters(ReportFilters filters, {List<Region>? regions, List<Area>? areas, List<Polo>? polos}) async {
    emit(state.copyWith(
      filters: filters,
      regions: regions,
      areas: areas,
      polos: polos,
    ));
    await reload();
  }

  Future<void> reload() async {
    emit(state.copyWith(loading: true, clearError: true));
    try {
      final person = state.summary.person;
      final range = state.filters.range ?? _defaultRange();
      if (profile != null && rehearsalRepo is FirestoreRehearsalRepository) {
        (rehearsalRepo as FirestoreRehearsalRepository).setScope(profile!);
      }
      final events = (await rehearsalRepo.listBetween(range.start, range.end))
          .where((r) => !r.dateTime.isBefore(range.start) && !r.dateTime.isAfter(range.end))
          .where((r) => rehearsalMatchesFilters(r, state.filters))
          .toList();

      final marks = <PersonEventMark>[];
      for (final rehearsal in events) {
        final records = await attendanceRepo.listByRehearsal(rehearsal.id);
        final mark = attendanceMarkForPerson(
          rehearsal: rehearsal,
          records: records,
          personId: person.id,
        );
        if (mark != null) marks.add(mark);
      }

      emit(state.copyWith(
        loading: false,
        summary: PersonSummary.fromMarks(person: person, marks: marks),
        clearError: true,
      ));
    } catch (e, st) {
      debugPrint('[IndividualReport] falha: $e\n$st');
      emit(state.copyWith(
        loading: false,
        errorMessage: 'Não foi possível carregar o relatório individual.',
      ));
    }
  }

  static DateTimeRange _defaultRange() {
    final now = DateTime.now();
    return DateTimeRange(
      start: DateTime(now.year, now.month, 1),
      end: DateTime(now.year, now.month + 1, 0),
    );
  }
}
