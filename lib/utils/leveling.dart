/// Система уровней, выводимая из накопленного XP. Чистые функции — без UI и
/// состояния, удобно тестировать (по образцу ru_format.dart).
///
/// Пороги и названия тиров — дизайн-константы, заданные «на глаз» под текущий
/// баланс XP; цифры из макета Figma были иллюстративными. Меняются здесь, в
/// одной точке правды.
library;

/// Сколько XP нужно на один уровень. Линейная шкала — простой и предсказуемый
/// прогресс. Тюнить здесь.
const int xpPerLevel = 500;

/// Названия тиров по возрастанию. Последнее — «потолок»: дальше уровень растёт,
/// а тир остаётся максимальным.
const List<String> levelTiers = <String>[
  'Новичок',
  'Стажёр',
  'Младший аналитик',
  'Аналитик',
  'Старший аналитик',
  'Ведущий аналитик',
  'Эксперт',
];

/// Снимок уровня для конкретного XP.
typedef LevelInfo = ({
  int level,
  String tier,
  int xpIntoLevel,
  int xpPerLevel,
  int xpToNext,
  String nextTier,
});

/// Вычисляет уровень, тир и прогресс до следующего уровня по [xp].
///
/// Уровень начинается с 1. `xpIntoLevel` — сколько XP набрано внутри текущего
/// уровня (0..xpPerLevel-1), `xpToNext` — сколько осталось до следующего.
LevelInfo levelForXp(int xp) {
  final safeXp = xp < 0 ? 0 : xp;
  final index = safeXp ~/ xpPerLevel; // 0-based
  final xpIntoLevel = safeXp % xpPerLevel;
  final lastTier = levelTiers.length - 1;
  return (
    level: index + 1,
    tier: levelTiers[index < lastTier ? index : lastTier],
    xpIntoLevel: xpIntoLevel,
    xpPerLevel: xpPerLevel,
    xpToNext: xpPerLevel - xpIntoLevel,
    nextTier: levelTiers[index + 1 < lastTier ? index + 1 : lastTier],
  );
}
