import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:interview_helper_system/models/models.dart';

/// Источник банка вопросов.
/// Реализация читает локальный JSON; позже рядом появится серверная.
abstract class QuestionRepository {
  Future<List<Track>> loadTracks();
}

/// Агрегирует вопросы из всех треков и грейдов по теме (Question.topic).
/// Вопросы с topic == null или пустой строкой не включаются.
/// Результат отсортирован по алфавиту; пустые группы не возникают.
List<TopicGroup> aggregateTopics(List<Track> tracks) {
  final grouped = <String, List<QuestionOrigin>>{};
  for (final track in tracks) {
    for (final grade in track.grades) {
      for (final question in grade.questions) {
        final topic = question.topic;
        if (topic == null || topic.isEmpty) continue;
        (grouped[topic] ??= []).add(
          QuestionOrigin(track: track, grade: grade, question: question),
        );
      }
    }
  }
  return grouped.entries
      .where((e) => e.value.isNotEmpty)
      .map((e) => TopicGroup(title: e.key, questions: List.unmodifiable(e.value)))
      .toList()
    ..sort((a, b) => a.title.compareTo(b.title));
}

class JsonQuestionRepository implements QuestionRepository {
  @override
  Future<List<Track>> loadTracks() async {
    final raw = await rootBundle.loadString('assets/data/questions.json');
    return parseTracks(raw);
  }

  @visibleForTesting
  List<Track> parseTracks(String raw) {
    final decoded = json.decode(raw);
    if (decoded is! Map<String, dynamic> || decoded['tracks'] is! List) {
      throw const FormatException('Ожидался объект с ключом tracks');
    }
    final tracks = <Track>[];
    for (final rawTrack in decoded['tracks'] as List) {
      final track = _parseTrack(rawTrack);
      if (track != null) tracks.add(track);
    }
    return tracks;
  }

  /// Разбирает направление. Невалидные вопросы внутри грейдов отсеиваются.
  Track? _parseTrack(dynamic raw) {
    try {
      if (raw is! Map<String, dynamic>) return null;

      final grades = <Grade>[];
      final rawGrades = raw['grades'];
      if (rawGrades is List) {
        for (final rawG in rawGrades) {
          final g = _parseGrade(rawG);
          if (g != null) grades.add(g);
        }
      }

      return Track(
        id: raw['id'] as String,
        title: raw['title'] as String,
        description: raw['description'] as String?,
        order: (raw['order'] as int?) ?? 0,
        grades: grades,
      );
    } catch (e) {
      debugPrint('Пропущено битое направление: $e');
      return null;
    }
  }

  /// Разбирает грейд. Невалидные вопросы отсеиваются, грейд остаётся.
  Grade? _parseGrade(dynamic raw) {
    try {
      if (raw is! Map<String, dynamic>) return null;

      final questions = <Question>[];
      final rawQuestions = raw['questions'];
      if (rawQuestions is List) {
        for (final rawQ in rawQuestions) {
          final q = _parseQuestion(rawQ);
          if (q != null) questions.add(q);
        }
      }

      return Grade(
        id: raw['id'] as String,
        title: raw['title'] as String,
        description: raw['description'] as String?,
        order: (raw['order'] as int?) ?? 0,
        questions: questions,
      );
    } catch (e) {
      debugPrint('Пропущен битый грейд: $e');
      return null;
    }
  }

  /// Разбирает и проверяет вопрос. Возвращает null, если он битый или невалидный.
  Question? _parseQuestion(dynamic raw) {
    try {
      if (raw is! Map<String, dynamic>) return null;
      final q = Question.fromJson(raw);
      if (!q.isValid) {
        debugPrint('Пропущен невалидный вопрос: ${raw['id']}');
        return null;
      }
      return q;
    } catch (e) {
      debugPrint('Пропущен битый вопрос: $e');
      return null;
    }
  }
}
