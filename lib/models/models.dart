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
    if (options.length < 2) return false; // меньше 2 — выбирать не из чего
    if (correctIndexes.isEmpty) return false; // нет правильного ответа
    // Все индексы правильных ответов должны указывать на существующие варианты
    for (final i in correctIndexes) {
      if (i < 0 || i >= options.length) return false;
    }
    return true;
  }

  /// Разбор сырого JSON в типизированный объект,
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

/// Тема группировки вопросов
class Topic {
  final String id;
  final String title;
  final List<Question> questions;

  const Topic({
    required this.id,
    required this.title,
    required this.questions,
  });

  factory Topic.fromJson(Map<String, dynamic> json) => Topic(
        id: json['id'] as String,
        title: json['title'] as String,
        questions: (json['questions'] as List)
            .map((e) => Question.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
