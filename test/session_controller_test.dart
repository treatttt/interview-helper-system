import 'package:flutter_test/flutter_test.dart';
import 'package:interview_helper_system/controllers/session_controller.dart';
import 'package:interview_helper_system/models/models.dart';

// Хелпер сборки вопроса — если твой конструктор Question отличается
// (другие обязательные поля), правишь только здесь, а не в каждом тесте.
Question _q({
  required String id,
  required List<String> options,
  required List<int> correct,
  String? explanation,
}) =>
    Question(
      id: id,
      text: 'Вопрос $id',
      options: options,
      correctIndexes: correct,
      explanation: explanation,
    );

void main() {
  group('SessionController — история ответов', () {
    test('submit пишет один ответ в историю', () {
      final c = SessionController([
        _q(id: 'q1', options: ['A', 'B', 'C'], correct: [0]),
      ]);
      c.toggle(0);
      c.submit();

      expect(c.result.answers.length, 1);
      expect(c.result.answers.first.question.id, 'q1');
      expect(c.result.answers.first.selected, {0});
      expect(c.result.answers.first.outcome, AnswerOutcome.correct);
    });

    test('selected не обнуляется после next() (защита от ссылки вместо копии)',
            () {
          final c = SessionController([
            _q(id: 'q1', options: ['A', 'B'], correct: [0]),
            _q(id: 'q2', options: ['A', 'B'], correct: [1]),
          ]);
          c.toggle(0);
          c.submit();
          c.next(); // тут _selected.clear() — выбор первого вопроса должен уцелеть

          expect(c.result.answers.first.selected, {0},
              reason: 'если в записи лежит ссылка на _selected, тут будет пусто',);
        });

    test('submit без выбора не создаёт запись', () {
      final c = SessionController([
        _q(id: 'q1', options: ['A', 'B'], correct: [0]),
      ]);
      c.submit(); // ничего не выбрано — guard в submit

      expect(c.result.answers, isEmpty);
    });

    test('в истории все отвеченные вопросы и в исходном порядке', () {
      final c = SessionController([
        _q(id: 'a', options: ['x', 'y'], correct: [0]),
        _q(id: 'b', options: ['x', 'y'], correct: [1]),
        _q(id: 'c', options: ['x', 'y'], correct: [0]),
      ]);
      c.toggle(0); c.submit(); c.next();
      c.toggle(1); c.submit(); c.next();
      c.toggle(0); c.submit();

      expect(c.result.answers.length, 3);
      expect(c.result.answers.map((a) => a.question.id).toList(),
          ['a', 'b', 'c'],);
    });
  });

  group('SessionController — категории вердикта', () {
    test('correct / partial / wrong определяются верно', () {
      final c = SessionController([
        _q(id: 'exact', options: ['A', 'B', 'C'], correct: [0, 1]),
        _q(id: 'part', options: ['A', 'B', 'C'], correct: [0, 1]),
        _q(id: 'miss', options: ['A', 'B', 'C'], correct: [0]),
      ]);

      // оба правильных -> correct
      c.toggle(0); c.toggle(1); c.submit(); c.next();
      // только один из двух -> partial
      c.toggle(0); c.submit(); c.next();
      // неверный вариант -> wrong
      c.toggle(1); c.submit();

      expect(c.result.answers.map((a) => a.outcome).toList(), [
        AnswerOutcome.correct,
        AnswerOutcome.partial,
        AnswerOutcome.wrong,
      ]);
    });

    test('все правильные плюс лишний неправильный — это partial', () {
      final c = SessionController([
        _q(id: 'q', options: ['A', 'B', 'C'], correct: [0, 1]),
      ]);
      c.toggle(0); c.toggle(1); c.toggle(2); // 2 — лишний
      c.submit();

      expect(c.result.answers.first.outcome, AnswerOutcome.partial);
    });

    test('счётчики result совпадают с категориями в истории', () {
      final c = SessionController([
        _q(id: 'a', options: ['x', 'y'], correct: [0]), // верно
        _q(id: 'b', options: ['x', 'y'], correct: [1]), // неверно
      ]);
      c.toggle(0); c.submit(); c.next();
      c.toggle(0); c.submit();

      final r = c.result;
      expect(r.correct,
          r.answers.where((a) => a.outcome == AnswerOutcome.correct).length,);
      expect(r.wrong,
          r.answers.where((a) => a.outcome == AnswerOutcome.wrong).length,);
    });
  });
}