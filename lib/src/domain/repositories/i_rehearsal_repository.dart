import '../../src.dart';

abstract class IRehearsalRepository {
  Future<List<Rehearsal>> listUpcoming();
  /// Stream de eventos futuros (a partir de hoje), atualizado em tempo real.
  Stream<List<Rehearsal>> watchUpcoming();
  /// Eventos já encerrados (closed == true), mais recentes primeiro.
  Future<List<Rehearsal>> listClosed();
  /// Stream de eventos encerrados em tempo real.
  Stream<List<Rehearsal>> watchClosed();
  Future<Rehearsal> getById(String id);

  /// Retorna eventos cujo `dateTime` está entre [start, end] (limites inclusivos).
  Future<List<Rehearsal>> listBetween(DateTime start, DateTime end);

  Future<Rehearsal> create({
    required DateTime dateTime,
    required RehearsalLevel level,
    required String regionId,
    required EventType eventType,
    String? title,
    String? areaId,
    String? poloId,
    String? place,
    String? description,
    EventParticipantMode participantMode = EventParticipantMode.all,
    List<String> expectedParticipants = const [],
  });

  /// Retorna o próximo evento (dateTime > agora), ou null se não houver.
  Future<Rehearsal?> nextUpcoming();

  /// finalizar/encerrar
  Future<void> close(String id);

  Future<Rehearsal> update({
    required String id,
    required DateTime dateTime,
    required RehearsalLevel level,
    required String regionId,
    required EventType eventType,
    String? title,
    String? areaId,
    String? poloId,
    String? place,
    String? description,
    EventParticipantMode participantMode = EventParticipantMode.all,
    List<String> expectedParticipants = const [],
    bool? closed,
    DateTime? closedAt,
  });

  /// Congela a lista da chamada (primeiro P/F/J ou finalizar).
  Future<void> setParticipantsSnapshot(String id, List<String> personIds);

  Future<void> delete(String id);
}