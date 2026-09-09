import '../src.dart';

/// Resolve quem deve aparecer na chamada, no contador e na seleção manual.
class EventParticipantsResolver {
  final IPersonRepository personRepo;

  EventParticipantsResolver(this.personRepo);

  /// Membros ativos da estrutura (modo "todos" e lista da tela Gerenciar).
  Future<List<Person>> availableInStructure({
    required RehearsalLevel level,
    required String regionId,
    String? areaId,
    String? poloId,
  }) async {
    if (!_structureReady(level: level, regionId: regionId, areaId: areaId, poloId: poloId)) {
      return const [];
    }

    List<Person> scoped;
    switch (level) {
      case RehearsalLevel.maanaim: {
        final rid = regionId.trim().isEmpty ? null : regionId;
        scoped = await personRepo.list(
          regionId: rid,
          worshipLevel: RehearsalLevel.maanaim,
        );
        break;
      }
      case RehearsalLevel.region:
        scoped = await personRepo.list(regionId: regionId);
        break;
      case RehearsalLevel.area:
        scoped = await personRepo.list(regionId: regionId, areaId: areaId);
        break;
      case RehearsalLevel.polo:
        scoped = await personRepo.list(
          regionId: regionId,
          areaId: areaId,
          poloId: poloId,
        );
        break;
    }

    final people = scoped
        .where(
          (p) => personBelongsToEventStructure(
            p,
            level: level,
            regionId: regionId,
            areaId: areaId,
            poloId: poloId,
          ),
        )
        .toList()
      ..sort((a, b) => a.fullName.compareTo(b.fullName));
    return people;
  }

  /// Participantes efetivos do evento.
  ///
  /// Se [ignoreSnapshot] for false e houver snapshot, usa a lista congelada
  /// (chamada já iniciada ou finalizada).
  Future<List<Person>> resolve(Rehearsal event, {bool ignoreSnapshot = false}) async {
    final snapshot = event.participantsSnapshot;
    if (!ignoreSnapshot && snapshot != null) {
      return personRepo.listByIds(snapshot);
    }
    if (event.participantMode == EventParticipantMode.selected) {
      return personRepo.listByIds(event.expectedParticipants);
    }
    return availableInStructure(
      level: event.level,
      regionId: event.regionId,
      areaId: event.areaId,
      poloId: event.poloId,
    );
  }

  bool _structureReady({
    required RehearsalLevel level,
    required String regionId,
    String? areaId,
    String? poloId,
  }) {
    if (regionId.trim().isEmpty && level != RehearsalLevel.maanaim) return false;
    if (level == RehearsalLevel.area && (areaId == null || areaId.trim().isEmpty)) {
      return false;
    }
    if (level == RehearsalLevel.polo &&
        ((areaId == null || areaId.trim().isEmpty) || (poloId == null || poloId.trim().isEmpty))) {
      return false;
    }
    return true;
  }
}
