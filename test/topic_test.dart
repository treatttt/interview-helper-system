import 'package:flutter_test/flutter_test.dart';
import 'package:interview_helper_system/models/models.dart'; // путь под твой пакет

void main() {
  Map<String, dynamic> rawQuestion() => {
    'id': 'q1',
    'text': 'Вопрос?',
    'options': ['A', 'B'],
    'correctIndexes': [0],
    'explanation': 'почему',
  };

  Map<String, dynamic> rawTopic() => {
    'id': 't1',
    'title': 'Тема',
    'questions': [rawQuestion()],
  };

  group('Topic.fromJson — структура и вложенные битые данные', () {
    test('пустой список вопросов парсится без ошибки', () {
      // Пустая тема не должна ронять парсинг — это легальная (хоть и
      // бесполезная) структура; отсев пустых тем — задача слоя выше.
      final m = rawTopic()..['questions'] = [];
      final t = Topic.fromJson(m);
      expect(t.questions, isEmpty);
    });

    test('отсутствует ключ questions -> бросает, а не молча пустая тема', () {
      // Важно: отсутствие questions — это битый контент, не «ноль вопросов».
      // Парсер не должен подменять отсутствие пустым списком молча.
      final m = rawTopic()..remove('questions');
      expect(() => Topic.fromJson(m), throwsA(anything));
    });

    test('отсутствует title -> бросает', () {
      final m = rawTopic()..remove('title');
      expect(() => Topic.fromJson(m), throwsA(isA<TypeError>()));
    });

    test('questions не список, а объект -> бросает', () {
      final m = rawTopic()..['questions'] = {'q1': rawQuestion()};
      expect(() => Topic.fromJson(m), throwsA(anything));
    });

    test('один битый вопрос в списке роняет парсинг всей темы', () {
      // Вопрос без обязательного text. Тема не должна «проглотить» битый
      // вопрос и вернуться с остальными — fromJson вопроса бросит,
      // и это всплывёт наружу при парсинге темы.
      final badQ = rawQuestion()..remove('text');
      final m = rawTopic()
        ..['questions'] = [rawQuestion(), badQ, rawQuestion()];
      expect(() => Topic.fromJson(m), throwsA(isA<TypeError>()));
    });

    test('валидная тема с несколькими вопросами собирается целиком', () {
      final m = rawTopic()
        ..['questions'] = [rawQuestion(), rawQuestion(), rawQuestion()];
      final t = Topic.fromJson(m);
      expect(t.questions.length, 3);
      expect(t.id, 't1');
    });
  });

  group('Topic — согласованность с валидностью вопросов', () {
    test('тема парсится, даже если внутри семантически невалидный вопрос', () {
      // Парсинг типов прошёл (индексы — int), но вопрос невалиден по isValid
      // (индекс за границей). Граница ответственности: fromJson != валидация.
      final brokenQ = rawQuestion()
        ..['options'] = ['A', 'B']
        ..['correctIndexes'] = [7];
      final m = rawTopic()..['questions'] = [brokenQ];
      final t = Topic.fromJson(m); // не бросает
      expect(t.questions.single.isValid, isFalse); // ловит валидатор
    });
  });
}