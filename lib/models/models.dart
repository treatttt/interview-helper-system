/// Вопросы: текст, вариант ответа, индексы правильных
class Question {
  final String id;
  final String topic;
  final String text;
  final List<String> options;
  final List<int> correctIndexes; /// Индексы правильных ответов в options

  const Question({
    required this.id,
    required this.topic,
    required this.text,
    required this.options,
    required this.correctIndexes,
});

  bool get isMultipleChoice => correctIndexes.length > 1;

  /// Разбор сырого JSON в типизированный объект,
  /// Ключи должны совпадать с questions.json
  factory Question.fromJson(Map<String, dynamic> json) => Question(
    id: json['id'] as String,
    topic: json['topic'] as String,
    text: json['text'] as String,
    options: (json['options'] as List).cast<String>(),
    correctIndexes: (json['correctIndexes'] as List).cast<int>(),
  );
}

/// Тема группировки вопросов
class Topic {
  final String id;
  final String title;

  const Topic({required this.id, required this.title});

  factory Topic.fromJson(Map<String, dynamic> json) => Topic(
    id: json['id'] as String,
    title: json['title'] as String,
  );
}