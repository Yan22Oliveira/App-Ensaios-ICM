import '../../src.dart';

abstract class IEventReportRepository {
  /// Relatório do evento, ou `null` se ainda não foi iniciado.
  Future<EventReport?> getByEventId(String eventId);

  /// Cria ou atualiza. O documento usa [EventReport.eventId] como ID (1 por evento).
  Future<EventReport> upsert(EventReport report);
}
