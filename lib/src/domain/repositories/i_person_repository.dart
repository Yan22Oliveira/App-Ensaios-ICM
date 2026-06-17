import '../../src.dart';

abstract class IPersonRepository {
  Future<Person> create(Person p);
  Future<Person> update(Person p); // ← novo
  Future<List<Person>> list({
    String? regionId,
    List<String>? regionIds,
    String? areaId,
    String? poloId,
    List<String>? roles,
    String? search,
    RehearsalLevel? worshipLevel,
  });
  /// Stream em tempo real com os mesmos filtros (sem search/worshipLevel).
  Stream<List<Person>> watchList({
    String? regionId,
    List<String>? regionIds,
    String? areaId,
    String? poloId,
    List<String>? roles,
  });
  Future<Person?> getById(String id);
  Future<List<Person>> bulkCreate(List<Person> people);
}