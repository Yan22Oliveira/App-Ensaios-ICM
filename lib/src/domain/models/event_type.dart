/// Tipo de atividade de um evento (ensaio, culto, vigília, etc.).
/// Independente de [RehearsalLevel], que representa o escopo geográfico.
enum EventType {
  rehearsal,
  worship,
  vigil,
  evangelism,
  assistance,
  seminar,
  meeting,
  cantata,
  mutirao,
  other,
}

extension EventTypeLabel on EventType {
  String get label => switch (this) {
        EventType.rehearsal => 'Ensaio',
        EventType.worship => 'Culto',
        EventType.vigil => 'Vigília',
        EventType.evangelism => 'Evangelização',
        EventType.assistance => 'Assistência',
        EventType.seminar => 'Seminário',
        EventType.meeting => 'Reunião',
        EventType.cantata => 'Cantata',
        EventType.mutirao => 'Mutirão',
        EventType.other => 'Outro',
      };

  /// Valor persistido no Firestore (`eventType`).
  String get storageValue => name;
}

/// Converte string persistida para [EventType].
///
/// - `null`/vazio → [EventType.rehearsal] (registros legados sem o campo).
/// - valor desconhecido → [EventType.other] (não quebra a UI).
EventType eventTypeFromString(String? raw) {
  final key = (raw ?? '').trim().toLowerCase();
  if (key.isEmpty) return EventType.rehearsal;
  for (final t in EventType.values) {
    if (t.name == key) return t;
  }
  return EventType.other;
}

String eventTypeToString(EventType type) => type.storageValue;
