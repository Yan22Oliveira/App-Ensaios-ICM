import 'package:class_attendance/src/domain/entities.dart';
import 'package:class_attendance/src/presentation/attendance/attendance_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AttendanceState', () {
    test('initial retorna estado vazio', () {
      final state = AttendanceState.initial();
      expect(state.loading, false);
      expect(state.rehearsal, isNull);
      expect(state.participants, isEmpty);
      expect(state.records, isEmpty);
      expect(state.errorMessage, isNull);
    });

    test('copyWith com clearError limpa errorMessage', () {
      final state = AttendanceState.initial().copyWith(
        errorMessage: 'Erro de teste',
      );
      expect(state.errorMessage, 'Erro de teste');

      final cleared = state.copyWith(clearError: true);
      expect(cleared.errorMessage, isNull);
    });

    test('isClosed retorna true quando rehearsal está fechado', () {
      final rehearsal = Rehearsal(
        id: 'r1',
        dateTime: DateTime.now().subtract(const Duration(days: 1)),
        level: RehearsalLevel.polo,
        regionId: 'r1',
        closed: true,
      );
      final state = AttendanceState.initial().copyWith(rehearsal: rehearsal);
      expect(state.isClosed, true);
    });
  });
}
