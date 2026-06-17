import '../../src.dart';

class GeoNameResolver {
  final IGeoRepository _repo;

  bool _loaded = false;
  bool get isLoaded => _loaded;

  final Map<String, String> _regionNames = {};
  final Map<String, String> _areaNames = {};
  final Map<String, String> _poloNames = {};
  final Map<String, String> _maanaimNames = {};

  GeoNameResolver(this._repo);

  /// Carrega e faz cache dos nomes. Idempotente.
  Future<void> preloadAll() async {
    if (_loaded) return;
    // Maanaims (coleção maanains)
    final maanaims = await _repo.maanaims();
    for (final m in maanaims) {
      _maanaimNames[m.id] = m.name;
    }
    // Regiões
    final regions = await _repo.regions();
    for (final r in regions) {
      _regionNames[r.id] = r.name;
    }

    // Todas as áreas das regiões carregadas
    for (final r in regions) {
      final areas = await _repo.areasByRegion(r.id);
      for (final a in areas) {
        _areaNames[a.id] = a.name;
        // Polos de cada área
        final polos = await _repo.polosByArea(a.id);
        for (final p in polos) {
          _poloNames[p.id] = p.name;
        }
      }
    }

    _loaded = true;
  }

  String? regionName(String? id) => id == null ? null : (_maanaimNames[id] ?? _regionNames[id]);
  String? areaName(String? id) => id == null ? null : _areaNames[id];
  String? poloName(String? id) => id == null ? null : _poloNames[id];
  /// Nome do Maanaim (só da coleção maanains).
  String? maanaimName(String? id) => id == null ? null : _maanaimNames[id];

  /// Helpers para uso em formulários (opcionais)
  Future<List<Maanaim>> maanaims() => _repo.maanaims();
  Future<List<Region>> regionsByMaanaim(String maanaimId) => _repo.regionsByMaanaim(maanaimId);
  Future<List<Region>> regions() => _repo.regions();
  Future<List<Area>> areasByRegion(String regionId) => _repo.areasByRegion(regionId);
  Future<List<Polo>> polosByArea(String areaId) => _repo.polosByArea(areaId);

  // ================================================================
  // Labels e Helpers para UI
  // ================================================================

  /// "Polo", "Area", "Region", "Maanaim"
  String levelLabel(RehearsalLevel l) => switch (l) {
    RehearsalLevel.polo => 'Polo',
    RehearsalLevel.area => 'Área',
    RehearsalLevel.region => 'Região',
    RehearsalLevel.maanaim => 'Maanaim',
  };

  /// "Polo", "Area", "Region", "Maanaim"
  String levelName(Rehearsal r) => switch (r.level) {
    RehearsalLevel.polo => 'Polo ${poloName(r.poloId)}',
    RehearsalLevel.area => 'Área ${areaName(r.areaId)}',
    RehearsalLevel.region => 'Região ${regionName(r.regionId)}',
    RehearsalLevel.maanaim => 'Maanaim ${maanaimName(r.regionId) ?? regionName(r.regionId) ?? r.regionId}',
  };

  /// "Region: Divinópolis • Area: Centro-Oeste 1/MG • Polo: Jardim América"
  String locationLabel(Rehearsal r) {
    final parts = <String>[];
    final region = regionName(r.regionId);
    if (region != null) parts.add('Região: $region');

    final area = areaName(r.areaId);
    if (area != null) parts.add('Área: $area');

    final polo = poloName(r.poloId);
    if (polo != null) parts.add('Polo: $polo');

    if (parts.isEmpty) return levelLabel(r.level);
    return parts.join(' • ');
  }

  /// Exemplo para pessoas (opcional, útil em listas):
  /// "Polo Jardim América • Area Centro-Oeste 1/MG • Divinópolis"
  String personLocationLine(Person p) {
    final parts = <String>[];
    final polo = poloName(p.poloId);
    final area = areaName(p.areaId);
    final region = regionName(p.regionId);

    if (polo != null) parts.add('Polo $polo');
    if (area != null) parts.add('Área $area');
    if (region != null) parts.add(region);
    return parts.join(' • ');
  }
}
