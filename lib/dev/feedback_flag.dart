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

/// URL `.../formResponse` Google-формы для авто-отправки отчёта.
/// `--dart-define=FEEDBACK_FORM_URL=https://docs.google.com/forms/d/e/XXX/formResponse`
const String kFeedbackFormUrl = String.fromEnvironment('FEEDBACK_FORM_URL');

/// ID поля формы для полного текста отчёта (catch-all). Обязательное.
/// Без него авто-отправка выключена. Пример: `entry.123456789`.
const String kEntryText = String.fromEnvironment('FEEDBACK_ENTRY_TEXT');

/// ID поля «Тип» (Баг/Идея). Опционально — отдельная колонка для фильтра.
const String kEntryType = String.fromEnvironment('FEEDBACK_ENTRY_TYPE');

/// ID поля «Экран». Опционально.
const String kEntryScreen = String.fromEnvironment('FEEDBACK_ENTRY_SCREEN');

/// ID поля «Версия». Опционально.
const String kEntryVersion = String.fromEnvironment('FEEDBACK_ENTRY_VERSION');

/// ID поля «ID отчёта» для сквозного отслеживания. Опционально.
const String kEntryId = String.fromEnvironment('FEEDBACK_ENTRY_ID');

/// Версия приложения в отчёте. По умолчанию совпадает с pubspec.
/// `--dart-define=APP_VERSION=1.2.0+5`
const String kFeedbackAppVersion = String.fromEnvironment(
  'APP_VERSION',
  defaultValue: '1.0.0+1',
);

/// Настроена ли авто-отправка: задан URL формы и поле текста.
bool get kFeedbackAutoSend =>
    kFeedbackFormUrl.isNotEmpty && kEntryText.isNotEmpty;
