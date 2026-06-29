/// Вопросы: текст, вариант ответа, индексы правильных
class Question {

  const Question({
    required this.id,
    required this.text,
    required this.options,
    required this.correctIndexes,
    this.explanation,
    this.topic,
    this.codeSnippet,
    this.codeLanguage,
    this.importantToKnow,
    this.mustRepeat,
    this.xpReward = defaultXpReward,
  });

  /// Ключи должны совпадать с questions.json
  factory Question.fromJson(Map<String, dynamic> json) => Question(
        id: json['id'] as String,
        text: json['text'] as String,
        options: (json['options'] as List).cast<String>(),
        correctIndexes:
            (json['correctIndexes'] as List).map((e) => e as int).toList(),
        explanation: json['explanation'] as String?,
        topic: json['topic'] as String?,
        codeSnippet: json['codeSnippet'] as String?,
        codeLanguage: json['codeLanguage'] as String?,
        importantToKnow:
            (json['importantToKnow'] as List?)?.map((e) => e as String).toList(),
        mustRepeat:
            (json['mustRepeat'] as List?)?.map((e) => e as String).toList(),
        xpReward: (json['xpReward'] as int?) ?? defaultXpReward,
      );

  /// Награда XP за верный ответ по умолчанию, если у вопроса не задан [xpReward].
  /// Один источник правды — менять здесь, а не россыпью по коду.
  static const defaultXpReward = 10;

  final String id;
  final String text;
  final List<String> options;
  final List<int> correctIndexes;
  final String? explanation;

  /// Тематическая метка вопроса (напр. «SQL», «ООП»). Используется для метрик дашборда.
  final String? topic;

  /// Пункты «Важно знать» — показываются на экране верного ответа (смежные
  /// знания). Берутся из questions.json, не хардкодятся в UI. Необязательно.
  final List<String>? importantToKnow;

  /// Пункты «Нужно повторить» — показываются на экране неверного ответа.
  /// Берутся из questions.json, не хардкодятся в UI. Необязательно.
  final List<String>? mustRepeat;

  /// Фрагмент кода, отображаемый над вариантами ответа. Необязательный.
  final String? codeSnippet;

  /// Язык кода для будущей подсветки синтаксиса (напр. 'dart', 'sql'). Необязательный.
  final String? codeLanguage;

  /// Сколько XP начисляется за верный ответ на этот вопрос. Лёгкие вопросы можно
  /// оценить дешевле, сложные — дороже; значение берётся из questions.json
  /// (поле `xpReward`), не хардкодится в UI/сервисе. По умолчанию
  /// [defaultXpReward].
  final int xpReward;

  bool get isMultipleChoice => correctIndexes.length > 1;

  /// Вопрос валиден, если из него можно составить осмысленный вопрос-выбор.
  bool get isValid {
    if (text.trim().isEmpty) return false;
    if (options.length < 2) return false;
    if (correctIndexes.isEmpty) return false;
    for (final i in correctIndexes) {
      if (i < 0 || i >= options.length) return false;
    }
    return true;
  }
}

/// Грейд — уровень подготовки внутри направления (Junior / Middle / Senior).
/// Содержит вопросы для сессии и метаданные для отображения.
class Grade {

  const Grade({
    required this.id,
    required this.title,
    required this.order,
    required this.questions,
    this.description,
  });

  factory Grade.fromJson(Map<String, dynamic> json) => Grade(
        id: json['id'] as String,
        title: json['title'] as String,
        description: json['description'] as String?,
        order: (json['order'] as int?) ?? 0,
        questions: (json['questions'] as List)
            .map((e) => Question.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
  final String id;
  final String title;
  final String? description;
  final int order;
  final List<Question> questions;
}

/// Направление — верхний уровень группировки (Аналитика, Разработка, Тестирование).
/// Содержит грейды и метаданные для отображения.
class Track {
  const Track({
    required this.id,
    required this.title,
    required this.order,
    required this.grades,
    this.description,
    this.category,
  });

  factory Track.fromJson(Map<String, dynamic> json) => Track(
        id: json['id'] as String,
        title: json['title'] as String,
        description: json['description'] as String?,
        order: json['order'] as int,
        category: json['category'] as String?,
        grades: (json['grades'] as List)
            .map((e) => Grade.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
  final String id;
  final String title;
  final String? description;
  final int order;

  /// Категория трека. "language" — языковой трек (Go, Python и т.д.),
  /// скрывается из секции «Все направления» на Обзоре.
  final String? category;

  final List<Grade> grades;
}

/// Обратная совместимость: Topic — псевдоним Grade для плавного перехода.
/// Использовать только в тестах, написанных до переименования.
typedef Topic = Grade;
