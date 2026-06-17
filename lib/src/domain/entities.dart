/// Níveis de ensaio e de pertencimento da pessoa (worshipLevel).
/// Hierarquia: Maanaim > Região > Área > Polo.
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

class Rehearsal {
  final String id;
  final DateTime dateTime;
  final RehearsalLevel level;
  final String regionId;
  final String? areaId;
  final String? poloId;
  final String? place;
  final String? description;
  final List<String> expectedParticipants;
  final bool closed;
  final DateTime? closedAt;

  const Rehearsal({
    required this.id,
    required this.dateTime,
    required this.level,
    required this.regionId,
    this.areaId,
    this.poloId,
    this.place,
    this.description,
    this.expectedParticipants = const [],
    this.closed = false,
    this.closedAt,
  });

  Rehearsal copyWith({
    DateTime? dateTime,
    RehearsalLevel? level,
    String? regionId,
    String? areaId,
    String? poloId,
    String? place,
    String? description,
    bool? closed,
    DateTime? closedAt,
    final List<String>? expectedParticipants,
  }) {
    return Rehearsal(
      id: id,
      dateTime: dateTime ?? this.dateTime,
      level: level ?? this.level,
      regionId: regionId ?? this.regionId,
      areaId: areaId ?? this.areaId,
      poloId: poloId ?? this.poloId,
      place: place ?? this.place,
      description: description ?? this.description,
      closed: closed ?? this.closed,
      closedAt: closedAt ?? this.closedAt,
      expectedParticipants: expectedParticipants ?? this.expectedParticipants,
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
