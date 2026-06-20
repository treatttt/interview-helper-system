import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:interview_helper_system/models/models.dart';

/// Источник банка вопросов.
/// Реализация читает локальный JSON; позже рядом появится серверная.
abstract class QuestionRepository {
  Future<List<Track>> loadTracks();
}

class JsonQuestionRepository implements QuestionRepository {
  int _discardedCount = 0;

  /// Число элементов, отброшенных в ходе последнего вызова [parseTracks].
  @visibleForTesting
  int get lastDiscardedCount => _discardedCount;

  @override
  Future<List<Track>> loadTracks() async {
    final raw = await rootBundle.loadString('assets/data/questions.json');
    return parseTracks(raw);
  }

  @visibleForTesting
  List<Track> parseTracks(String raw) {
    _discardedCount = 0;
    final decoded = json.decode(raw);
    if (decoded is! Map<String, dynamic> || decoded['tracks'] is! List) {
      throw const FormatException('Ожидался объект с ключом tracks');
    }
    final tracks = <Track>[];
    for (final rawTrack in decoded['tracks'] as List) {
      final track = _parseTrack(rawTrack);
      if (track != null) tracks.add(track);
    }
    if (kDebugMode && _discardedCount > 0) {
      debugPrint(
        'JsonQuestionRepository: отброшено $_discardedCount невалидных '
        'элементов — проверь questions.json',
      );
    }
    return tracks;
  }

  /// Разбирает направление. Невалидные вопросы внутри грейдов отсеиваются.
  Track? _parseTrack(dynamic raw) {
    try {
      if (raw is! Map<String, dynamic>) {
        _discardedCount++;
        return null;
      }

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
      _discardedCount++;
      return null;
    }
  }

  /// Разбирает грейд. Невалидные вопросы отсеиваются, грейд остаётся.
  Grade? _parseGrade(dynamic raw) {
    try {
      if (raw is! Map<String, dynamic>) {
        _discardedCount++;
        return null;
      }

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
      _discardedCount++;
      return null;
    }
  }

  /// Разбирает и проверяет вопрос. Возвращает null, если он битый или невалидный.
  Question? _parseQuestion(dynamic raw) {
    try {
      if (raw is! Map<String, dynamic>) {
        _discardedCount++;
        return null;
      }
      final q = Question.fromJson(raw);
      if (!q.isValid) {
        debugPrint('Пропущен невалидный вопрос: ${raw['id']}');
        _discardedCount++;
        return null;
      }
      return q;
    } catch (e) {
      debugPrint('Пропущен битый вопрос: $e');
      _discardedCount++;
      return null;
    }
  }
}
