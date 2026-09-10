import 'package:class_attendance/src/domain/models/user_profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UserRoleLabel', () {
    test('rótulos em português', () {
      expect(UserRole.admin.label, 'Administrador');
      expect(UserRole.maanaim.label, 'Maanaim');
      expect(UserRole.region.label, 'Região');
      expect(UserRole.area.label, 'Área');
      expect(UserRole.polo.label, 'Polo');
      expect(UserRole.readonly.label, 'Somente leitura');
    });
  });
}
