import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/models.dart';

/// Загружает банк вопросов из локального JSON-файла
/// Сейчас читает локальный JSON, позже можно подтянуть сервер
abstract class QuestionRepository {
  Future<List<Topic>> loadTopics();
}

class JsonQuestionRepository implements QuestionRepository {
  @override
  Future<List<Topic>> loadTopics() async {
    final raw = await rootBundle.loadString('assets/data/questions.json');
    final data = json.decode(raw) as Map<String, dynamic>;
    final topics = (data['topics'] as List)
        .map((e) => Topic.fromJson(e as Map<String, dynamic>))
        .toList();
    return topics;
  }
}
