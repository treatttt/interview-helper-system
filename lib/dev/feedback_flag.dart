// Конфигурация инструмента обратной связи для тестовых сборок.
//
// Весь модуль `lib/dev/` попадает в бинарь только когда [kFeedbackEnabled]
// истинен. В прод-сборке константа равна `false`, и tree-shaking полностью
// удаляет связанный код (включая захардкоженные ниже строки) — прод-путь
// и прод-бинарь не меняются.

/// Включает оверлей обратной связи. НЕ хардкодить в `true` — иначе фидбек
/// попадёт и в прод-сборку. Тестовый билд: `--dart-define=FEEDBACK=true`.
const bool kFeedbackEnabled = bool.fromEnvironment('FEEDBACK');

/// URL `.../formResponse` Google-формы. Можно переопределить флагом
/// `--dart-define=FEEDBACK_FORM_URL=...`, иначе берётся значение по умолчанию.
const String kFeedbackFormUrl = String.fromEnvironment('FEEDBACK_FORM_URL');

/// ID поля «Отчёт» (весь текст). Обязательное — без него отправка выключена.
/// Вставь сюда `entry.NNN` из «Получить заполненную ссылку».
const String kEntryText = String.fromEnvironment(
  'FEEDBACK_ENTRY_TEXT',
  defaultValue: '', // ← entry.NNN поля «Отчёт»
);

/// ID поля «Тип» (Баг/Идея). Опционально — отдельная колонка для фильтра.
const String kEntryType = String.fromEnvironment(
  'FEEDBACK_ENTRY_TYPE',
  defaultValue: '', // ← entry.NNN поля «Тип» (или оставь пустым)
);

/// ID поля «Экран». Опционально.
const String kEntryScreen = String.fromEnvironment(
  'FEEDBACK_ENTRY_SCREEN',
  defaultValue: '', // ← entry.NNN поля «Экран» (или оставь пустым)
);

/// ID поля «Версия». Опционально.
const String kEntryVersion = String.fromEnvironment(
  'FEEDBACK_ENTRY_VERSION',
  defaultValue: '', // ← entry.NNN поля «Версия» (или оставь пустым)
);

/// ID поля «ID отчёта» для сквозного отслеживания. Опционально.
const String kEntryId = String.fromEnvironment(
  'FEEDBACK_ENTRY_ID',
  defaultValue: '', // ← entry.NNN поля «ID отчёта» (или оставь пустым)
);

/// Версия приложения в отчёте. По умолчанию совпадает с pubspec.
const String kFeedbackAppVersion = String.fromEnvironment(
  'APP_VERSION',
  defaultValue: '1.0.0+1',
);

/// Настроена ли авто-отправка: задан URL формы и поле текста.
bool get kFeedbackAutoSend =>
    kFeedbackFormUrl.isNotEmpty && kEntryText.isNotEmpty;