import 'package:equatable/equatable.dart';

enum UserRole { admin, maanaim, region, area, polo, readonly }

UserRole roleFromString(String? s) {
  switch ((s ?? '').trim()) {
    case 'admin':
      return UserRole.admin;
    case 'maanaim':
      return UserRole.maanaim;
    case 'region':
      return UserRole.region;
    case 'area':
      return UserRole.area;
    case 'polo':
      return UserRole.polo;
    default:
      return UserRole.readonly;
  }
}

String roleToString(UserRole r) {
  switch (r) {
    case UserRole.admin:
      return 'admin';
    case UserRole.maanaim:
      return 'maanaim';
    case UserRole.region:
      return 'region';
    case UserRole.area:
      return 'area';
    case UserRole.polo:
      return 'polo';
    case UserRole.readonly:
      return 'readonly';
  }
}

class UserProfile extends Equatable {
  final String uid;
  final String displayName;
  final String email;
  final UserRole role;
  final bool active;
  final String? regionId;
  final String? areaId;
  final String? poloId;
  final String? phone;
  final String? photoUrl;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const UserProfile({
    required this.uid,
    required this.displayName,
    required this.email,
    required this.role,
    required this.active,
    this.regionId,
    this.areaId,
    this.poloId,
    this.phone,
    this.photoUrl,
    this.createdAt,
    this.updatedAt,
  });

  bool get isScopedMaanaim => role == UserRole.maanaim;
  bool get isScopedRegion => role == UserRole.region && regionId != null;
  bool get isScopedArea => role == UserRole.area && areaId != null;
  bool get isScopedPolo => role == UserRole.polo && poloId != null;

  @override
  List<Object?> get props =>
      [uid, displayName, email, role, active, regionId, areaId, poloId, phone, photoUrl];

  UserProfile copyWith({
    String? displayName,
    String? email,
    UserRole? role,
    bool? active,
    String? regionId,
    String? areaId,
    String? poloId,
    String? phone,
    String? photoUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserProfile(
      uid: uid,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      role: role ?? this.role,
      active: active ?? this.active,
      regionId: regionId ?? this.regionId,
      areaId: areaId ?? this.areaId,
      poloId: poloId ?? this.poloId,
      phone: phone ?? this.phone,
      photoUrl: photoUrl ?? this.photoUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
