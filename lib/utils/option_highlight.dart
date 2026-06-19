/// Тип подсветки варианта ответа после фиксации ответа пользователем.
enum OptionHighlight {
  /// Верный вариант (выбран — или показываем правильный для одиночного выбора).
  correct,

  /// Верный вариант, который пользователь пропустил (только мультивыбор).
  missed,

  /// Неверный вариант, который пользователь выбрал.
  wrong,

  /// Нейтральный вариант — не выбран и не является правильным.
  neutral,
}

/// Определяет тип подсветки варианта ответа.
///
/// Правила:
/// - Одиночный выбор: правильный вариант всегда `correct`; неверный выбор → `wrong`.
/// - Мультивыбор: правильный+выбранный → `correct`; правильный+пропущенный → `missed`;
///   неверный+выбранный → `wrong`.
OptionHighlight resolveOptionHighlight({
  required bool isCorrect,
  required bool isPicked,
  required bool isMultiChoice,
}) {
  if (isCorrect) {
    // Для одиночного выбора показываем правильный ответ зелёным в любом случае.
    if (!isMultiChoice || isPicked) return OptionHighlight.correct;
    return OptionHighlight.missed;
  }
  if (isPicked) return OptionHighlight.wrong;
  return OptionHighlight.neutral;
}
