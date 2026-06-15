import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/models.dart';

/// Источник банка вопросов
/// Реализация читает локальный JSON; позже рядом появится серверная
abstract class QuestionRepository {
  Future<List<Topic>> loadTopics();
}

class JsonQuestionRepository implements QuestionRepository {
  @override
  Future<List<Topic>> loadTopics() async {
    final raw = await rootBundle.loadString('assets/data/questions.json');
    return parseTopics(raw);            // I/O отдельно
  }

  @visibleForTesting
  List<Topic> parseTopics(String raw) { // чистая логика - тестируется строками
    final decoded = json.decode(raw);
    if (decoded is! Map<String, dynamic> || decoded['topics'] is! List) {
      throw const FormatException('Ожидался объект с ключом topics');
    }
    final topics = <Topic>[];
    for (final rawTopic in decoded['topics'] as List) {
      final topic = _parseTopic(rawTopic);
      if (topic != null && topic.questions.isNotEmpty) topics.add(topic);
    }
    return topics;
  }

  /// Разбирает тему. Возвращает null, если тема структурно битая.
  /// Невалидные вопросы внутри темы отсеиваются, валидные остаются.
  Topic? _parseTopic(dynamic raw) {
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

      return Topic(
        id: raw['id'] as String,
        title: raw['title'] as String,
        questions: questions,
      );
    } catch (e) {
      // Тема без id/title или с битой структурой — пропускаем целиком
      debugPrint('Пропущена битая тема: $e');
      return null;
    }
  }

  /// Разбирает и проверяет вопрос. Возвращает null, если он битый или невалидный
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
      // Битый тип поля, отсутствующий ключ и т.п.
      debugPrint('Пропущен битый вопрос: $e');
      return null;
    }
  }
}
