import '../../src.dart';

abstract class IRehearsalRepository {
  Future<List<Rehearsal>> listUpcoming();
  /// Stream de ensaios futuros (a partir de hoje), atualizado em tempo real.
  Stream<List<Rehearsal>> watchUpcoming();
  /// Ensaios já encerrados (closed == true), mais recentes primeiro.
  Future<List<Rehearsal>> listClosed();
  /// Stream de ensaios encerrados em tempo real.
  Stream<List<Rehearsal>> watchClosed();
  Future<Rehearsal> getById(String id);

  /// Retorna ensaios cujo `dateTime` está entre [start, end] (limites inclusivos).
  Future<List<Rehearsal>> listBetween(DateTime start, DateTime end);

  Future<Rehearsal> create({
    required DateTime dateTime,
    required RehearsalLevel level,
    required String regionId,
    String? areaId,
    String? poloId,
    String? place,
    String? description,
  });

  /// Retorna o próximo ensaio (dateTime > agora), ou null se não houver.
  Future<Rehearsal?> nextUpcoming();

  /// finalizar/encerrar
  Future<void> close(String id);

  Future<Rehearsal> update({
    required String id,
    required DateTime dateTime,
    required RehearsalLevel level,
    required String regionId,
    String? areaId,
    String? poloId,
    String? place,
    String? description,
    bool? closed,        // opcional, caso queira alterar o status
    DateTime? closedAt,  // opcional
  });

  Future<void> delete(String id);

}