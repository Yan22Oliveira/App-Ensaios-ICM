import 'event_report_status.dart';

/// Relatório textual vinculado a um evento (`eventId` = id do documento em `rehearsals`).
/// Não duplica tipo, data, local nem geografia — esses dados vêm do [Rehearsal].
class EventReport {
  final String id;
  final String eventId;
  final String title;
  final String? responsible;
  final String overview;
  final String conclusion;
  final String? notes;
  final EventReportStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  /// Nome de quem salvou por último, se o perfil estiver disponível.
  final String? updatedByName;

  const EventReport({
    required this.id,
    required this.eventId,
    required this.title,
    this.responsible,
    required this.overview,
    required this.conclusion,
    this.notes,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.updatedByName,
  });

  EventReport copyWith({
    String? title,
    String? responsible,
    String? overview,
    String? conclusion,
    String? notes,
    EventReportStatus? status,
    DateTime? updatedAt,
    String? updatedByName,
  }) {
    return EventReport(
      id: id,
      eventId: eventId,
      title: title ?? this.title,
      responsible: responsible ?? this.responsible,
      overview: overview ?? this.overview,
      conclusion: conclusion ?? this.conclusion,
      notes: notes ?? this.notes,
      status: status ?? this.status,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      updatedByName: updatedByName ?? this.updatedByName,
    );
  }
}
