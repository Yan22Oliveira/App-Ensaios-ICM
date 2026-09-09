/// Status persistido do relatório do evento.
/// "Não iniciado" é ausência de documento, não um valor deste enum.
enum EventReportStatus {
  draft,
  finalized,
}

extension EventReportStatusLabel on EventReportStatus {
  String get label => switch (this) {
        EventReportStatus.draft => 'Rascunho',
        EventReportStatus.finalized => 'Finalizado',
      };
}

EventReportStatus eventReportStatusFromString(String? raw) {
  final key = (raw ?? '').trim().toLowerCase();
  if (key == EventReportStatus.finalized.name) return EventReportStatus.finalized;
  return EventReportStatus.draft;
}

String eventReportStatusToString(EventReportStatus status) => status.name;
