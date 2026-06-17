import '../../src.dart';

abstract class IGeoRepository {
  /// Lista todos os Maanaims (coleção `maanains`, campo Nome).
  Future<List<Maanaim>> maanaims();
  /// Regiões da subcoleção do documento do Maanaim: `maanains/{maanaimId}/regions`.
  Future<List<Region>> regionsByMaanaim(String maanaimId);

  Future<List<Region>> regions();
  Future<List<Area>> areasByRegion(String regionId);
  Future<List<Polo>> polosByArea(String areaId);
}