import '../../src.dart';

abstract class IAttendanceRepository {
  /// Lista os registros de chamada de um ensaio.
  Future<List<AttendanceRecord>> listByRehearsal(String rehearsalId);

  /// Cria/atualiza um registro de presença.
  Future<AttendanceRecord> upsert(AttendanceRecord record);

  /// Upsert em lote (utilizado quando salvar vários de uma vez).
  Future<void> upsertMany(List<AttendanceRecord> records);

  /// Remove um registro por id (opcional).
  Future<void> delete(String id);

/// (Opcional para relatórios futuros)
/// Future<List<AttendanceRecord>> listBetween(DateTime start, DateTime end);
}