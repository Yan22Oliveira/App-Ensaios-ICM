import 'package:class_attendance/src/core/theme/app_theme.dart';
import 'package:class_attendance/src/domain/entities.dart';
import 'package:class_attendance/src/presentation/reports/attendance_level.dart';
import 'package:class_attendance/src/presentation/reports/report_metrics.dart';
import 'package:class_attendance/src/presentation/reports/reports_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Rehearsal _event({
  required String id,
  EventType type = EventType.rehearsal,
  String regionId = 'div',
  String? areaId,
  String? poloId,
  RehearsalLevel level = RehearsalLevel.polo,
}) {
  return Rehearsal(
    id: id,
    eventType: type,
    dateTime: DateTime(2026, 9, 5),
    level: level,
    regionId: regionId,
    areaId: areaId,
    poloId: poloId,
  );
}

void main() {
  group('attendanceLevelFromRate', () {
    test('thresholds', () {
      expect(attendanceLevelFromRate(0.80), AttendanceLevel.high);
      expect(attendanceLevelFromRate(1.0), AttendanceLevel.high);
      expect(attendanceLevelFromRate(0.79), AttendanceLevel.medium);
      expect(attendanceLevelFromRate(0.60), AttendanceLevel.medium);
      expect(attendanceLevelFromRate(0.59), AttendanceLevel.low);
    });

    test('percentual da lista usa verde, âmbar e vermelho', () {
      expect(attendanceRateColor(1), AppTheme.success);
      expect(attendanceRateColor(0.72), const Color(0xFFD4A017));
      expect(attendanceRateColor(0.4), AppTheme.error);
    });
  });

  group('ReportPeriodTotals', () {
    test('percentual usa participações, não participantes únicos', () {
      final events = [
        RehearsalSummary(rehearsal: _event(id: '1'), present: 8, unjustified: 1, justified: 0),
        RehearsalSummary(rehearsal: _event(id: '2'), present: 2, unjustified: 0, justified: 1),
      ];
      final totals = ReportPeriodTotals.fromSummaries(
        events: events,
        uniqueParticipantCount: 2,
      );
      expect(totals.eventCount, 2);
      expect(totals.uniqueParticipantCount, 2);
      expect(totals.presentCount, 10);
      expect(totals.unjustifiedCount, 1);
      expect(totals.justifiedCount, 1);
      expect(totals.totalParticipations, 12);
      expect(totals.attendanceRate, closeTo(10 / 12, 0.0001));
    });

    test('Isaac em 3 e Amanda em 2 = 2 únicos e 5 participações', () {
      final events = [
        RehearsalSummary(rehearsal: _event(id: '1'), present: 2, unjustified: 0, justified: 0),
        RehearsalSummary(rehearsal: _event(id: '2'), present: 2, unjustified: 0, justified: 0),
        RehearsalSummary(rehearsal: _event(id: '3'), present: 1, unjustified: 0, justified: 0),
      ];
      final totals = ReportPeriodTotals.fromSummaries(
        events: events,
        uniqueParticipantCount: 2,
      );
      expect(totals.uniqueParticipantCount, 2);
      expect(totals.totalParticipations, 5);
    });

    test('sem registros o percentual é 0', () {
      final totals = ReportPeriodTotals.fromSummaries(events: const [], uniqueParticipantCount: 0);
      expect(totals.attendanceRate, 0);
      expect(totals.totalParticipations, 0);
    });
  });

  group('rehearsalMatchesFilters', () {
    test('tipo Seminário e região Divinópolis', () {
      final filters = ReportFilters(
        range: DateTimeRange(start: DateTime(2026, 9, 1), end: DateTime(2026, 9, 30)),
        eventType: EventType.seminar,
        regionId: 'divinopolis',
      );
      expect(
        rehearsalMatchesFilters(
          _event(id: 'ok', type: EventType.seminar, regionId: 'divinopolis'),
          filters,
        ),
        isTrue,
      );
      expect(
        rehearsalMatchesFilters(
          _event(id: 'tipo', type: EventType.rehearsal, regionId: 'divinopolis'),
          filters,
        ),
        isFalse,
      );
      expect(
        rehearsalMatchesFilters(
          _event(id: 'reg', type: EventType.seminar, regionId: 'outra'),
          filters,
        ),
        isFalse,
      );
    });
  });

  group('PersonSummary', () {
    test('eventCount considera só eventos com P/F/J da pessoa', () {
      const person = Person(id: 'i', fullName: 'Isaac', regionId: 'div');
      const summary = PersonSummary(person: person, present: 8, unjustified: 1, justified: 0);
      expect(summary.eventCount, 9);
      expect(summary.attendanceRate, closeTo(8 / 9, 0.0001));
    });

    test('fromMarks ignora eventos em que a pessoa não estava convocada e unmarked', () {
      const person = Person(id: 'i', fullName: 'Isaac', regionId: 'div');
      final marks = [
        PersonEventMark(rehearsal: _event(id: '1'), status: AttendanceStatus.present),
        PersonEventMark(rehearsal: _event(id: '2'), status: AttendanceStatus.present),
        PersonEventMark(rehearsal: _event(id: '3'), status: AttendanceStatus.present),
        PersonEventMark(rehearsal: _event(id: '4'), status: AttendanceStatus.present),
        PersonEventMark(rehearsal: _event(id: '5'), status: AttendanceStatus.present),
        PersonEventMark(rehearsal: _event(id: '6'), status: AttendanceStatus.present),
        PersonEventMark(rehearsal: _event(id: '7'), status: AttendanceStatus.present),
        PersonEventMark(rehearsal: _event(id: '8'), status: AttendanceStatus.present),
        PersonEventMark(rehearsal: _event(id: '9'), status: AttendanceStatus.unjustifiedAbsence),
        PersonEventMark(rehearsal: _event(id: '10'), status: AttendanceStatus.unmarked),
      ];
      final summary = PersonSummary.fromMarks(person: person, marks: marks);
      expect(summary.eventCount, 9);
      expect(summary.present, 8);
      expect(summary.unjustified, 1);
      expect(summary.justified, 0);
      expect(summary.attendanceRate, closeTo(8 / 9, 0.0001));
      expect(formatAttendancePercent(summary.attendanceRate), '88,9%');
    });

    test('justificada entra no denominador', () {
      const person = Person(id: 'i', fullName: 'Isaac', regionId: 'div');
      final summary = PersonSummary.fromMarks(
        person: person,
        marks: [
          for (var i = 0; i < 8; i++)
            PersonEventMark(rehearsal: _event(id: '$i'), status: AttendanceStatus.present),
          PersonEventMark(rehearsal: _event(id: 'f'), status: AttendanceStatus.unjustifiedAbsence),
          PersonEventMark(rehearsal: _event(id: 'j'), status: AttendanceStatus.justifiedAbsence),
        ],
      );
      expect(summary.eventCount, 10);
      expect(summary.attendanceRate, closeTo(8 / 10, 0.0001));
    });

    test('formata nome em caixa alta e iniciais pelo primeiro e último', () {
      expect(displayPersonName('PRISCILA BRANDÃO MIZAEL SILVA'), 'Priscila Brandão Mizael Silva');
      expect(personInitials('PRISCILA BRANDÃO MIZAEL SILVA'), 'PS');
      expect(personInitials('Priscila da Silva'), 'PS');
      expect(displayPersonName('Isaac Rodrigues'), 'Isaac Rodrigues');
    });

    test('sem eventos previstos o percentual é 0 e não é NaN', () {
      const person = Person(id: 'i', fullName: 'Isaac', regionId: 'div');
      final summary = PersonSummary.fromMarks(person: person, marks: const []);
      expect(summary.eventCount, 0);
      expect(summary.attendanceRate, 0);
      expect(formatAttendancePercent(summary.attendanceRate), '0,0%');
    });
  });

  group('frequencyInsightFromRate', () {
    test('thresholds e empty', () {
      expect(frequencyInsightFromRate(0.9, hasEvents: true), FrequencyInsight.excellent);
      expect(frequencyInsightFromRate(0.75, hasEvents: true), FrequencyInsight.good);
      expect(frequencyInsightFromRate(0.60, hasEvents: true), FrequencyInsight.regular);
      expect(frequencyInsightFromRate(0.59, hasEvents: true), FrequencyInsight.low);
      expect(frequencyInsightFromRate(1, hasEvents: false), isNull);
    });
  });

  group('attendanceMarkForPerson', () {
    test('null quando a pessoa não estava na chamada', () {
      expect(
        attendanceMarkForPerson(
          rehearsal: _event(id: '1'),
          records: const [],
          personId: 'isaac',
        ),
        isNull,
      );
    });
  });
}
