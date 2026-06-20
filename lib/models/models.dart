/// Вопросы: текст, вариант ответа, индексы правильных
class Question {

  const Question({
    required this.id,
    required this.text,
    required this.options,
    required this.correctIndexes,
    this.explanation,
    this.topic,
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
      );
  final String id;
  final String text;
  final List<String> options;
  final List<int> correctIndexes;

  /// Индексы правильных ответов в options
  final String? explanation;

  /// Тема вопроса — сквозной тег (напр. «SQL», «API и интеграции»).
  final String? topic;

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
  });

  factory Track.fromJson(Map<String, dynamic> json) => Track(
        id: json['id'] as String,
        title: json['title'] as String,
        description: json['description'] as String?,
        order: json['order'] as int,
        grades: (json['grades'] as List)
            .map((e) => Grade.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
  final String id;
  final String title;
  final String? description;
  final int order;
  final List<Grade> grades;
}

/// Обратная совместимость: Topic — псевдоним Grade для плавного перехода.
/// Использовать только в тестах, написанных до переименования.
typedef Topic = Grade;

/// Вопрос вместе с его исходным треком и грейдом.
/// Хранится в TopicGroup для корректной записи прогресса по нужному gradeKey.
class QuestionOrigin {
  const QuestionOrigin({
    required this.track,
    required this.grade,
    required this.question,
  });

  final Track track;
  final Grade grade;
  final Question question;

  String get gradeKey => '${track.id}_${grade.id}';
}

/// Все вопросы одной темы, собранные из всех треков и грейдов.
class TopicGroup {
  const TopicGroup({required this.title, required this.questions});

  final String title;
  final List<QuestionOrigin> questions;
}
