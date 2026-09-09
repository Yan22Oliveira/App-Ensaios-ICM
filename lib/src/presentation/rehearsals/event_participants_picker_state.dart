import 'package:equatable/equatable.dart';

import '../../src.dart';

class EventParticipantsPickerState extends Equatable {
  final bool loading;
  final String? errorMessage;
  final List<Person> members;
  final Set<String> selectedIds;
  final Set<String> initialSelectedIds;
  final String search;

  const EventParticipantsPickerState({
    required this.loading,
    required this.members,
    required this.selectedIds,
    required this.initialSelectedIds,
    required this.search,
    this.errorMessage,
  });

  factory EventParticipantsPickerState.initial() => const EventParticipantsPickerState(
        loading: true,
        members: [],
        selectedIds: {},
        initialSelectedIds: {},
        search: '',
      );

  bool get hasChanges {
    if (selectedIds.length != initialSelectedIds.length) return true;
    return !selectedIds.containsAll(initialSelectedIds);
  }

  EventParticipantsPickerState copyWith({
    bool? loading,
    String? errorMessage,
    bool clearError = false,
    List<Person>? members,
    Set<String>? selectedIds,
    Set<String>? initialSelectedIds,
    String? search,
  }) {
    return EventParticipantsPickerState(
      loading: loading ?? this.loading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      members: members ?? this.members,
      selectedIds: selectedIds ?? this.selectedIds,
      initialSelectedIds: initialSelectedIds ?? this.initialSelectedIds,
      search: search ?? this.search,
    );
  }

  @override
  List<Object?> get props => [
        loading,
        errorMessage,
        members,
        selectedIds,
        initialSelectedIds,
        search,
      ];
}
