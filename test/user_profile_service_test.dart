import 'package:flutter_test/flutter_test.dart';
import 'package:interview_helper_system/services/user_profile_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('UserProfileService', () {
    test('по умолчанию имя пустое, displayName — заглушка', () async {
      final service = UserProfileService();
      await service.init();

      expect(service.firstName, '');
      expect(service.displayName, UserProfileService.fallbackName);
    });

    test('только имя — допустимо, фамилия остаётся пустой', () async {
      final service = UserProfileService();
      await service.init();

      await service.setName('Никита');

      expect(service.firstName, 'Никита');
      expect(service.lastName, isNull);
      expect(service.displayName, 'Никита');
    });

    test('имя и фамилия объединяются в displayName', () async {
      final service = UserProfileService();
      await service.init();

      await service.setName('Никита', 'Борков');

      expect(service.displayName, 'Никита Борков');
    });

    test('значения переживают перезагрузку', () async {
      final first = UserProfileService();
      await first.init();
      await first.setName('Аня');

      final reloaded = UserProfileService();
      await reloaded.init();
      expect(reloaded.firstName, 'Аня');
    });

    test('смена направления сбрасывает целевой грейд', () async {
      final service = UserProfileService();
      await service.init();
      await service.setDirection('analytics');
      await service.setTargetGrade('middle');
      expect(service.targetGradeId, 'middle');

      await service.setDirection('dev');
      expect(service.directionTrackId, 'dev');
      expect(service.targetGradeId, isNull);
    });
  });
}
