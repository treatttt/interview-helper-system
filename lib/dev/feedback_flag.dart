// Конфигурация инструмента обратной связи для тестовых сборок.
//
// Весь модуль `lib/dev/` попадает в бинарь только когда [kFeedbackEnabled]
// истинен. В прод-сборке константа равна `false`, и tree-shaking полностью
// удаляет связанный код — прод-путь не меняется.

/// Включает оверлей обратной связи.
///
/// Тестовая сборка: `flutter build apk --dart-define=FEEDBACK=true`.
/// Прод-сборка: без флага → `false` → код вырезается компилятором.
const bool kFeedbackEnabled = bool.fromEnvironment('FEEDBACK');

/// Канал доставки: куда тестер вставляет скопированный отчёт.
///
/// Подходит любая ссылка - Google Forms, Telegram, mailto. Меняется без
/// правки кода: `--dart-define=FEEDBACK_URL=https://forms.gle/xxxx`.
const String kFeedbackDestination = String.fromEnvironment(
  'FEEDBACK_URL',
  defaultValue: 'https://forms.gle/REPLACE_ME',
);

/// Версия приложения в отчёте. По умолчанию совпадает с pubspec.
/// Можно переопределить: `--dart-define=APP_VERSION=1.2.0+5`.
const String kFeedbackAppVersion = String.fromEnvironment(
  'APP_VERSION',
  defaultValue: '1.0.0+1',
);
