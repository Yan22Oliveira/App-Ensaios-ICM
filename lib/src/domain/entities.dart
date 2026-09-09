import 'models/event_participant_mode.dart';
import 'models/event_type.dart';
export 'models/event_participant_mode.dart';
export 'models/event_type.dart';

/// Escopo geográfico/organizacional do evento e nível de participação da pessoa (worshipLevel).
/// Hierarquia: Maanaim > Região > Área > Polo.
/// Não confundir com [EventType] (ensaio, culto, vigília, etc.).
/// Ver [business_rules.md] para regras de pertencimento (quem tem região/área/polo obrigatório).
enum RehearsalLevel { polo, area, region, maanaim }
enum AttendanceStatus { unmarked, present, justifiedAbsence, unjustifiedAbsence }

/// Geografia / organização

/// Maanaim: documento da coleção `maanains` (id = doc id, nome = campo Nome).
class Maanaim {
  final String id;   // ex.: "divinopolis"
  final String name; // ex.: "Maanaim Divinópolis" (campo Nome no Firestore)
  const Maanaim({required this.id, required this.name});
}

class Region {
  final String id;     // ex.: "divinopolis"
  final String name;   // "Divinópolis"
  const Region({required this.id, required this.name});
}

class Area {
  final String id;        // ex.: "co1_mg"
  final String name;      // "Centro-Oeste 1/MG"
  final String regionId;  // "divinopolis"
  const Area({required this.id, required this.name, required this.regionId});
}

class Polo {
  final String id;        // ex.: "polo_centro"
  final String name;      // "Polo Centro"
  final String areaId;    // "co1_mg"
  const Polo({required this.id, required this.name, required this.areaId});
}

/// Pessoa/membro. O [worshipLevel] define o nível de participação.
/// Regras: Maanaim e Região exigem regionId+areaId+poloId; Área exige areaId+poloId; Polo exige poloId.
class Person {
  final String id;
  final String fullName;
  final String regionId;
  final String? areaId;
  final String? poloId;
  final String? phone;
  final String? email;
  final List<String> roles;
  final bool active;
  final RehearsalLevel worshipLevel;

  const Person({
    required this.id,
    required this.fullName,
    required this.regionId,
    this.areaId,
    this.poloId,
    this.phone,
    this.email,
    this.roles = const [],
    this.active = true,
    this.worshipLevel = RehearsalLevel.polo,
  });

  Person copyWith({
    String? id,
    String? fullName,
    String? regionId,
    String? areaId,
    String? poloId,
    String? phone,
    String? email,
    List<String>? roles,
    bool? active,
    RehearsalLevel? worshipLevel,
  }) {
    return Person(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      regionId: regionId ?? this.regionId,
      areaId: areaId ?? this.areaId,
      poloId: poloId ?? this.poloId,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      roles: roles ?? this.roles,
      active: active ?? this.active,
      worshipLevel: worshipLevel ?? this.worshipLevel,
    );
  }
}

/// Evento com chamada (ensaio, culto, vigília, etc.).
///
/// Mantém o nome [Rehearsal] por compatibilidade com Firestore (`rehearsals`)
/// e com `attendance.rehearsalId`. Semanticamente é um Evento.
class Rehearsal {
  final String id;
  final EventType eventType;
  final String? title;
  final DateTime dateTime;
  final RehearsalLevel level;
  final String regionId;
  final String? areaId;
  final String? poloId;
  final String? place;
  final String? description;
  /// Modo de participantes. Ausente no Firestore → [EventParticipantMode.all].
  final EventParticipantMode participantMode;
  /// IDs dos membros escolhidos quando [participantMode] é [EventParticipantMode.selected].
  final List<String> expectedParticipants;
  /// Lista congelada após o primeiro P/F/J ou ao finalizar a chamada.
  /// `null` = ainda dinâmica (modo all pode incluir novos membros).
  final List<String>? participantsSnapshot;
  final bool closed;
  final DateTime? closedAt;

  const Rehearsal({
    required this.id,
    this.eventType = EventType.rehearsal,
    this.title,
    required this.dateTime,
    required this.level,
    required this.regionId,
    this.areaId,
    this.poloId,
    this.place,
    this.description,
    this.participantMode = EventParticipantMode.all,
    this.expectedParticipants = const [],
    this.participantsSnapshot,
    this.closed = false,
    this.closedAt,
  });

  /// Título para UI: campo informado ou, se vazio, o rótulo do tipo.
  String get displayTitle {
    final t = title?.trim();
    if (t != null && t.isNotEmpty) return t;
    return eventType.label;
  }

  Rehearsal copyWith({
    EventType? eventType,
    String? title,
    DateTime? dateTime,
    RehearsalLevel? level,
    String? regionId,
    String? areaId,
    String? poloId,
    String? place,
    String? description,
    EventParticipantMode? participantMode,
    List<String>? expectedParticipants,
    List<String>? participantsSnapshot,
    bool clearSnapshot = false,
    bool? closed,
    DateTime? closedAt,
  }) {
    return Rehearsal(
      id: id,
      eventType: eventType ?? this.eventType,
      title: title ?? this.title,
      dateTime: dateTime ?? this.dateTime,
      level: level ?? this.level,
      regionId: regionId ?? this.regionId,
      areaId: areaId ?? this.areaId,
      poloId: poloId ?? this.poloId,
      place: place ?? this.place,
      description: description ?? this.description,
      participantMode: participantMode ?? this.participantMode,
      expectedParticipants: expectedParticipants ?? this.expectedParticipants,
      participantsSnapshot: clearSnapshot
          ? null
          : (participantsSnapshot ?? this.participantsSnapshot),
      closed: closed ?? this.closed,
      closedAt: closedAt ?? this.closedAt,
    );
  }

  bool get isClosed => dateTime.isBefore(DateTime.now());
}

class AttendanceRecord {
  final String id;
  final String rehearsalId;
  final String personId;
  final AttendanceStatus status;
  final String? justification;
  final String markedByUserId;
  final DateTime markedAt;
  final bool pendingSync;

  const AttendanceRecord({
    required this.id,
    required this.rehearsalId,
    required this.personId,
    required this.status,
    this.justification,
    required this.markedByUserId,
    required this.markedAt,
    this.pendingSync = true,
  });

  AttendanceRecord copyWith({
    String? id,
    String? rehearsalId,
    String? personId,
    AttendanceStatus? status,
    String? justification,
    String? markedByUserId,
    DateTime? markedAt,
    bool? pendingSync,
  }) {
    return AttendanceRecord(
      id: id ?? this.id,
      rehearsalId: rehearsalId ?? this.rehearsalId,
      personId: personId ?? this.personId,
      status: status ?? this.status,
      justification: justification ?? this.justification,
      markedByUserId: markedByUserId ?? this.markedByUserId,
      markedAt: markedAt ?? this.markedAt,
      pendingSync: pendingSync ?? this.pendingSync,
    );
  }

}
