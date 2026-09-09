import 'package:bloc_test/bloc_test.dart';
import 'package:class_attendance/src/data/event_participants_resolver.dart';
import 'package:class_attendance/src/domain/entities.dart';
import 'package:class_attendance/src/domain/repositories/i_person_repository.dart';
import 'package:class_attendance/src/presentation/rehearsals/event_participants_picker_controller.dart';
import 'package:class_attendance/src/presentation/rehearsals/event_participants_picker_state.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakePeople implements IPersonRepository {
  final List<Person> people;
  _FakePeople(this.people);

  @override
  Future<List<Person>> list({
    String? regionId,
    List<String>? regionIds,
    String? areaId,
    String? poloId,
    List<String>? roles,
    String? search,
    RehearsalLevel? worshipLevel,
  }) async {
    return people.where((p) {
      if (poloId != null && p.poloId != poloId) return false;
      if (areaId != null && p.areaId != areaId) return false;
      if (regionId != null && p.regionId != regionId) return false;
      return true;
    }).toList();
  }

  @override
  Future<List<Person>> listByIds(List<String> ids) async =>
      people.where((p) => ids.contains(p.id)).toList();

  @override
  Future<Person> create(Person p) => throw UnimplementedError();
  @override
  Future<Person> update(Person p) => throw UnimplementedError();
  @override
  Stream<List<Person>> watchList({
    String? regionId,
    List<String>? regionIds,
    String? areaId,
    String? poloId,
    List<String>? roles,
  }) =>
      throw UnimplementedError();
  @override
  Future<Person?> getById(String id) async => people.cast<Person?>().firstWhere((p) => p?.id == id, orElse: () => null);
  @override
  Future<List<Person>> bulkCreate(List<Person> people) => throw UnimplementedError();
}

Person _member(String id, {String polo = 'centro', List<String> roles = const []}) {
  return Person(
    id: id,
    fullName: id,
    regionId: 'div',
    areaId: 'a1',
    poloId: polo,
    roles: roles,
    worshipLevel: RehearsalLevel.polo,
  );
}

void main() {
  final members = [
    _member('ana', roles: ['Violino']),
    _member('bruno', roles: ['Teclado']),
    _member('carla', polo: 'centro', roles: ['Flauta']),
  ];

  EventParticipantsPickerController build({Set<String>? selected}) {
    return EventParticipantsPickerController(
      resolver: EventParticipantsResolver(_FakePeople(members)),
      level: RehearsalLevel.polo,
      regionId: 'div',
      areaId: 'a1',
      poloId: 'centro',
      initialSelectedIds: selected,
    );
  }

  blocTest<EventParticipantsPickerController, EventParticipantsPickerState>(
    'load traz membros da estrutura e preserva seleção válida',
    build: () => build(selected: {'ana', 'inexistente'}),
    act: (c) => c.load(),
    expect: () => [
      isA<EventParticipantsPickerState>().having((s) => s.loading, 'loading', true),
      isA<EventParticipantsPickerState>()
          .having((s) => s.loading, 'loading', false)
          .having((s) => s.members.length, 'members', 3)
          .having((s) => s.selectedIds, 'selected', {'ana'}),
    ],
  );

  blocTest<EventParticipantsPickerController, EventParticipantsPickerState>(
    'toggle marca e desmarca participante',
    build: () => build(),
    seed: () => EventParticipantsPickerState.initial().copyWith(
      loading: false,
      members: members,
      selectedIds: {'ana'},
      initialSelectedIds: {'ana'},
    ),
    act: (c) {
      c.toggle('bruno');
      c.toggle('ana');
    },
    expect: () => [
      isA<EventParticipantsPickerState>().having((s) => s.selectedIds, 'after add', {'ana', 'bruno'}),
      isA<EventParticipantsPickerState>().having((s) => s.selectedIds, 'after remove', {'bruno'}),
    ],
  );

  test('busca não remove seleção oculta', () async {
    final c = build();
    c.emit(EventParticipantsPickerState.initial().copyWith(
      loading: false,
      members: members,
      selectedIds: {'ana'},
      initialSelectedIds: const {},
      search: 'bruno',
    ));
    expect(c.visibleMembers.map((p) => p.id), ['bruno']);
    expect(c.state.selectedIds, {'ana'});
    await c.close();
  });
}
