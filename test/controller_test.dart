import 'package:flutter_test/flutter_test.dart';
import 'package:interview_helper_system/models/models.dart';
import 'package:interview_helper_system/controllers/session_controller.dart';

void main() {
  // Хелперы вопросов.
  Question single() => const Question(
      id: 's', text: 'Один верный?', options: ['A', 'B', 'C'],
      correctIndexes: [1]);
  Question multi() => const Question(
      id: 'm', text: 'Несколько верных?', options: ['A', 'B', 'C', 'D'],
      correctIndexes: [0, 2]);

  group('submit — идемпотентность (опора фикса двойного тапа)', () {
    test('повторный submit не пересчитывает баллы и не дублирует ответ', () {
      final c = SessionController([single()]);
      c.toggle(1); // верный
      c.submit();
      final pointsAfterFirst = c.result.points;
      final answersAfterFirst = c.result.answers.length;

      c.submit(); // второй раз — должен быть игнор (_answered уже true)
      c.submit(); // и третий

      expect(c.result.points, pointsAfterFirst); // баллы не выросли
      expect(c.result.answers.length, answersAfterFirst); // ответ не задвоился
      expect(c.result.answers.length, 1);
    });

    test('submit без выбора ничего не фиксирует', () {
      final c = SessionController([single()]);
      c.submit(); // _selected пуст → ранний выход
      expect(c.answered, isFalse);
      expect(c.result.answers, isEmpty);
      expect(c.result.maxPoints, 0); // даже maxPoints не должен накрутиться
    });
  });

  group('next — нельзя листать без ответа и за конец', () {
    test('next без ответа не двигает индекс и возвращает true', () {
      final c = SessionController([single(), multi()]);
      final moved = c.next(); // не отвечали
      expect(moved, isTrue); // true = «ещё рано, остаёмся»
      expect(c.index, 0); // индекс не сдвинулся
    });

    test('двойной next после ответа не проскакивает вопрос', () {
      final c = SessionController([single(), multi()]);
      c.toggle(1);
      c.submit();
      c.next(); // перешли на вопрос 1, _answered сброшен в false
      c.next(); // второй next: !_answered → возврат true, индекс НЕ растёт
      expect(c.index, 1); // не проскочили на несуществующий 2
    });

    test('next на последнем возвращает false и не трогает состояние', () {
      final c = SessionController([single()]);
      c.toggle(1);
      c.submit();
      expect(c.next(), isFalse); // конец
      expect(c.index, 0); // индекс не вышел за границы
    });
  });

  group('submit — корректность вердикта по четырём состояниям multi-select', () {
    test('все верные и только верные → correct', () {
      final c = SessionController([multi()]); // верные [0,2]
      c..toggle(0)..toggle(2);
      c.submit();
      expect(c.result.correct, 1);
      expect(c.result.answers.single.outcome, AnswerOutcome.correct);
      expect(c.result.points, 2); // hit=2
      expect(c.result.maxPoints, 2);
    });

    test('часть верных, без лишних → partial', () {
      final c = SessionController([multi()]); // верные [0,2]
      c.toggle(0); // только один из двух
      c.submit();
      expect(c.result.partial, 1);
      expect(c.result.answers.single.outcome, AnswerOutcome.partial);
      expect(c.result.points, 1); // hit=1
    });

    test('все верные ПЛЮС лишний → не correct, а partial', () {
      // КЛЮЧЕВОЙ кейс немаркированного multi: выбрал оба верных и один лишний.
      // hit=2=correctSet, НО selected.length=3 != 2 → не correct.
      final c = SessionController([multi()]); // верные [0,2]
      c..toggle(0)..toggle(2)..toggle(1); // 1 — лишний
      c.submit();
      expect(c.result.answers.single.outcome, AnswerOutcome.partial);
      expect(c.result.correct, 0); // именно НЕ зачлось как полностью верно
    });

    test('только неверные → wrong', () {
      final c = SessionController([multi()]); // верные [0,2]
      c.toggle(1); // неверный
      c.submit();
      expect(c.result.wrong, 1);
      expect(c.result.answers.single.outcome, AnswerOutcome.wrong);
      expect(c.result.points, 0);
    });
  });

  group('инкапсуляция и границы', () {
    test('answers в результате не должен быть мутируемой ссылкой на внутренний список',
            () {
          // Атака на утечку инкапсуляции: получили result, попытались дописать.
          // Если result отдаёт живой _answers — внешняя мутация просочится внутрь.
          final c = SessionController([single()]);
          c.toggle(1);
          c.submit();
          final answers = c.result.answers;
          expect(() => answers.add(answers.first), throwsUnsupportedError,
              reason: 'result.answers должен быть неизменяемым для вызывающего');
        });

    test('selected в AnsweredQuestion — копия, не живая ссылка на _selected', () {
      // submit копирует _selected ({..._selected}); проверяем, что переход
      // к следующему вопросу (где _selected.clear()) не стирает сохранённый ответ.
      final c = SessionController([single(), multi()]);
      c.toggle(1);
      c.submit();
      final savedBefore = c.result.answers.first.selected.toList();
      c.next(); // тут _selected.clear()
      final savedAfter = c.result.answers.first.selected.toList();
      expect(savedAfter, savedBefore); // ответ первого вопроса не затёрт
      expect(savedAfter, [1]);
    });
  });
}