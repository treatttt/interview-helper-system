import 'package:flutter_test/flutter_test.dart';
import 'package:interview_helper_system/models/models.dart';
import 'package:interview_helper_system/controllers/session_controller.dart';

// Хелпер: быстро собрать вопрос для теста.
Question q({
  required List<String> options,
  required List<int> correct,
}) =>
    Question(
      id: 't',
      text: 'test',
      options: options,
      correctIndexes: correct,
    );

void main() {
  group('SessionController — одиночный выбор', () {
    test('правильный ответ засчитывается как верный', () {
      final c = SessionController([
        q(options: ['A', 'B'], correct: [0]),
      ]);

      c.toggle(0); // выбрал правильный
      c.submit();

      expect(c.result.correct, 1);
      expect(c.result.wrong, 0);
      expect(c.result.partial, 0);
      expect(c.result.points, 1);
    });

    test('неправильный ответ засчитывается как неверный', () {
      final c = SessionController([
        q(options: ['A', 'B'], correct: [0]),
      ]);

      c.toggle(1); // выбрал неправильный
      c.submit();

      expect(c.result.wrong, 1);
      expect(c.result.correct, 0);
      expect(c.result.points, 0);
    });
  });

  group('SessionController — множественный выбор', () {
    test('все правильные отмечены — верно, баллы за каждый', () {
      final c = SessionController([
        q(options: ['A', 'B', 'C', 'D'], correct: [0, 2]),
      ]);

      c.toggle(0);
      c.toggle(2);
      c.submit();

      expect(c.result.correct, 1);
      expect(c.result.points, 2); // балл за каждый угаданный
    });

    test('угадана часть правильных — частично', () {
      final c = SessionController([
        q(options: ['A', 'B', 'C', 'D'], correct: [0, 2]),
      ]);

      c.toggle(0); // только один из двух
      c.submit();

      expect(c.result.partial, 1);
      expect(c.result.correct, 0);
      expect(c.result.points, 1); // балл за угаданный
    });

    test('одиночный выбор: повторный тап заменяет предыдущий', () {
      final c = SessionController([
        q(options: ['A', 'B'], correct: [0]),
      ]);

      c.toggle(0);
      c.toggle(1); // должен заменить, а не добавить
      expect(c.selected, {1}); // выбран только последний
    });
  });
}