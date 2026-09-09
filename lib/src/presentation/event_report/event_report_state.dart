import 'package:equatable/equatable.dart';

import '../../src.dart';

class EventReportState extends Equatable {
  final bool loading;
  final bool saving;
  final bool editing;
  final Rehearsal? event;
  final EventReport? report;
  final String? errorMessage;
  final String? successMessage;

  const EventReportState({
    required this.loading,
    required this.saving,
    required this.editing,
    required this.event,
    required this.report,
    this.errorMessage,
    this.successMessage,
  });

  factory EventReportState.initial() => const EventReportState(
        loading: false,
        saving: false,
        editing: true,
        event: null,
        report: null,
      );

  bool get isFinalized => report?.status == EventReportStatus.finalized;

  EventReportState copyWith({
    bool? loading,
    bool? saving,
    bool? editing,
    Rehearsal? event,
    EventReport? report,
    String? errorMessage,
    String? successMessage,
    bool clearMessages = false,
  }) {
    return EventReportState(
      loading: loading ?? this.loading,
      saving: saving ?? this.saving,
      editing: editing ?? this.editing,
      event: event ?? this.event,
      report: report ?? this.report,
      errorMessage: clearMessages ? errorMessage : (errorMessage ?? this.errorMessage),
      successMessage: clearMessages ? successMessage : (successMessage ?? this.successMessage),
    );
  }

  @override
  List<Object?> get props => [
        loading,
        saving,
        editing,
        event,
        report,
        errorMessage,
        successMessage,
      ];
}
