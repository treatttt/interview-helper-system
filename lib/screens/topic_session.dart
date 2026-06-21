import 'dart:async';

import 'package:flutter/material.dart';
import 'package:interview_helper_system/controllers/session_controller.dart'
    show AnswerOutcome, AnsweredQuestion;
import 'package:interview_helper_system/models/incomplete_session.dart';
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

/// Учитывает вопросы одного грейда в аккумуляторах [total]/[mastered]
/// (тема → счётчик). Вопросы без темы пропускаются. Темы добавляются в карты
/// по первому появлению (Map в Dart хранит ключи в порядке вставки).
void _accumulateGrade(Grade grade,
    Set<String> masteredIds,
    Map<String, int> total,
    Map<String, int> mastered,) {
  for (final q in grade.questions) {
    final topic = q.topic;
    if (topic == null || topic.isEmpty) continue;
    total[topic] = (total[topic] ?? 0) + 1;
    if (masteredIds.contains(q.id)) {
      mastered[topic] = (mastered[topic] ?? 0) + 1;
    }
  }
}

/// Собирает список тем из загруженного каталога: группирует вопросы по
/// [Question.topic] (вопросы без темы пропускаются), считает всего/освоено по
/// каждой теме. Порядок — по первому появлению темы при обходе треков и грейдов
/// по возрастанию их order. Темы могут встречаться в нескольких треках/грейдах —
/// счётчики суммируются по всем.
List<TopicProgress> buildTopicCatalog(
  List<Track> tracks,
  ProgressService progress,
) {
  final total = <String, int>{};
  final mastered = <String, int>{};

  final sortedTracks = [...tracks]..sort((a, b) => a.order.compareTo(b.order));
  for (final track in sortedTracks) {
    final grades = [...track.grades]
      ..sort((a, b) => a.order.compareTo(b.order));
    for (final grade in grades) {
      _accumulateGrade(
        grade,
        progress.masteredIds(track.id, grade.id),
        total,
        mastered,
      );
    }
  }

  return [
    for (final entry in total.entries)
      TopicProgress(
        title: entry.key,
        total: entry.value,
        mastered: mastered[entry.key] ?? 0,
      ),
  ];
}

/// Запуск/продолжение сессии по теме [topicTitle].
///
/// Сначала проверяем тема-слот: если по этой теме есть незавершённый дрилл —
/// предлагаем «Продолжить / Начать заново» (та же логика роллбэка, что у
/// грейдов). Иначе берём первый грейд (по order) с непройденными вопросами темы
/// и гоняем только их подмножество; прогресс пишется под обычным ключом
/// track_grade этого грейда. Тема может лежать в нескольких грейдах — остаток
/// всплывёт при следующем заходе.
///
/// Если непройденных вопросов темы не осталось — показываем SnackBar (защитная
/// ветка: в норме недостижима, см. фильтр пройденных тем на «Обзоре» и сброс на
/// «Темах»).
void startTopicSession(
  BuildContext context, {
  required List<Track> tracks,
  required ProgressService progress,
  required String topicTitle,
}) {
  unawaited(
    _runTopicSession(
      context,
      tracks: tracks,
      progress: progress,
      topicTitle: topicTitle,
    ),
  );
}

Future<void> _runTopicSession(
  BuildContext context, {
  required List<Track> tracks,
  required ProgressService progress,
  required String topicTitle,
}) async {
  if (await _maybeResumeTopic(context, tracks, progress, topicTitle)) return;
  if (!context.mounted) return;
  if (_startFreshTopic(context, tracks, progress, topicTitle)) return;

  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text('В теме «$topicTitle» не осталось новых вопросов.'),
      ),
    );
}

/// Возвращает true, если резюм полностью обработал заход (открыл продолжение).
/// false — если паузы нет/протухла/пользователь выбрал «Начать заново»:
/// вызывающий уходит в свежий старт.
Future<bool> _maybeResumeTopic(
  BuildContext context,
  List<Track> tracks,
  ProgressService progress,
  String topicTitle,
) async {
  final raw = progress.loadIncompleteTopicSession(topicTitle);
  if (raw == null) return false;

  final paused = IncompleteSession.fromJson(raw);
  final args = _resumeArgs(tracks, paused);
  if (args == null) {
    await progress.clearIncompleteTopicSession(topicTitle: topicTitle);
    return false;
  }

  if (!context.mounted) return true;
  final choice = await _showTopicResumeDialog(context, paused);
  if (!context.mounted) return true;

  if (choice == null) return true; // barrier/back dismiss → cancel, keep pause
  if (choice != 'continue') {
    // 'restart': explicit user choice — clear saved topic session
    await progress.clearIncompleteTopicSession(topicTitle: topicTitle);
    return false;
  }

  unawaited(
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SessionScreen(
          track: args.track,
          grade: args.grade,
          questions: args.questions,
          progress: progress,
          initialIndex: args.startIndex,
          previousAnswers: args.previousAnswers,
          topicTitle: topicTitle,
        ),
      ),
    ),
  );
  return true;
}

/// Реконструирует аргументы сессии из паузы: находит грейд по gradeKey и
/// восстанавливает вопросы/ответы. null — если грейд или вопросы не нашлись
/// (данные поменялись) → пауза считается протухшей.
({
  Track track,
  Grade grade,
  List<Question> questions,
  int startIndex,
  List<AnsweredQuestion> previousAnswers,
})? _resumeArgs(List<Track> tracks, IncompleteSession paused) {
  for (final track in tracks) {
    for (final grade in track.grades) {
      if ('${track.id}_${grade.id}' != paused.gradeKey) continue;
      final byId = {for (final q in grade.questions) q.id: q};
      final questions = paused.questionIds
          .map((id) => byId[id])
          .whereType<Question>()
          .toList();
      if (questions.length != paused.questionIds.length) return null;
      final previous = <AnsweredQuestion>[];
      for (final d in paused.answeredData) {
        final q = byId[d.id];
        if (q == null) return null;
        previous.add(
          AnsweredQuestion(
            question: q,
            selected: d.selected.toSet(),
            outcome: AnswerOutcome.values.byName(d.outcome),
          ),
        );
      }
      return (
        track: track,
        grade: grade,
        questions: questions,
        startIndex: paused.currentIndex,
        previousAnswers: previous,
      );
    }
  }
  return null;
}

/// Свежий старт: первый грейд (по order) с непройденными вопросами темы.
/// Возвращает true, если сессия открыта.
bool _startFreshTopic(
  BuildContext context,
  List<Track> tracks,
  ProgressService progress,
  String topicTitle,
) {
  final sortedTracks = [...tracks]..sort((a, b) => a.order.compareTo(b.order));
  for (final track in sortedTracks) {
    final grades = [...track.grades]
      ..sort((a, b) => a.order.compareTo(b.order));
    for (final grade in grades) {
      final mastered = progress.masteredIds(track.id, grade.id);
      final questions = grade.questions
          .where((q) => q.topic == topicTitle && !mastered.contains(q.id))
          .toList();
      if (questions.isEmpty) continue;
      unawaited(
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => SessionScreen(
              track: track,
              grade: grade,
              questions: questions,
              progress: progress,
              topicTitle: topicTitle,
            ),
          ),
        ),
      );
      return true;
    }
  }
  return false;
}

Future<String?> _showTopicResumeDialog(
  BuildContext context,
  IncompleteSession paused,
) {
  final answered = paused.answeredData.length;
  final total = paused.questionIds.length;
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      title: const Text('Незавершённая тема'),
      content: Text('Вы остановились на вопросе ${answered + 1} из $total.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop('restart'),
          child: const Text('Начать заново'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop('continue'),
          child: const Text('Продолжить'),
        ),
      ],
    ),
  );
}

/// Сбросить прогресс темы [topicTitle]: вернуть в пул все её вопросы по всему
/// каталогу и очистить её паузу. История точности (_topicStats) намеренно не
/// трогается — это правда о том, как пользователь отвечал, и она кормит блок
/// слабых тем.
Future<void> resetTopic(
  List<Track> tracks,
  ProgressService progress,
  String topicTitle,
) async {
  final idsByGradeKey = <String, Set<String>>{};
  for (final track in tracks) {
    for (final grade in track.grades) {
      for (final q in grade.questions) {
        if (q.topic != topicTitle) continue;
        (idsByGradeKey['${track.id}_${grade.id}'] ??= <String>{}).add(q.id);
      }
    }
  }
  await progress.resetMastered(idsByGradeKey);
  await progress.clearIncompleteTopicSession(topicTitle: topicTitle);
}
