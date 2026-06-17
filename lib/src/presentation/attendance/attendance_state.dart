import 'package:equatable/equatable.dart';

import '../../domain/entities.dart';

class AttendanceState extends Equatable {
  final bool loading;
  final Rehearsal? rehearsal;
  final List<Person> participants;
  final Map<String, AttendanceRecord> records;
  final String? search;
  final String? errorMessage;

  const AttendanceState({
    required this.loading,
    required this.rehearsal,
    required this.participants,
    required this.records,
    required this.search,
    this.errorMessage,
  });

  bool get isClosed => rehearsal?.closed == true;

  factory AttendanceState.initial() => const AttendanceState(
    loading: false,
    rehearsal: null,
    participants: [],
    records: {},
    search: null,
    errorMessage: null,
  );

  AttendanceState copyWith({
    bool? loading,
    Rehearsal? rehearsal,
    List<Person>? participants,
    Map<String, AttendanceRecord>? records,
    String? search,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AttendanceState(
      loading: loading ?? this.loading,
      rehearsal: rehearsal ?? this.rehearsal,
      participants: participants ?? this.participants,
      records: records ?? this.records,
      search: search ?? this.search,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [loading, rehearsal, participants, records, search, errorMessage];
}
