import 'package:class_attendance/src/domain/entities.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Person', () {
    test('copyWith preserva valores não alterados', () {
      const p = Person(
        id: '1',
        fullName: 'João Silva',
        regionId: 'r1',
        roles: ['voz'],
      );

      final p2 = p.copyWith(fullName: 'João Santos');
      expect(p2.id, '1');
      expect(p2.fullName, 'João Santos');
      expect(p2.regionId, 'r1');
      expect(p2.roles, ['voz']);
    });
  });

  group('Rehearsal', () {
    test('isClosed retorna true quando dateTime está no passado', () {
      final r = Rehearsal(
        id: 'r1',
        dateTime: DateTime.now().subtract(const Duration(days: 1)),
        level: RehearsalLevel.polo,
        regionId: 'r1',
      );
      expect(r.isClosed, true);
    });

    test('displayTitle usa o tipo quando não há título', () {
      final r = Rehearsal(
        id: 'r1',
        dateTime: DateTime.now(),
        level: RehearsalLevel.polo,
        regionId: 'r1',
        eventType: EventType.vigil,
      );
      expect(r.displayTitle, 'Vigília');
    });

    test('displayTitle prefere o título informado', () {
      final r = Rehearsal(
        id: 'r1',
        dateTime: DateTime.now(),
        level: RehearsalLevel.polo,
        regionId: 'r1',
        eventType: EventType.vigil,
        title: 'Vigília de Jovens',
      );
      expect(r.displayTitle, 'Vigília de Jovens');
    });
  });

  group('AttendanceRecord', () {
    test('copyWith altera apenas status', () {
      final r = AttendanceRecord(
        id: 'a1',
        rehearsalId: 'r1',
        personId: 'p1',
        status: AttendanceStatus.present,
        markedByUserId: 'u1',
        markedAt: DateTime(2025, 1, 1),
      );
      final r2 = r.copyWith(status: AttendanceStatus.unjustifiedAbsence);
      expect(r2.status, AttendanceStatus.unjustifiedAbsence);
      expect(r2.id, 'a1');
      expect(r2.personId, 'p1');
    });
  });
}
