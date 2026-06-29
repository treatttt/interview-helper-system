import 'package:interview_helper_system/controllers/session_controller.dart';

/// Текст-похвала по проценту верных ответов сессии (0..100).
///
/// Пороги (включительно снизу, исключительно сверху):
///   • [0, 50)   — «Тебе нужно подготовиться лучше»
///   • [50, 60)  — «Неплохой результат»
///   • [60, 90)  — «Хороший результат»
///   • [90, 100] — «Отличный результат»
String praiseForScore(int percent) {
  if (percent < 50) return 'Тебе нужно подготовиться лучше';
  if (percent < 60) return 'Неплохой результат';
  if (percent < 90) return 'Хороший результат';
  return 'Отличный результат';
}

/// Тема и её процент освоения в рамках одной сессии.
class TopicScore {
  const TopicScore(this.title, this.percent);
  final String title;
  final int percent; // 0..100
}

/// «Стоит повторить»: слабые темы завершённой сессии.
///
/// Для каждой темы из [answers] считаем долю верных ответов
/// (percent = верные / всего по теме · 100) — это и есть система оценки темы.
/// Оставляем только темы с ошибками (percent < 100), сортируем от слабейшей и
/// берём не более [limit]. Вопросы без темы игнорируются.
List<TopicScore> weakTopicsFromAnswers(
  List<AnsweredQuestion> answers, {
  int limit = 4,
}) {
  final total = <String, int>{};
  final correct = <String, int>{};
  for (final a in answers) {
    final topic = a.question.topic;
    if (topic == null || topic.trim().isEmpty) continue;
    total[topic] = (total[topic] ?? 0) + 1;
    if (a.outcome == AnswerOutcome.correct) {
      correct[topic] = (correct[topic] ?? 0) + 1;
    }
  }

  final scores = <TopicScore>[];
  total.forEach((topic, count) {
    final percent = ((correct[topic] ?? 0) / count * 100).round();
    if (percent < 100) scores.add(TopicScore(topic, percent));
  });
  scores.sort((a, b) => a.percent.compareTo(b.percent));
  return scores.take(limit).toList();
}
