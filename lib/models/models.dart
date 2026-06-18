/// Вопросы: текст, вариант ответа, индексы правильных
class Question {
  final String id;
  final String text;
  final List<String> options;
  final List<int> correctIndexes;

  /// Индексы правильных ответов в options
  final String? explanation;

  const Question({
    required this.id,
    required this.text,
    required this.options,
    required this.correctIndexes,
    this.explanation,
  });

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

  /// Ключи должны совпадать с questions.json
  factory Question.fromJson(Map<String, dynamic> json) => Question(
        id: json['id'] as String,
        text: json['text'] as String,
        options: (json['options'] as List).cast<String>(),
        correctIndexes:
            (json['correctIndexes'] as List).map((e) => e as int).toList(),
        explanation: json['explanation'] as String?,
      );
}

/// Грейд — уровень подготовки внутри направления (Junior / Middle / Senior).
/// Содержит вопросы для сессии и метаданные для отображения.
class Grade {
  final String id;
  final String title;
  final String? description;
  final int order;
  final List<Question> questions;

  const Grade({
    required this.id,
    required this.title,
    this.description,
    required this.order,
    required this.questions,
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
}

/// Направление — верхний уровень группировки (Аналитика, Разработка, Тестирование).
/// Содержит грейды и метаданные для отображения.
class Track {
  final String id;
  final String title;
  final String? description;
  final int order;
  final List<Grade> grades;

  const Track({
    required this.id,
    required this.title,
    this.description,
    required this.order,
    required this.grades,
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
}

/// Обратная совместимость: Topic — псевдоним Grade для плавного перехода.
/// Использовать только в тестах, написанных до переименования.
typedef Topic = Grade;
