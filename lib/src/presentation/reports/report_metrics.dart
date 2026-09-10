import '../../domain/entities.dart';
import 'reports_controller.dart';

bool rehearsalMatchesFilters(Rehearsal r, ReportFilters filters) {
  if (filters.eventType != null && r.eventType != filters.eventType) return false;
  if (filters.level != null && r.level != filters.level) return false;
  if (filters.regionId != null && r.regionId != filters.regionId) return false;
  if (filters.areaId != null && r.areaId != filters.areaId) return false;
  if (filters.poloId != null && r.poloId != filters.poloId) return false;
  return true;
}

/// Registro da pessoa na chamada daquele evento, ou null se não estava convocado.
PersonEventMark? attendanceMarkForPerson({
  required Rehearsal rehearsal,
  required List<AttendanceRecord> records,
  required String personId,
}) {
  for (final record in records) {
    if (record.personId == personId) {
      return PersonEventMark(rehearsal: rehearsal, status: record.status);
    }
  }
  return null;
}

String formatAttendancePercent(double rate) {
  if (rate.isNaN || rate.isInfinite) return '0,0%';
  return '${(rate * 100).toStringAsFixed(1).replaceAll('.', ',')}%';
}

String displayPersonName(String raw) {
  final t = raw.trim();
  if (t.isEmpty) return t;
  final letters = t.replaceAll(RegExp(r'[^A-Za-zÀ-ÿ]'), '');
  if (letters.isEmpty || letters != letters.toUpperCase()) return t;
  const small = {'DA', 'DE', 'DO', 'DAS', 'DOS', 'E', 'DI', 'DEL'};
  final words = t.split(RegExp(r'\s+'));
  return words.asMap().entries.map((e) {
    final w = e.value;
    if (w.isEmpty) return w;
    if (e.key > 0 && small.contains(w.toUpperCase())) return w.toLowerCase();
    return '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}';
  }).join(' ');
}

String personInitials(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((w) {
        const skip = {'da', 'de', 'do', 'das', 'dos', 'e', 'di', 'del'};
        return w.isNotEmpty && !skip.contains(w.toLowerCase());
      })
      .toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first[0].toUpperCase();
  return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
}

class ReportPeriodTotals {
  final int eventCount;
  final int uniqueParticipantCount;
  final int presentCount;
  final int unjustifiedCount;
  final int justifiedCount;

  const ReportPeriodTotals({
    required this.eventCount,
    required this.uniqueParticipantCount,
    required this.presentCount,
    required this.unjustifiedCount,
    required this.justifiedCount,
  });

  int get totalParticipations => presentCount + unjustifiedCount + justifiedCount;

  /// Presença = presentes / (P + F + J). Justificadas entram no denominador.
  double get attendanceRate =>
      totalParticipations == 0 ? 0.0 : presentCount / totalParticipations;

  factory ReportPeriodTotals.fromSummaries({
    required List<RehearsalSummary> events,
    required int uniqueParticipantCount,
  }) {
    final present = events.fold<int>(0, (acc, e) => acc + e.present);
    final unjustified = events.fold<int>(0, (acc, e) => acc + e.unjustified);
    final justified = events.fold<int>(0, (acc, e) => acc + e.justified);
    return ReportPeriodTotals(
      eventCount: events.length,
      uniqueParticipantCount: uniqueParticipantCount,
      presentCount: present,
      unjustifiedCount: unjustified,
      justifiedCount: justified,
    );
  }
}
