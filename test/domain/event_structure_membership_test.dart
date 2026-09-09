import 'package:class_attendance/src/domain/entities.dart';
import 'package:class_attendance/src/domain/event_structure_membership.dart';
import 'package:flutter_test/flutter_test.dart';

Person _p({
  required String id,
  required RehearsalLevel level,
  String regionId = 'div',
  String? areaId,
  String? poloId,
}) {
  return Person(
    id: id,
    fullName: id,
    regionId: regionId,
    areaId: areaId,
    poloId: poloId,
    worshipLevel: level,
  );
}

void main() {
  group('personBelongsToEventStructure', () {
    test('polo inclui qualquer nível do mesmo polo', () {
      expect(
        personBelongsToEventStructure(
          _p(id: '1', level: RehearsalLevel.polo, areaId: 'a', poloId: 'centro'),
          level: RehearsalLevel.polo,
          regionId: 'div',
          areaId: 'a',
          poloId: 'centro',
        ),
        isTrue,
      );
      expect(
        personBelongsToEventStructure(
          _p(id: '2', level: RehearsalLevel.maanaim, areaId: 'a', poloId: 'centro'),
          level: RehearsalLevel.polo,
          regionId: 'div',
          areaId: 'a',
          poloId: 'centro',
        ),
        isTrue,
      );
      expect(
        personBelongsToEventStructure(
          _p(id: '3', level: RehearsalLevel.polo, areaId: 'a', poloId: 'outro'),
          level: RehearsalLevel.polo,
          regionId: 'div',
          areaId: 'a',
          poloId: 'centro',
        ),
        isFalse,
      );
    });

    test('região inclui região e maanaim da mesma região', () {
      expect(
        personBelongsToEventStructure(
          _p(id: '1', level: RehearsalLevel.region),
          level: RehearsalLevel.region,
          regionId: 'div',
        ),
        isTrue,
      );
      expect(
        personBelongsToEventStructure(
          _p(id: '2', level: RehearsalLevel.polo, areaId: 'a', poloId: 'c'),
          level: RehearsalLevel.region,
          regionId: 'div',
        ),
        isFalse,
      );
    });
  });

  group('foldSearch', () {
    test('ignora acentos e caixa', () {
      expect(foldSearch('Amânda'), contains(foldSearch('amanda')));
      expect(foldSearch('São Paulo').contains(foldSearch('sao')), isTrue);
    });
  });
}
