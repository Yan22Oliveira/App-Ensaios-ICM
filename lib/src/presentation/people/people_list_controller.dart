import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

import '../../src.dart';

class PeopleListState extends Equatable {
  final bool loading;
  final List<Person> items;
  final String? search;
  final String? regionFilter;
  final String? areaFilter;
  final String? poloFilter;
  final List<String> roleFilter;
  final List<String> debugLines;

  /// true = incluir níveis abaixo (Região/Área/Polo); false = só o próprio nível (Maanaim/Região/Área).
  final bool expandScopeFilter;

  /// Perfil do usuário logado (para saber escopo e filtros disponíveis).
  final UserProfile? profile;

  const PeopleListState({
    required this.loading,
    required this.items,
    this.search,
    this.regionFilter,
    this.areaFilter,
    this.poloFilter,
    this.roleFilter = const [],
    this.debugLines = const [],
    this.expandScopeFilter = false,
    this.profile,
  });

  factory PeopleListState.initial() =>
      const PeopleListState(loading: false, items: []);

  static const _omit = _Omit();

  PeopleListState copyWith({
    bool? loading,
    List<Person>? items,
    String? search,
    Object? regionFilter = _omit,
    Object? areaFilter = _omit,
    Object? poloFilter = _omit,
    List<String>? roleFilter,
    List<String>? debugLines,
    bool? expandScopeFilter,
    UserProfile? profile,
  }) {
    return PeopleListState(
      loading: loading ?? this.loading,
      items: items ?? this.items,
      search: search ?? this.search,
      regionFilter: regionFilter == _omit ? this.regionFilter : regionFilter as String?,
      areaFilter: areaFilter == _omit ? this.areaFilter : areaFilter as String?,
      poloFilter: poloFilter == _omit ? this.poloFilter : poloFilter as String?,
      roleFilter: roleFilter ?? this.roleFilter,
      debugLines: debugLines ?? this.debugLines,
      expandScopeFilter: expandScopeFilter ?? this.expandScopeFilter,
      profile: profile ?? this.profile,
    );
  }

  bool get showScopeFilterToggle =>
      profile != null &&
      profile!.role != UserRole.admin &&
      profile!.role != UserRole.readonly &&
      (profile!.role == UserRole.area ||
          profile!.role == UserRole.region ||
          profile!.role == UserRole.maanaim);

  @override
  List<Object?> get props => [
    loading,
    items,
    search,
    regionFilter,
    areaFilter,
    poloFilter,
    roleFilter,
    debugLines,
    expandScopeFilter,
    profile?.uid,
  ];
}

class PeopleListController extends Cubit<PeopleListState> {
  final IPersonRepository _repo;
  final IGeoRepository _geo;

  StreamSubscription<List<Person>>? _subscription;

  PeopleListController(this._repo, this._geo)
    : super(PeopleListState.initial());

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }

  Future<void> load(UserProfile? profile) async {
    // Padrão: secretário vê primeiro só o próprio nível (Maanaim/Região/Área/Polo). Filtros no sheet incluem níveis abaixo.
    emit(state.copyWith(
      loading: true,
      debugLines: [],
      profile: profile,
      expandScopeFilter: false,
      regionFilter: null,
      areaFilter: null,
      poloFilter: null,
    ));

    await _subscription?.cancel();
    _subscription = null;

    Stream<List<Person>> stream;
    if (profile == null ||
        profile.role == UserRole.admin ||
        profile.role == UserRole.readonly) {
      stream = _repo.watchList();
    } else if (profile.role == UserRole.polo) {
      if ((profile.poloId ?? '').isEmpty) {
        stream = Stream.value([]);
      } else {
        stream = _repo.watchList(poloId: profile.poloId);
      }
    } else if (profile.role == UserRole.area) {
      // Sempre carrega toda a área; expandScopeFilter define se mostra só nível Área ou Área+Polos
      stream = _repo.watchList(areaId: profile.areaId);
    } else if (profile.role == UserRole.region) {
      // Sempre carrega toda a região; expandScopeFilter define se mostra só nível Região ou todos
      stream = _repo.watchList(regionId: profile.regionId);
    } else if (profile.role == UserRole.maanaim) {
      // Sempre carrega todas as regiões do Maanaim; expandScopeFilter define se mostra só Maanaim ou todos
      final regions = await _geo.regionsByMaanaim(profile.regionId ?? '');
      final regionIds = regions.map((r) => r.id).toList();
      stream =
          regionIds.isEmpty
              ? _repo.watchList(regionId: profile.regionId)
              : _repo.watchList(regionIds: regionIds);
    } else {
      stream = _repo.watchList();
    }

    _subscription = stream.listen(
      (items) {
        final List<String> debugLines = [];
        if (kDebugMode) {
          debugLines.add('watchList → ${items.length} pessoa(s)');
          final byLevel = <RehearsalLevel, int>{};
          for (final p in items) {
            byLevel[p.worshipLevel] = (byLevel[p.worshipLevel] ?? 0) + 1;
          }
          debugLines.add(
            'Por nível: polo=${byLevel[RehearsalLevel.polo] ?? 0} area=${byLevel[RehearsalLevel.area] ?? 0} region=${byLevel[RehearsalLevel.region] ?? 0} maanaim=${byLevel[RehearsalLevel.maanaim] ?? 0}',
          );
        }
        emit(
          state.copyWith(loading: false, items: items, debugLines: debugLines),
        );
      },
      onError: (e, st) {
        if (kDebugMode) debugPrint('[PeopleList] watchList error: $e');
        emit(state.copyWith(loading: false, items: state.items));
      },
    );
  }

  void setExpandScopeFilter(bool value, UserProfile? profile) {
    emit(state.copyWith(expandScopeFilter: value));
  }

  void setGeoFilters({String? regionId, String? areaId, String? poloId}) {
    emit(state.copyWith(
      regionFilter: regionId,
      areaFilter: areaId,
      poloFilter: poloId,
    ));
  }

  void replaceOne(Person p) {
    final list = [...state.items];
    final idx = list.indexWhere((e) => e.id == p.id);
    if (idx >= 0) {
      list[idx] = p;
      emit(state.copyWith(items: list));
    }
  }

  void search(String term) => emit(state.copyWith(search: term));

  void addOne(Person p) {
    if (state.items.any((e) => e.id == p.id)) return;
    final next = [...state.items, p]
      ..sort((a, b) => a.fullName.compareTo(b.fullName));
    emit(state.copyWith(items: next));
  }

  void removeOne(String id) {
    final next = state.items.where((e) => e.id != id).toList();
    emit(state.copyWith(items: next));
  }

  void addMany(List<Person> list) {
    final existingIds = state.items.map((e) => e.id).toSet();
    final toAdd = list.where((p) => !existingIds.contains(p.id)).toList();
    if (toAdd.isEmpty) return;
    final next = [...state.items, ...toAdd]
      ..sort((a, b) => a.fullName.compareTo(b.fullName));
    emit(state.copyWith(items: next));
  }

  List<Person> get filtered {
    List<Person> r = List<Person>.from(state.items);
    final s = (state.search ?? '').trim().toLowerCase();
    final profile = state.profile;

    if (s.isNotEmpty) {
      r =
          r
              .where(
                (e) =>
                    e.fullName.toLowerCase().contains(s) ||
                    e.regionId.toLowerCase().contains(s) ||
                    (e.areaId ?? '').toLowerCase().contains(s) ||
                    (e.poloId ?? '').toLowerCase().contains(s) ||
                    (e.email ?? '').toLowerCase().contains(s) ||
                    (e.phone ?? '').toLowerCase().contains(s),
              )
              .toList();
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

    if (state.roleFilter.isNotEmpty) {
      r =
          r
              .where(
                (e) => e.roles.any((role) => state.roleFilter.contains(role)),
              )
              .toList();
    }

    // Padrão (expandScopeFilter false): quem cada secretário vê ao abrir a tela
    // Maanaim: só Maanaim. Região: Região + Maanaim. Área: Área + Região + Maanaim. Polo: Polo + Área + Região + Maanaim (todos). Admin: todos.
    if (profile != null && !state.expandScopeFilter) {
      if (profile.role == UserRole.maanaim) {
        r = r.where((e) => e.worshipLevel == RehearsalLevel.maanaim).toList();
      } else if (profile.role == UserRole.region) {
        r = r.where((e) =>
            e.worshipLevel == RehearsalLevel.region ||
            e.worshipLevel == RehearsalLevel.maanaim).toList();
      } else if (profile.role == UserRole.area) {
        r = r.where((e) =>
            e.worshipLevel == RehearsalLevel.area ||
            e.worshipLevel == RehearsalLevel.region ||
            e.worshipLevel == RehearsalLevel.maanaim).toList();
      }
      // Polo: não filtra por nível — vê todos do polo (Polo, Área, Região, Maanaim). Admin/readonly: sem filtro.
    }

    r.sort((a, b) => a.fullName.compareTo(b.fullName));
    return r;
  }
}

class _Omit {
  const _Omit();
}
