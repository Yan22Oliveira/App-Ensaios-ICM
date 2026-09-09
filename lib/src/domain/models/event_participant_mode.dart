/// Como o evento define quem aparece na chamada.
enum EventParticipantMode {
  /// Todos os membros da estrutura do evento (resolvido dinamicamente).
  all,

  /// Apenas os membros escolhidos em [Rehearsal.expectedParticipants].
  selected,
}

extension EventParticipantModeLabel on EventParticipantMode {
  String get label => switch (this) {
        EventParticipantMode.all => 'Todos os membros',
        EventParticipantMode.selected => 'Selecionar participantes',
      };
}

/// Legado sem campo → [EventParticipantMode.all] (comportamento atual da chamada).
EventParticipantMode eventParticipantModeFromString(String? raw) {
  final key = (raw ?? '').trim().toLowerCase();
  if (key == EventParticipantMode.selected.name) {
    return EventParticipantMode.selected;
  }
  return EventParticipantMode.all;
}

String eventParticipantModeToString(EventParticipantMode mode) => mode.name;
