import 'package:flutter_test/flutter_test.dart';
import 'package:interview_helper_system/controllers/session_controller.dart';
import 'package:interview_helper_system/models/models.dart';

Question single(String id) => Question(
    id: id, text: 'Q', options: ['А', 'Б', 'В'], correctIndexes: const [0],);

Question multi(String id) => Question(
    id: id,
    text: 'Q',
    options: ['А', 'Б', 'В', 'Г'],
    correctIndexes: const [0, 2],);

void main() {
  // ─── toggle в запрещённых состояниях ───────────────────────────────────────
  group('toggle — попытки изменить выбор после фиксации', () {
    test('toggle после submit игнорируется — selected не меняется', () {
      final c = SessionController([single('q')]);
      c.toggle(0); // верный
      c.submit();
      c.toggle(1); // попытка изменить
      c.toggle(2);
      expect(c.selected, {0}); // выбор зафиксирован
      expect(c.answered, isTrue);
    });

    test('toggle неверного + toggle правильного = всё равно wrong в single', () {
      final c = SessionController([single('q')]);
      c.toggle(1); // неверный
      c.toggle(2); // single: заменяет, не накапливает
      expect(c.selected, {2}); // только последний
      c.submit();
      expect(c.result.wrong, 1);
    });

    test('multi-toggle одной опции чётное число раз = не выбрана', () {
      final c = SessionController([multi('q')]);
      c.toggle(0); c.toggle(0); c.toggle(0); c.toggle(0); // 4 раза
      expect(c.selected, isEmpty);
      c.submit(); // пустой → guard должен отклонить
      expect(c.answered, isFalse);
    });

    test('multi-toggle одной опции нечётное число раз = выбрана', () {
      final c = SessionController([multi('q')]);
      for (var i = 0; i < 7; i++) { c.toggle(0); }
      expect(c.selected, {0});
    });
  });

  // ─── submit в запрещённых состояниях ───────────────────────────────────────
  group('submit — повторные вызовы и пустое состояние', () {
    test('10 submit подряд = один ответ в history', () {
      final c = SessionController([single('q')]);
      c.toggle(0);
      for (var i = 0; i < 10; i++) { c.submit(); }
      expect(c.result.answers.length, 1);
      expect(c.result.points, 1);
    });

    test('submit без выбора не меняет состояние', () {
      final c = SessionController([multi('q')]);
      c.submit();
      expect(c.answered, isFalse);
      expect(c.result.maxPoints, 0);
    });

    test('submit после неверного: wrong фиксируется, correctIds пуст', () {
      final c = SessionController([single('q')]);
      c.toggle(1); // неверный
      c.submit();
      expect(c.result.wrong, 1);
      expect(c.result.correctIds, isEmpty);
    });
  });

  // ─── next в запрещённых состояниях ─────────────────────────────────────────
  group('next — нельзя перейти без ответа или за последний вопрос', () {
    test('10 вызовов next без ответа — остаёмся на первом', () {
      final c = SessionController([single('q1'), single('q2')]);
      for (var i = 0; i < 10; i++) { c.next(); }
      expect(c.index, 0);
    });

    test('next после last → false, index не выходит за границу', () {
      final c = SessionController([single('q')]);
      c.toggle(0); c.submit();
      for (var i = 0; i < 5; i++) { expect(c.next(), isFalse); }
      expect(c.index, 0);
    });

    test('быстрый next→next после submit — второй next игнорируется', () {
      final c = SessionController([single('q1'), single('q2'), single('q3')]);
      c.toggle(0); c.submit();
      c.next(); // переходим на q2
      c.next(); // q2 не отвечен → игнор
      expect(c.index, 1);
    });
  });

  // ─── result — идемпотентность и инварианты ─────────────────────────────────
  group('result — идемпотентность и консистентность', () {
    test('result.getter вызванный несколько раз возвращает одинаковые данные', () {
      final c = SessionController([single('q1'), multi('q2')]);
      c.toggle(0); c.submit(); c.next();
      c.toggle(0); c.toggle(2); c.submit();

      final r1 = c.result;
      final r2 = c.result;
      expect(r1.correct, r2.correct);
      expect(r1.wrong, r2.wrong);
      expect(r1.points, r2.points);
      expect(r1.correctIds, r2.correctIds);
    });

    test('result.correct + partial + wrong = total ответов в sessions', () {
      final c = SessionController([single('q1'), multi('q2'), single('q3')]);
      c.toggle(0); c.submit(); c.next(); // correct
      c.toggle(1); c.submit(); c.next(); // wrong (1 — неверный для multi)
      c.toggle(1); c.submit();           // wrong

      final r = c.result;
      expect(r.correct + r.partial + r.wrong, r.answers.length);
    });

    test('correctIds содержит только ID с outcome==correct', () {
      final c = SessionController([single('q1'), single('q2'), single('q3')]);
      c.toggle(0); c.submit(); c.next(); // q1 верно
      c.toggle(1); c.submit(); c.next(); // q2 неверно
      c.toggle(0); c.submit();           // q3 верно

      final r = c.result;
      expect(r.correctIds, containsAll(['q1', 'q3']));
      expect(r.correctIds, isNot(contains('q2')));
    });

    test('maxPoints == сумма correctIndexes.length по всем вопросам', () {
      // single: 1 балл, multi: 2 балла
      final c = SessionController([single('a'), multi('b')]);
      c.toggle(0); c.submit(); c.next();
      c.toggle(0); c.toggle(2); c.submit();
      expect(c.result.maxPoints, 3); // 1 + 2
    });

    test('points никогда не превышает maxPoints', () {
      final c = SessionController([multi('q')]);
      c.toggle(0); c.toggle(2); c.toggle(1); // 2 верных + 1 лишний
      c.submit();
      expect(c.result.points, lessThanOrEqualTo(c.result.maxPoints));
    });

    test('result.answers неизменяем — попытка записи бросает ошибку', () {
      final c = SessionController([single('q')]);
      c.toggle(0); c.submit();
      expect(
        () => c.result.answers.add(c.result.answers.first),
        throwsUnsupportedError,
      );
    });
  });

  // ─── SessionController.resume() ────────────────────────────────────────────
  group('SessionController.resume() — восстановление состояния', () {
    test('resume с пустым состоянием эквивалентен обычному конструктору', () {
      final questions = [single('q1'), single('q2')];
      final c = SessionController.resume(
        questions: questions,
        startIndex: 0,
        previousAnswers: [],
      );
      expect(c.index, 0);
      expect(c.answers, isEmpty);
      expect(c.result.correct, 0);
    });

    test('resume восстанавливает накопленные счётчики', () {
      final prev = [
        AnsweredQuestion(
            question: single('q1'), selected: {0}, outcome: AnswerOutcome.correct,),
        AnsweredQuestion(
            question: single('q2'), selected: {1}, outcome: AnswerOutcome.wrong,),
      ];
      final c = SessionController.resume(
        questions: [single('q1'), single('q2'), single('q3')],
        startIndex: 2,
        previousAnswers: prev,
      );
      expect(c.index, 2);
      expect(c.result.correct, 1);
      expect(c.result.wrong, 1);
    });

    test('ответы после resume накапливаются поверх восстановленных', () {
      final prev = [
        AnsweredQuestion(
            question: single('q1'), selected: {0}, outcome: AnswerOutcome.correct,),
      ];
      final c = SessionController.resume(
        questions: [single('q1'), single('q2')],
        startIndex: 1,
        previousAnswers: prev,
      );
      c.toggle(0); c.submit(); // q2 верно
      expect(c.result.correct, 2);
      expect(c.result.correctIds, containsAll(['q1', 'q2']));
    });

    test('resume корректно восстанавливает points и maxPoints', () {
      const q2 = Question(
          id: 'q2', text: 'T', options: ['А', 'Б', 'В'], correctIndexes: [0, 1],);
      final prev = [
        const AnsweredQuestion(
            question: q2, selected: {0, 1}, outcome: AnswerOutcome.correct,),
      ];
      final c = SessionController.resume(
        questions: [q2, single('q3')],
        startIndex: 1,
        previousAnswers: prev,
      );
      // q2 дал hit=2, maxPoints=2
      expect(c.result.points, 2);
      expect(c.result.maxPoints, 2);
    });

    test('resume с out-of-range startIndex — обращение к current бросает RangeError', () {
      // Документирует поведение при повреждённых данных из prefs.
      // В штатном коде grades_screen/session_screen этот кейс не возникает,
      // но прямое API-использование должно поднимать понятную ошибку.
      final c = SessionController.resume(
        questions: [single('q1')],
        startIndex: 99, // вне диапазона
        previousAnswers: [],
      );
      expect(
        () => c.current,
        throwsA(isA<RangeError>()),
      );
    });

    test('resume: partial answer восстанавливает правильный hit для points', () {
      const q = Question(
          id: 'q1',
          text: 'T',
          options: ['А', 'Б', 'В'],
          correctIndexes: [0, 1],);
      final prev = [
        // partial: выбрал только [0] из [0,1], hit=1
        const AnsweredQuestion(
            question: q, selected: {0}, outcome: AnswerOutcome.partial,),
      ];
      final c = SessionController.resume(
        questions: [q, single('q2')],
        startIndex: 1,
        previousAnswers: prev,
      );
      expect(c.result.points, 1);   // hit=1
      expect(c.result.maxPoints, 2); // 2 верных варианта
      expect(c.result.partial, 1);
    });
  });

  // ─── 0 вопросов — assert ───────────────────────────────────────────────────
  group('конструктор — нарушение инварианта непустого списка', () {
    test('пустой список вопросов → assert выбрасывает AssertionError', () {
      expect(
        () => SessionController([]),
        throwsA(isA<AssertionError>()),
      );
    });

    test('resume с пустым списком вопросов → assert выбрасывает AssertionError', () {
      expect(
        () => SessionController.resume(
          questions: [],
          startIndex: 0,
          previousAnswers: [],
        ),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  // ─── 1 вопрос — граничный случай ─────────────────────────────────────────
  group('ровно один вопрос — полный жизненный цикл', () {
    test('1 вопрос: toggle → submit → next() = false → result корректен', () {
      final c = SessionController([single('q')]);
      expect(c.isLast, isTrue);
      expect(c.total, 1);

      c.toggle(0);
      c.submit();
      expect(c.answered, isTrue);

      // next() на последнем возвращает false и не двигает индекс
      expect(c.next(), isFalse);
      expect(c.index, 0);

      final r = c.result;
      expect(r.correct, 1);
      expect(r.wrong, 0);
      expect(r.answers.length, 1);
    });

    test('1 вопрос неверный: wrong = 1, correct = 0, points = 0', () {
      final c = SessionController([single('q')]);
      c.toggle(1); // неверный вариант
      c.submit();
      final r = c.result;
      expect(r.wrong, 1);
      expect(r.correct, 0);
      expect(r.points, 0);
      expect(r.maxPoints, 1);
    });
  });

  // ─── пустой correctIndexes в вопросе ─────────────────────────────────────
  group('вопрос с пустым correctIndexes — submit всегда wrong', () {
    test('empty correctIndexes → любой выбор = wrong, points не начисляются', () {
      // В штатной работе такой вопрос отсеивает isValid в репозитории.
      // Тест документирует поведение контроллера при обходе этой проверки.
      const q = Question(
        id: 'q',
        text: 'T',
        options: ['А', 'Б'],
        correctIndexes: [],
      );
      final c = SessionController([q]);
      c.toggle(0);
      c.submit();
      expect(c.result.wrong, 1);
      expect(c.result.correct, 0);
      expect(c.result.points, 0);
      expect(c.result.maxPoints, 0); // total = correctSet.length = 0
    });
  });

  // ─── toggle с выходящим за диапазон индексом ──────────────────────────────
  group('toggle — индекс вне диапазона options', () {
    test('toggle(999) на 3-вариантном вопросе → нет краша, ответ wrong', () {
      final c = SessionController([single('q')]); // correctIndexes = [0]
      c.toggle(999); // 999 не совпадает ни с одним верным вариантом
      expect(c.submit, returnsNormally);
      expect(c.result.wrong, 1);
      expect(c.result.correct, 0);
    });
  });
}
