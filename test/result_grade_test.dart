import 'package:flutter_test/flutter_test.dart';
import 'package:interview_helper_system/controllers/session_controller.dart';
import 'package:interview_helper_system/models/models.dart';
import 'package:interview_helper_system/utils/result_grade.dart';

var _seq = 0;
AnsweredQuestion _a(String topic, AnswerOutcome outcome) => AnsweredQuestion(
      question: Question(
        id: '$topic-${outcome.name}-${_seq++}',
        text: 'q',
        options: const ['A', 'B'],
        correctIndexes: const [0],
        topic: topic,
      ),
      selected: const {0},
      outcome: outcome,
    );

void main() {
  group('praiseForScore — пороги похвалы', () {
    test('меньше 50% — подготовиться лучше', () {
      expect(praiseForScore(0), 'Тебе нужно подготовиться лучше');
      expect(praiseForScore(49), 'Тебе нужно подготовиться лучше');
    });

    test('[50, 60) — неплохо', () {
      expect(praiseForScore(50), 'Неплохой результат');
      expect(praiseForScore(59), 'Неплохой результат');
    });

    test('[60, 90) — хорошо', () {
      expect(praiseForScore(60), 'Хороший результат');
      expect(praiseForScore(89), 'Хороший результат');
    });

    test('[90, 100] — отлично', () {
      expect(praiseForScore(90), 'Отличный результат');
      expect(praiseForScore(100), 'Отличный результат');
    });
  });

  group('weakTopicsFromAnswers — слабые темы сессии', () {
    test('считает процент по теме и отбирает только темы с ошибками', () {
      final weak = weakTopicsFromAnswers([
        _a('SQL', AnswerOutcome.correct),
        _a('SQL', AnswerOutcome.correct), // SQL = 100% → исключается
        _a('Подзапросы', AnswerOutcome.correct),
        _a('Подзапросы', AnswerOutcome.wrong), // 50%
      ]);

      expect(weak.length, 1);
      expect(weak.first.title, 'Подзапросы');
      expect(weak.first.percent, 50);
    });

    test('сортирует от слабейшей и режет по limit', () {
      final weak = weakTopicsFromAnswers(
        [
          _a('A', AnswerOutcome.wrong), // 0%
          _a('B', AnswerOutcome.correct),
          _a('B', AnswerOutcome.wrong), // 50%
          _a('C', AnswerOutcome.wrong), // 0%
        ],
        limit: 2,
      );

      expect(weak.length, 2);
      expect(weak.first.percent, 0); // слабейшая первой
      expect(weak.map((t) => t.percent), everyElement(lessThan(100)));
    });

    test('вопросы без темы игнорируются', () {
      final weak = weakTopicsFromAnswers([
        const AnsweredQuestion(
          question: Question(
            id: 'x',
            text: 'q',
            options: ['A', 'B'],
            correctIndexes: [0],
          ),
          selected: {1},
          outcome: AnswerOutcome.wrong,
        ),
      ]);
      expect(weak, isEmpty);
    });
  });
}
