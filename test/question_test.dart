import 'package:flutter_test/flutter_test.dart';
import 'package:interview_helper_system/models/models.dart'; // путь под твой пакет

void main() {
  // Хелпер: валидный вопрос, от которого отклоняемся в каждом тесте.
  Question q({
    String id = 'q1',
    String text = 'Вопрос?',
    List<String> options = const ['A', 'B', 'C'],
    List<int> correct = const [0],
    String? explanation,
  }) =>
      Question(
        id: id,
        text: text,
        options: options,
        correctIndexes: correct,
        explanation: explanation,
      );

  group('Question.isValid — попытки протащить невалидный вопрос', () {
    test('пустой текст отклоняется', () {
      expect(q(text: '').isValid, isFalse);
    });

    test('текст из одних пробелов отклоняется (trim)', () {
      expect(q(text: '   ').isValid, isFalse);
    });

    test('один вариант — выбирать не из чего', () {
      expect(q(options: ['A'], correct: [0]).isValid, isFalse);
    });

    test('ноль вариантов', () {
      expect(q(options: [], correct: []).isValid, isFalse);
    });

    test('нет правильного ответа', () {
      expect(q(correct: []).isValid, isFalse);
    });

    test('индекс правильного за верхней границей options', () {
      // options длиной 3 -> валидные индексы 0..2, индекс 3 невалиден
      expect(q(options: ['A', 'B', 'C'], correct: [3]).isValid, isFalse);
    });

    test('индекс правильного ровно на границе длины (off-by-one)', () {
      // длина 3 -> индекс 3 не существует; классический off-by-one
      expect(q(options: ['A', 'B', 'C'], correct: [0, 3]).isValid, isFalse);
    });

    test('отрицательный индекс правильного', () {
      expect(q(correct: [-1]).isValid, isFalse);
    });

    test('один из нескольких correct невалиден — весь вопрос невалиден', () {
      // первый индекс валиден, второй нет: валидатор не должен «пропустить» по первому
      expect(q(options: ['A', 'B'], correct: [0, 99]).isValid, isFalse);
    });

    test('валидный multi-select проходит', () {
      expect(q(options: ['A', 'B', 'C'], correct: [0, 2]).isValid, isTrue);
    });
  });

  group('Question.fromJson — битые и неполные данные', () {
    Map<String, dynamic> raw() => {
      'id': 'q1',
      'text': 'Вопрос?',
      'options': ['A', 'B'],
      'correctIndexes': [0],
      'explanation': 'почему',
    };

    test('explanation отсутствует -> null, не падает', () {
      final m = raw()..remove('explanation');
      final parsed = Question.fromJson(m);
      expect(parsed.explanation, isNull);
    });

    test('отсутствует обязательное поле text -> бросает', () {
      final m = raw()..remove('text');
      expect(() => Question.fromJson(m), throwsA(isA<TypeError>()));
    });

    test('text не строка, а число -> бросает на касте', () {
      final m = raw()..['text'] = 42;
      expect(() => Question.fromJson(m), throwsA(isA<TypeError>()));
    });

    test('correctIndexes содержит строку вместо int -> бросает на cast<int>', () {
      final m = raw()..['correctIndexes'] = ['0'];
      expect(() => Question.fromJson(m), throwsA(anything));
    });

    test('options не список -> бросает', () {
      final m = raw()..['options'] = 'A,B';
      expect(() => Question.fromJson(m), throwsA(anything));
    });

    test('fromJson не проверяет валидность: пропускает семантически битый вопрос',
            () {
          // ВАЖНО: парсинг и валидация — разные стадии. fromJson соберёт объект
          // с correctIndexes=[5] при двух options, не бросив. Отлов — на isValid.
          final m = raw()
            ..['options'] = ['A', 'B']
            ..['correctIndexes'] = [5];
          final parsed = Question.fromJson(m);
          expect(parsed.isValid, isFalse); // парсинг прошёл, валидатор ловит
        });
  });

  group('Question.fromJson — codeSnippet / codeLanguage', () {
    Map<String, dynamic> raw() => {
      'id': 'q1',
      'text': 'Вопрос?',
      'options': ['A', 'B'],
      'correctIndexes': [0],
    };

    test('без codeSnippet и codeLanguage — поля null, вопрос валиден', () {
      final parsed = Question.fromJson(raw());
      expect(parsed.codeSnippet, isNull);
      expect(parsed.codeLanguage, isNull);
      expect(parsed.isValid, isTrue);
    });

    test('с codeSnippet — поле заполнено, вопрос по-прежнему валиден', () {
      final m = raw()..['codeSnippet'] = 'SELECT * FROM users;';
      final parsed = Question.fromJson(m);
      expect(parsed.codeSnippet, 'SELECT * FROM users;');
      expect(parsed.codeLanguage, isNull);
      expect(parsed.isValid, isTrue);
    });

    test('с codeSnippet и codeLanguage — оба поля заполнены', () {
      final m = raw()
        ..['codeSnippet'] = 'int x = 42;'
        ..['codeLanguage'] = 'dart';
      final parsed = Question.fromJson(m);
      expect(parsed.codeSnippet, 'int x = 42;');
      expect(parsed.codeLanguage, 'dart');
    });
  });

  group('Question.fromJson — importantToKnow / mustRepeat (из данных)', () {
    Map<String, dynamic> raw() => {
      'id': 'q1',
      'text': 'Вопрос?',
      'options': ['A', 'B'],
      'correctIndexes': [0],
    };

    test('без полей — оба null, не падает', () {
      final parsed = Question.fromJson(raw());
      expect(parsed.importantToKnow, isNull);
      expect(parsed.mustRepeat, isNull);
    });

    test('списки строк читаются как есть', () {
      final m = raw()
        ..['importantToKnow'] = ['Факт 1', 'Факт 2']
        ..['mustRepeat'] = ['Повтори X'];
      final parsed = Question.fromJson(m);
      expect(parsed.importantToKnow, ['Факт 1', 'Факт 2']);
      expect(parsed.mustRepeat, ['Повтори X']);
    });
  });

  group('Question.fromJson — xpReward (награда за вопрос)', () {
    Map<String, dynamic> raw() => {
      'id': 'q1',
      'text': 'Вопрос?',
      'options': ['A', 'B'],
      'correctIndexes': [0],
    };

    test('без поля — берётся значение по умолчанию', () {
      expect(Question.fromJson(raw()).xpReward, Question.defaultXpReward);
    });

    test('заданное значение читается как есть (сложнее → дороже)', () {
      final parsed = Question.fromJson(raw()..['xpReward'] = 25);
      expect(parsed.xpReward, 25);
    });

    test('лёгкий вопрос может стоить дешевле дефолта', () {
      final parsed = Question.fromJson(raw()..['xpReward'] = 5);
      expect(parsed.xpReward, 5);
    });
  });
}
