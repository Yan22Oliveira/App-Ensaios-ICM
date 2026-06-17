import 'dart:async';

import 'package:flutter/material.dart';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../src.dart';

enum ReportsTab { overview, byPerson, byRehearsal, raw }

class ReportFilters extends Equatable {
  final DateTimeRange? range;
  final RehearsalLevel? level;
  final String? regionId;
  final String? areaId;
  final String? poloId;
  final bool onlyWithRecords;

  const ReportFilters({
    required this.range,
    this.level,
    this.regionId,
    this.areaId,
    this.poloId,
    this.onlyWithRecords = true,
  });

  ReportFilters copyWith({
    DateTimeRange? range,
    RehearsalLevel? level,
    String? regionId,
    String? areaId,
    String? poloId,
    bool? onlyWithRecords,
  }) {
    return ReportFilters(
      range: range ?? this.range,
      level: level ?? this.level,
      regionId: regionId ?? this.regionId,
      areaId: areaId ?? this.areaId,
      poloId: poloId ?? this.poloId,
      onlyWithRecords: onlyWithRecords ?? this.onlyWithRecords,
    );
  }

  @override
  List<Object?> get props => [range, level, regionId, areaId, poloId, onlyWithRecords];
}

class PersonSummary extends Equatable {
  final Person person;
  final int present;
  final int unjustified;
  final int justified;

  const PersonSummary({required this.person, required this.present, required this.unjustified, required this.justified});

  double get attendanceRate {
    final total = present + unjustified + justified;
    if (total == 0) return 0;
    return present / total;
  }

  @override
  List<Object?> get props => [person, present, unjustified, justified];
}

class RehearsalSummary extends Equatable {
  final Rehearsal rehearsal;
  final int present;
  final int unjustified;
  final int justified;

  const RehearsalSummary({required this.rehearsal, required this.present, required this.unjustified, required this.justified});

  double get attendanceRate {
    final total = present + unjustified + justified;
    if (total == 0) return 0;
    return present / total;
  }

  @override
  List<Object?> get props => [rehearsal, present, unjustified, justified];
}

class ReportsState extends Equatable {
  final bool loading;
  final ReportsTab tab;
  final ReportFilters filters;
  final List<PersonSummary> byPerson;
  final List<RehearsalSummary> byRehearsal;
  // Overview
  final int totalRehearsals;
  final double attendanceRate;
  final double justificationRate;
  final int peopleCovered;

  const ReportsState({
    required this.loading,
    required this.tab,
    required this.filters,
    required this.byPerson,
    required this.byRehearsal,
    required this.totalRehearsals,
    required this.attendanceRate,
    required this.justificationRate,
    required this.peopleCovered,
  });

  factory ReportsState.initial() => ReportsState(
    loading: false,
    tab: ReportsTab.overview,
    filters: ReportFilters(range: null),
    byPerson: const [],
    byRehearsal: const [],
    totalRehearsals: 0,
    attendanceRate: 0,
    justificationRate: 0,
    peopleCovered: 0,
  );

  ReportsState copyWith({
    bool? loading,
    ReportsTab? tab,
    ReportFilters? filters,
    List<PersonSummary>? byPerson,
    List<RehearsalSummary>? byRehearsal,
    int? totalRehearsals,
    double? attendanceRate,
    double? justificationRate,
    int? peopleCovered,
  }) {
    return ReportsState(
      loading: loading ?? this.loading,
      tab: tab ?? this.tab,
      filters: filters ?? this.filters,
      byPerson: byPerson ?? this.byPerson,
      byRehearsal: byRehearsal ?? this.byRehearsal,
      totalRehearsals: totalRehearsals ?? this.totalRehearsals,
      attendanceRate: attendanceRate ?? this.attendanceRate,
      justificationRate: justificationRate ?? this.justificationRate,
      peopleCovered: peopleCovered ?? this.peopleCovered,
    );
  }

  @override
  List<Object?> get props => [
    loading, tab, filters, byPerson, byRehearsal,
    totalRehearsals, attendanceRate, justificationRate, peopleCovered
  ];
}

class ReportsController extends Cubit<ReportsState> {
  final IAttendanceRepository attendanceRepo;
  final IRehearsalRepository rehearsalRepo;
  final IPersonRepository personRepo;
  final IGeoRepository geoRepo;
  final GeoNameResolver geo;
  final UserProfile? profile;

  ReportsController({
    required this.attendanceRepo,
    required this.rehearsalRepo,
    required this.personRepo,
    required this.geoRepo,
    required this.geo,
    this.profile,
  }) : super(ReportsState.initial());

  void setTab(ReportsTab t) => emit(state.copyWith(tab: t));
  void setFilters(ReportFilters f) => _refresh(f);

  /// Lista pessoas dentro do escopo do perfil (mesma regra da lista de membros).
  Future<List<Person>> _listPeopleInScope() async {
    if (profile == null || profile!.role == UserRole.admin) {
      return personRepo.list();
    }
    if (profile!.role == UserRole.readonly) {
      if ((profile!.poloId ?? '').isNotEmpty) return personRepo.list(poloId: profile!.poloId);
      if ((profile!.areaId ?? '').isNotEmpty) return personRepo.list(areaId: profile!.areaId);
      if ((profile!.regionId ?? '').isNotEmpty) return personRepo.list(regionId: profile!.regionId);
      return personRepo.list();
    }
    if (profile!.role == UserRole.polo) {
      if ((profile!.poloId ?? '').isEmpty) return [];
      return personRepo.list(poloId: profile!.poloId);
    }
    if (profile!.role == UserRole.area) {
      return personRepo.list(areaId: profile!.areaId);
    }
    if (profile!.role == UserRole.region) {
      return personRepo.list(regionId: profile!.regionId);
    }
    if (profile!.role == UserRole.maanaim) {
      final regions = await geoRepo.regionsByMaanaim(profile!.regionId ?? '');
      final regionIds = regions.map((r) => r.id).toList();
      if (regionIds.isEmpty) return personRepo.list(regionId: profile!.regionId);
      return personRepo.list(regionIds: regionIds);
    }
    return personRepo.list();
  }

  /// Período padrão quando o usuário não escolhe datas (mês atual).
  static DateTimeRange _defaultRange() {
    final now = DateTime.now();
    return DateTimeRange(
      start: DateTime(now.year, now.month, 1),
      end: DateTime(now.year, now.month + 1, 0),
    );
  }

  Future<void> _refresh(ReportFilters newFilters) async {
    emit(state.copyWith(loading: true, filters: newFilters));

    final effectiveRange = newFilters.range ?? _defaultRange();

    // Garante escopo do perfil no repositório de ensaios (ex.: polo só vê ensaios do seu polo)
    if (profile != null && rehearsalRepo is FirestoreRehearsalRepository) {
      (rehearsalRepo as FirestoreRehearsalRepository).setScope(profile!);
    }

    debugPrint('[Reports] effectiveRange: ${effectiveRange.start} – ${effectiveRange.end}');

    // Ensaios escopados pelo repositório (setScope no Firestore)
    final allRehearsals = await rehearsalRepo.listBetween(effectiveRange.start, effectiveRange.end);
    debugPrint('[Reports] listBetween retornou ${allRehearsals.length} ensaio(s)');

    final inRange = allRehearsals.where((r) {
      return !r.dateTime.isBefore(effectiveRange.start) && !r.dateTime.isAfter(effectiveRange.end);
    }).where((r) {
      if (newFilters.level != null && r.level != newFilters.level) return false;
      if (newFilters.regionId != null && r.regionId != newFilters.regionId) return false;
      if (newFilters.areaId != null && r.areaId != newFilters.areaId) return false;
      if (newFilters.poloId != null && r.poloId != newFilters.poloId) return false;
      return true;
    }).toList();

    debugPrint('[Reports] inRange (após filtros level/region/area/polo): ${inRange.length} ensaio(s)');

    // Computa summaries por ensaio
    final byRehearsal = <RehearsalSummary>[];
    final personCounters = <String, (int p, int f, int j)>{};

    for (final reh in inRange) {
      final recs = await attendanceRepo.listByRehearsal(reh.id);
      int p = 0, f = 0, j = 0;
      for (final r in recs) {
        switch (r.status) {
          case AttendanceStatus.present: p++; break;
          case AttendanceStatus.unjustifiedAbsence: f++; break;
          case AttendanceStatus.justifiedAbsence: j++; break;
          default: break;
        }
        final tuple = personCounters[r.personId] ?? (0,0,0);
        personCounters[r.personId] = switch (r.status) {
          AttendanceStatus.present => (tuple.$1 + 1, tuple.$2, tuple.$3),
          AttendanceStatus.unjustifiedAbsence => (tuple.$1, tuple.$2 + 1, tuple.$3),
          AttendanceStatus.justifiedAbsence => (tuple.$1, tuple.$2, tuple.$3 + 1),
          _ => tuple,
        };
      }
      byRehearsal.add(RehearsalSummary(rehearsal: reh, present: p, unjustified: f, justified: j));
    }

    // Pessoas no escopo do usuário (permissões)
    final people = await _listPeopleInScope();
    debugPrint('[Reports] pessoas no escopo: ${people.length}');

    final byPerson = <PersonSummary>[];
    final coveredIds = <String>{};

    for (final p in people) {
      final tuple = personCounters[p.id] ?? (0,0,0);
      if (!newFilters.onlyWithRecords || (tuple.$1 + tuple.$2 + tuple.$3) > 0) {
        byPerson.add(PersonSummary(
          person: p, present: tuple.$1, unjustified: tuple.$2, justified: tuple.$3,
        ));
        if ((tuple.$1 + tuple.$2 + tuple.$3) > 0) coveredIds.add(p.id);
      }
    }

    // Overview KPIs
    final totalP = byRehearsal.fold<int>(0, (acc, e) => acc + e.present);
    final totalF = byRehearsal.fold<int>(0, (acc, e) => acc + e.unjustified);
    final totalJ = byRehearsal.fold<int>(0, (acc, e) => acc + e.justified);
    final totalMarked = totalP + totalF + totalJ;
    final double attendanceRate =
    totalMarked == 0 ? 0.0 : totalP / totalMarked;

    final double justificationRate =
    (totalF + totalJ) == 0 ? 0.0 : totalJ / (totalF + totalJ);

    byPerson.sort((a,b) => b.attendanceRate.compareTo(a.attendanceRate));
    byRehearsal.sort((a,b) => a.rehearsal.dateTime.compareTo(b.rehearsal.dateTime));

    emit(state.copyWith(
      loading: false,
      byPerson: byPerson,
      byRehearsal: byRehearsal,
      totalRehearsals: inRange.length,
      attendanceRate: attendanceRate,
      justificationRate: justificationRate,
      peopleCovered: coveredIds.length,
    ));
  }

  /// CSV simples para qualquer aba — retorna string pronta para gravar em arquivo.
  String buildCsvRaw() {
    final buffer = StringBuffer('date;time;level;region;area;polo;rehearsalId;personId;personName;status;justification\n');
    for (final s in state.byRehearsal) {
      // No MVP exportamos agregados como linhas sintéticas (poderia buscar raw record por record também)
      buffer.writeln('${_d(s.rehearsal.dateTime)};${_t(s.rehearsal.dateTime)};'
          '${s.rehearsal.level.name};'
          '${geo.regionName(s.rehearsal.regionId) ?? s.rehearsal.regionId};'
          '${s.rehearsal.areaId != null ? (geo.areaName(s.rehearsal.areaId!) ?? s.rehearsal.areaId!) : ''};'
          '${s.rehearsal.poloId != null ? (geo.poloName(s.rehearsal.poloId!) ?? s.rehearsal.poloId!) : ''};'
          '${s.rehearsal.id};;;' // placeholders para person
          'AGGREGATE;P:${s.present}|F:${s.unjustified}|J:${s.justified}');
    }
    return buffer.toString();
  }

  String _d(DateTime d) => '${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}/${d.year}';
  String _t(DateTime d) => '${d.hour.toString().padLeft(2,'0')}:${d.minute.toString().padLeft(2,'0')}';
}
