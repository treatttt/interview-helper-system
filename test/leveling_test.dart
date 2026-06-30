import 'package:flutter_test/flutter_test.dart';
import 'package:interview_helper_system/utils/leveling.dart';

void main() {
  group('levelForXp', () {
    test('нулевой XP — первый уровень, прогресс 0', () {
      final info = levelForXp(0);
      expect(info.level, 1);
      expect(info.tier, levelTiers.first);
      expect(info.xpIntoLevel, 0);
      expect(info.xpToNext, xpPerLevel);
    });

    test('середина уровня считает остаток и остаток до следующего', () {
      final info = levelForXp(120);
      expect(info.level, 1);
      expect(info.xpIntoLevel, 120);
      expect(info.xpToNext, xpPerLevel - 120);
    });

    test('ровно на границе уровня переходит на следующий', () {
      final info = levelForXp(xpPerLevel);
      expect(info.level, 2);
      expect(info.xpIntoLevel, 0);
      expect(info.tier, levelTiers[1]);
    });

    test('тир не превышает потолок при большом XP', () {
      final info = levelForXp(xpPerLevel * 1000);
      expect(info.tier, levelTiers.last);
      expect(info.nextTier, levelTiers.last);
      expect(info.level, greaterThan(levelTiers.length));
    });

    test('отрицательный XP трактуется как ноль', () {
      final info = levelForXp(-50);
      expect(info.level, 1);
      expect(info.xpIntoLevel, 0);
    });
  });
}
