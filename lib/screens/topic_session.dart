import 'dart:async';

import 'package:flutter/material.dart';
import 'package:interview_helper_system/models/models.dart';
import 'package:interview_helper_system/screens/session_screen.dart';
import 'package:interview_helper_system/services/progress_service.dart';

/// Прогресс по одной теме, агрегированный по всему каталогу (все треки и грейды).
class TopicProgress {
  const TopicProgress({
    required this.title,
    required this.total,
    required this.mastered,
  });

  final String title;
  final int total;
  final int mastered;

  double get fraction => total == 0 ? 0.0 : mastered / total;

  bool get allMastered => total > 0 && mastered >= total;
}

/// Собирает список тем из загруженного каталога: группирует вопросы по
/// [Question.topic] (вопросы без темы пропускаются), считает всего/освоено по
/// каждой теме. Порядок — по первому появлению темы при обходе треков и грейдов
/// по их [order]. Темы могут встречаться в нескольких треках/грейдах — счётчики
/// суммируются по всем.
List<TopicProgress> buildTopicCatalog(
  List<Track> tracks,
  ProgressService progress,
) {
  final order = <String>[];
  final total = <String, int>{};
  final mastered = <String, int>{};

  final sortedTracks = [...tracks]..sort((a, b) => a.order.compareTo(b.order));
  for (final track in sortedTracks) {
    final grades = [...track.grades]
      ..sort((a, b) => a.order.compareTo(b.order));
    for (final grade in grades) {
      final masteredIds = progress.masteredIds(track.id, grade.id);
      for (final q in grade.questions) {
        final topic = q.topic;
        if (topic == null || topic.isEmpty) continue;
        if (!total.containsKey(topic)) {
          order.add(topic);
          total[topic] = 0;
          mastered[topic] = 0;
        }
        total[topic] = total[topic]! + 1;
        if (masteredIds.contains(q.id)) {
          mastered[topic] = mastered[topic]! + 1;
        }
      }
    }
  }

  return [
    for (final topic in order)
      TopicProgress(
        title: topic,
        total: total[topic]!,
        mastered: mastered[topic]!,
      ),
  ];
}

/// Запуск сессии по теме [topicTitle]: берём первый грейд (по порядку), где есть
/// непройденные вопросы этой темы, и гоняем только их подмножество. Прогресс
/// пишется под обычным ключом track_grade этого грейда.
///
/// persistIncomplete: false — короткая тема-сессия не резюмируется и не трогает
/// единственный слот незавершённой сессии грейда (иначе полногрейдовая пауза
/// была бы перезаписана/затёрта). Тема может лежать в нескольких грейдах —
/// остаток всплывёт при следующем заходе. Если непройденных вопросов темы не
/// осталось — показываем SnackBar.
void startTopicSession(
  BuildContext context, {
  required List<Track> tracks,
  required ProgressService progress,
  required String topicTitle,
}) {
  final sortedTracks = [...tracks]..sort((a, b) => a.order.compareTo(b.order));
  for (final track in sortedTracks) {
    final grades = [...track.grades]
      ..sort((a, b) => a.order.compareTo(b.order));
    for (final grade in grades) {
      final mastered = progress.masteredIds(track.id, grade.id);
      final questions = grade.questions
          .where((q) => q.topic == topicTitle && !mastered.contains(q.id))
          .toList();
      if (questions.isNotEmpty) {
        unawaited(
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => SessionScreen(
                track: track,
                grade: grade,
                questions: questions,
                progress: progress,
                persistIncomplete: false,
              ),
            ),
          ),
        );
        return;
      }
    }
  }

  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(
          'Все вопросы темы «$topicTitle» пройдены. '
          'Сбрось грейд в каталоге, чтобы повторить.',
        ),
      ),
    );
}
