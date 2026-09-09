import 'package:class_attendance/src/domain/models/event_report.dart';
import 'package:class_attendance/src/domain/models/event_report_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('eventReportStatusFromString', () {
    test('finalized', () {
      expect(eventReportStatusFromString('finalized'), EventReportStatus.finalized);
      expect(eventReportStatusFromString('FINALIZED'), EventReportStatus.finalized);
    });

    test('legado/desconhecido vira draft', () {
      expect(eventReportStatusFromString(null), EventReportStatus.draft);
      expect(eventReportStatusFromString(''), EventReportStatus.draft);
      expect(eventReportStatusFromString('rascunho'), EventReportStatus.draft);
    });
  });

  group('EventReportStatusLabel', () {
    test('rótulos', () {
      expect(EventReportStatus.draft.label, 'Rascunho');
      expect(EventReportStatus.finalized.label, 'Finalizado');
    });
  });

  group('EventReport', () {
    test('copyWith preserva eventId e createdAt', () {
      final created = DateTime(2026, 9, 1);
      final report = EventReport(
        id: 'e1',
        eventId: 'e1',
        title: 'Relatório',
        overview: 'Panorama',
        conclusion: 'Fim',
        status: EventReportStatus.draft,
        createdAt: created,
        updatedAt: created,
      );
      final next = report.copyWith(
        status: EventReportStatus.finalized,
        updatedAt: DateTime(2026, 9, 2),
      );
      expect(next.eventId, 'e1');
      expect(next.createdAt, created);
      expect(next.status, EventReportStatus.finalized);
      expect(next.title, 'Relatório');
    });
  });
}
