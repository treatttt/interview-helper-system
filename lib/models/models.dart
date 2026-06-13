// Модели данных: тема и вопрос.

class Question {
  final String id;
  final String text;
  final List<String> options;
  final int correct;
  final String explanation;

  Question({
    required this.id,
    required this.text,
    required this.options,
    required this.correct,
    required this.explanation,
  });

  factory Question.fromJson(Map<String, dynamic> json) {
    return Question(
      id: json['id'] as String,
      text: json['text'] as String,
      options: (json['options'] as List).map((e) => e as String).toList(),
      correct: json['correct'] as int,
      explanation: json['explanation'] as String,
    );
  }
}

class Topic {
  final String id;
  final String title;
  final List<Question> questions;

  Topic({
    required this.id,
    required this.title,
    required this.questions,
  });

  factory Topic.fromJson(Map<String, dynamic> json) {
    return Topic(
      id: json['id'] as String,
      title: json['title'] as String,
      questions: (json['questions'] as List)
          .map((e) => Question.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
