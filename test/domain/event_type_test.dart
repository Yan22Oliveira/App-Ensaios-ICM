import 'package:class_attendance/src/domain/models/event_type.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('eventTypeFromString', () {
    test('null ou vazio vira rehearsal (legado)', () {
      expect(eventTypeFromString(null), EventType.rehearsal);
      expect(eventTypeFromString(''), EventType.rehearsal);
      expect(eventTypeFromString('  '), EventType.rehearsal);
    });

    test('valores conhecidos', () {
      expect(eventTypeFromString('rehearsal'), EventType.rehearsal);
      expect(eventTypeFromString('Vigil'), EventType.vigil);
      expect(eventTypeFromString('worship'), EventType.worship);
      expect(eventTypeFromString('mutirao'), EventType.mutirao);
    });

    test('valor desconhecido vira other', () {
      expect(eventTypeFromString('festa'), EventType.other);
      expect(eventTypeFromString('unknown'), EventType.other);
    });
  });

  group('EventTypeLabel', () {
    test('rótulos em português', () {
      expect(EventType.rehearsal.label, 'Ensaio');
      expect(EventType.worship.label, 'Culto');
      expect(EventType.vigil.label, 'Vigília');
      expect(EventType.other.label, 'Outro');
    });
  });
}
