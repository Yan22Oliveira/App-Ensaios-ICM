import 'dart:async';

import 'package:bloc/bloc.dart';

import '../../src.dart';

class EventParticipantsPickerController extends Cubit<EventParticipantsPickerState> {
  final EventParticipantsResolver resolver;
  final RehearsalLevel level;
  final String regionId;
  final String? areaId;
  final String? poloId;
  final Set<String> initialSelectedIds;

  Timer? _searchDebounce;

  EventParticipantsPickerController({
    required this.resolver,
    required this.level,
    required this.regionId,
    this.areaId,
    this.poloId,
    Set<String>? initialSelectedIds,
  })  : initialSelectedIds = Set<String>.from(initialSelectedIds ?? const {}),
        super(EventParticipantsPickerState.initial());

  Future<void> load() async {
    emit(state.copyWith(loading: true, clearError: true));
    try {
      final members = await resolver.availableInStructure(
        level: level,
        regionId: regionId,
        areaId: areaId,
        poloId: poloId,
      );
      final valid = initialSelectedIds.intersection(members.map((p) => p.id).toSet());
      emit(state.copyWith(
        loading: false,
        members: members,
        selectedIds: valid,
        initialSelectedIds: valid,
        clearError: true,
      ));
    } catch (e) {
      emit(state.copyWith(
        loading: false,
        errorMessage: 'Não foi possível carregar os participantes.',
      ));
    }
  }

  void setSearch(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      emit(state.copyWith(search: value));
    });
  }

  void toggle(String personId) {
    final next = Set<String>.from(state.selectedIds);
    if (!next.add(personId)) next.remove(personId);
    emit(state.copyWith(selectedIds: next));
  }

  List<Person> get visibleMembers {
    final q = foldSearch(state.search.trim());
    if (q.isEmpty) return state.members;
    return state.members.where((p) {
      final hay = foldSearch([
        p.fullName,
        p.email ?? '',
        ...p.roles,
      ].join(' '));
      return hay.contains(q);
    }).toList();
  }

  @override
  Future<void> close() {
    _searchDebounce?.cancel();
    return super.close();
  }
}
