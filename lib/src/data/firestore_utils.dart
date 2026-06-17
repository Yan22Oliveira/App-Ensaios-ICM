import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/domain.dart';

DateTime? tsToDate(Timestamp? t) => t?.toDate();
Timestamp dateToTs(DateTime d) => Timestamp.fromDate(d);

// Enum <-> String (para gravar legível)
String levelToStr(RehearsalLevel l) => switch (l) {
  RehearsalLevel.polo => 'polo',
  RehearsalLevel.area => 'area',
  RehearsalLevel.region => 'region',
  RehearsalLevel.maanaim => 'maanaim',
};
RehearsalLevel levelFromStr(String? s) {
  final key = (s ?? '').trim().toLowerCase();
  switch (key) {
    case 'maanaim':
      return RehearsalLevel.maanaim;
    case 'region':
      return RehearsalLevel.region;
    case 'area':
      return RehearsalLevel.area;
    case 'polo':
      return RehearsalLevel.polo;
    default:
      return RehearsalLevel.polo;
  }
}

/// Aplica filtros por escopo a uma Query de ensaios (`rehearsals`).
Query<Map<String, dynamic>> applyScopeToRehearsalsQuery(
    Query<Map<String, dynamic>> q,
    UserProfile me,
    ) {
  switch (me.role) {
    case UserRole.admin:
      return q; // sem filtro
    case UserRole.maanaim:
      return q.where('level', isEqualTo: 'maanaim');
    case UserRole.region:
      return q.where('level', isEqualTo: 'region').where('regionId', isEqualTo: me.regionId);
    case UserRole.area:
      return q.where('level', isEqualTo: 'area').where('areaId', isEqualTo: me.areaId);
    case UserRole.polo:
      return q.where('level', isEqualTo: 'polo').where('poloId', isEqualTo: me.poloId);
    case UserRole.readonly:
    // readonly: leitura — mantenha filtrado pelo escopo mais específico disponível
      if (me.poloId != null) {
        return q.where('level', isEqualTo: 'polo').where('poloId', isEqualTo: me.poloId);
      } else if (me.areaId != null) {
        return q.where('level', isEqualTo: 'area').where('areaId', isEqualTo: me.areaId);
      } else if (me.regionId != null) {
        return q.where('level', isEqualTo: 'region').where('regionId', isEqualTo: me.regionId);
      }
      return q.where('level', isEqualTo: '__none__'); // cai em vazio
  }
}
