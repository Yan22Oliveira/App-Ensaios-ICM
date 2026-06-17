import 'package:class_attendance/src/core/theme/app_theme.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppTheme', () {
    test('primary tem valor definido', () {
      expect(AppTheme.primary, isNotNull);
    });

    test('cores de acento estão definidas', () {
      expect(AppTheme.accentPurple, isNotNull);
      expect(AppTheme.accentOrange, isNotNull);
      expect(AppTheme.accentTeal, isNotNull);
    });

    test('light retorna ThemeData', () {
      final theme = AppTheme.light();
      expect(theme, isNotNull);
    });
  });
}
