import '../../core/theme/app_theme.dart';
import 'package:flutter/material.dart';

enum AttendanceLevel { high, medium, low }

AttendanceLevel attendanceLevelFromRate(double rate) {
  final pct = rate * 100;
  if (pct >= 80) return AttendanceLevel.high;
  if (pct >= 60) return AttendanceLevel.medium;
  return AttendanceLevel.low;
}

Color attendanceLevelColor(AttendanceLevel level) => switch (level) {
      AttendanceLevel.high => AppTheme.success,
      AttendanceLevel.medium => AppTheme.warning,
      AttendanceLevel.low => AppTheme.error,
    };

Color attendanceRateColor(double rate) => switch (attendanceLevelFromRate(rate)) {
      AttendanceLevel.high => AppTheme.success,
      AttendanceLevel.medium => const Color(0xFFD4A017),
      AttendanceLevel.low => AppTheme.error,
    };

({Color bg, Color fg}) attendanceDateBadgeColors(double rate) {
  if (attendanceLevelFromRate(rate) == AttendanceLevel.low) {
    return (bg: const Color(0xFFFDECEC), fg: AppTheme.error);
  }
  return (bg: const Color(0xFFE7F3F7), fg: AppTheme.primary);
}

/// Cor para varredura de lista: só destaca o que pede atenção.
Color attendanceScanColor(double rate) {
  return switch (attendanceLevelFromRate(rate)) {
    AttendanceLevel.high => const Color(0xFF1F2937),
    AttendanceLevel.medium => AppTheme.accentOrange,
    AttendanceLevel.low => AppTheme.error,
  };
}

enum FrequencyInsight { excellent, good, regular, low }

FrequencyInsight? frequencyInsightFromRate(double rate, {required bool hasEvents}) {
  if (!hasEvents) return null;
  final pct = rate * 100;
  if (pct >= 90) return FrequencyInsight.excellent;
  if (pct >= 75) return FrequencyInsight.good;
  if (pct >= 60) return FrequencyInsight.regular;
  return FrequencyInsight.low;
}

extension FrequencyInsightCopy on FrequencyInsight {
  String get title => switch (this) {
        FrequencyInsight.excellent => 'Frequência excelente',
        FrequencyInsight.good => 'Boa frequência',
        FrequencyInsight.regular => 'Frequência regular',
        FrequencyInsight.low => 'Frequência baixa',
      };

  String get body => switch (this) {
        FrequencyInsight.excellent => 'O membro manteve uma ótima frequência no período.',
        FrequencyInsight.good => 'O membro manteve uma boa frequência no período.',
        FrequencyInsight.regular => 'O membro teve frequência regular no período.',
        FrequencyInsight.low => 'A frequência ficou abaixo do esperado no período.',
      };
}
