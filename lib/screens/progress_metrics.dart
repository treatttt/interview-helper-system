import 'package:interview_helper_system/models/models.dart';

/// Число освоенных тем по всему каталогу треков.
///
/// Тема считается освоенной, если ВСЕ валидные вопросы этой темы
/// (по всем трекам и грейдам) входят в mastered. Маппинг gradeKey выполняет
/// сам вызывающий через [masteredIds] — ProgressService туда не тянем.
int countMasteredTopics(
  List<Track> tracks,
  Set<String> Function(String trackId, String gradeId) masteredIds,
) {
  // topic → все валидные questionId по каталогу
  final topicQuestions = <String, Set<String>>{};
  for (final track in tracks) {
    for (final grade in track.grades) {
      for (final q in grade.questions) {
        if (!q.isValid) continue;
        final topic = q.topic;
        if (topic == null || topic.isEmpty) continue;
        topicQuestions.putIfAbsent(topic, () => {}).add(q.id);
      }
    }
  }
  if (topicQuestions.isEmpty) return 0;

  // Все освоенные ID по всем грейдам
  final allMastered = <String>{};
  for (final track in tracks) {
    for (final grade in track.grades) {
      allMastered.addAll(masteredIds(track.id, grade.id));
    }
  }

  return topicQuestions.values
      .where((ids) => ids.isNotEmpty && allMastered.containsAll(ids))
      .length;
}

/// Прогресс грейда: доля освоенных валидных вопросов (0..1) и признак «Скоро».
///
/// isSoon = true означает, что в грейде нет ни одного валидного вопроса —
/// логика совпадает с grades_screen.dart (hasQuestions = grade.questions.any(isValid)).
({double fraction, bool isSoon}) gradeProgress(
  String trackId,
  Grade grade,
  Set<String> Function(String trackId, String gradeId) masteredIds,
) {
  final validCount = grade.questions.where((q) => q.isValid).length;
  if (validCount == 0) return (fraction: 0.0, isSoon: true);
  final done = masteredIds(trackId, grade.id).length;
  return (fraction: (done / validCount).clamp(0.0, 1.0), isSoon: false);
}

/// Дельта точности: точность последнего дня минус точность первого дня в логе.
///
/// Возвращает null, если в логе менее двух дней.
double? accuracyDelta(Map<String, ({int answers, int correct})> log) {
  if (log.length < 2) return null;
  final sortedKeys = log.keys.toList()..sort();
  double acc(String key) {
    final e = log[key]!;
    return e.answers == 0 ? 0.0 : e.correct / e.answers;
  }
  return acc(sortedKeys.last) - acc(sortedKeys.first);
}
