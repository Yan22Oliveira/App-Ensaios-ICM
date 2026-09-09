import 'package:class_attendance/src/domain/models/event_participant_mode.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('eventParticipantModeFromString', () {
    test('null ou vazio vira all (legado)', () {
      expect(eventParticipantModeFromString(null), EventParticipantMode.all);
      expect(eventParticipantModeFromString(''), EventParticipantMode.all);
    });

    test('selected é reconhecido', () {
      expect(eventParticipantModeFromString('selected'), EventParticipantMode.selected);
      expect(eventParticipantModeFromString('SELECTED'), EventParticipantMode.selected);
    });

    test('valor desconhecido vira all', () {
      expect(eventParticipantModeFromString('convoked'), EventParticipantMode.all);
    });
  });

  group('EventParticipantModeLabel', () {
    test('rótulos em português', () {
      expect(EventParticipantMode.all.label, 'Todos os membros');
      expect(EventParticipantMode.selected.label, 'Selecionar participantes');
    });
  });
}
