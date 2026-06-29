import 'package:flutter_test/flutter_test.dart';
import 'package:interview_helper_system/controllers/session_controller.dart';
import 'package:interview_helper_system/models/models.dart';
import 'package:interview_helper_system/screens/progress_metrics.dart';
import 'package:interview_helper_system/services/progress_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Question q(String id) => Question(
        id: id,
        text: 'Q $id',
        options: const ['A', 'B'],
        correctIndexes: const [0],
      );

  AnsweredQuestion answered(Question question, AnswerOutcome outcome) =>
      AnsweredQuestion(question: question, selected: const {0}, outcome: outcome);

  SessionResult resWithAnswers(List<AnsweredQuestion> answers) {
    final correctIds = answers
        .where((a) => a.outcome == AnswerOutcome.correct)
        .map((a) => a.question.id)
        .toSet();
    return SessionResult(
      correct: correctIds.length,
      partial: 0,
      wrong: answers.length - correctIds.length,
      points: correctIds.length,
      maxPoints: answers.length,
      answers: answers,
      correctIds: correctIds,
    );
  }

  Future<ProgressService> freshService({DateTime Function()? clock}) async {
    SharedPreferences.setMockInitialValues({});
    final p = ProgressService(clock: clock);
    await p.init();
    return p;
  }

  group('ProgressService — dailyAccuracyLog', () {
    test('пуст после инициализации на чистом хранилище', () async {
      final p = await freshService();
      expect(p.dailyAccuracyLog, isEmpty);
    });

    test('отсутствующий ключ читается как пустой лог (обратная совместимость)',
        () async {
      SharedPreferences.setMockInitialValues({'xp': 10});
      final p = ProgressService();
      await p.init();
      expect(p.dailyAccuracyLog, isEmpty);
    });

    test('повреждённый JSON не роняет init, возвращает пустой лог', () async {
      SharedPreferences.setMockInitialValues(
        {'daily_accuracy_log': '{bad json['},
      );
      final p = ProgressService();
      await p.init();
      expect(p.dailyAccuracyLog, isEmpty);
    });

    test('одна сессия создаёт запись за текущий день', () async {
      final day = DateTime(2026, 6, 29);
      final p = await freshService(clock: () => day);
      await p.recordSession(
        't1',
        resWithAnswers([
          answered(q('q1'), AnswerOutcome.correct),
          answered(q('q2'), AnswerOutcome.wrong),
        ]),
      );

      final log = p.dailyAccuracyLog;
      expect(log, contains('2026-06-29'));
      expect(log['2026-06-29']!.answers, 2);
      expect(log['2026-06-29']!.correct, 1);
    });

    test('две сессии в один день объединяются в одну запись', () async {
      final day = DateTime(2026, 6, 29);
      final p = await freshService(clock: () => day);

      await p.recordSession(
        't1',
        resWithAnswers([
          answered(q('q1'), AnswerOutcome.correct),
          answered(q('q2'), AnswerOutcome.wrong),
        ]),
      );
      await p.recordSession(
        't2',
        resWithAnswers([
          answered(q('q3'), AnswerOutcome.correct),
          answered(q('q4'), AnswerOutcome.correct),
          answered(q('q5'), AnswerOutcome.wrong),
        ]),
      );

      final log = p.dailyAccuracyLog;
      expect(log.length, 1);
      expect(log['2026-06-29']!.answers, 5);
      expect(log['2026-06-29']!.correct, 3);
    });

    test('сессии в разные дни хранятся отдельно', () async {
      var day = DateTime(2026, 6, 28);
      final p = await freshService(clock: () => day);

      await p.recordSession(
        't1',
        resWithAnswers([answered(q('q1'), AnswerOutcome.correct)]),
      );
      day = DateTime(2026, 6, 29);
      await p.recordSession(
        't1',
        resWithAnswers([
          answered(q('q2'), AnswerOutcome.wrong),
          answered(q('q3'), AnswerOutcome.wrong),
        ]),
      );

      final log = p.dailyAccuracyLog;
      expect(log.length, 2);
      expect(log['2026-06-28']!.answers, 1);
      expect(log['2026-06-29']!.answers, 2);
    });

    test('лог переживает пересоздание сервиса (persist)', () async {
      final day = DateTime(2026, 6, 29);
      SharedPreferences.setMockInitialValues({});
      final p1 = ProgressService(clock: () => day);
      await p1.init();
      await p1.recordSession(
        't1',
        resWithAnswers([
          answered(q('q1'), AnswerOutcome.correct),
          answered(q('q2'), AnswerOutcome.wrong),
        ]),
      );

      final p2 = ProgressService(clock: () => day);
      await p2.init();
      final log = p2.dailyAccuracyLog;
      expect(log, contains('2026-06-29'));
      expect(log['2026-06-29']!.answers, 2);
      expect(log['2026-06-29']!.correct, 1);
    });

    test('resetAll очищает лог', () async {
      final day = DateTime(2026, 6, 29);
      final p = await freshService(clock: () => day);
      await p.recordSession(
        't1',
        resWithAnswers([answered(q('q1'), AnswerOutcome.correct)]),
      );
      await p.resetAll();
      expect(p.dailyAccuracyLog, isEmpty);
    });
  });

  group('accuracyDelta', () {
    test('возвращает null для пустого лога', () {
      expect(accuracyDelta({}), isNull);
    });

    test('возвращает null при одной точке', () {
      expect(
        accuracyDelta({'2026-06-01': (answers: 4, correct: 2)}),
        isNull,
      );
    });

    test('корректно считает положительную дельту', () {
      final log = {
        '2026-06-01': (answers: 4, correct: 2), // 50%
        '2026-06-10': (answers: 4, correct: 3), // 75%
      };
      expect(accuracyDelta(log), closeTo(0.25, 0.001));
    });

    test('корректно считает отрицательную дельту', () {
      final log = {
        '2026-06-01': (answers: 4, correct: 4), // 100%
        '2026-06-10': (answers: 4, correct: 1), // 25%
      };
      expect(accuracyDelta(log), closeTo(-0.75, 0.001));
    });

    test('нулевая дельта возвращает 0', () {
      final log = {
        '2026-06-01': (answers: 4, correct: 2),
        '2026-06-10': (answers: 2, correct: 1),
      };
      expect(accuracyDelta(log), closeTo(0.0, 0.001));
    });

    test('дельта считается между крайними точками (первая и последняя)', () {
      final log = {
        '2026-06-01': (answers: 2, correct: 1),   // 50%
        '2026-06-15': (answers: 2, correct: 0),   // 0%
        '2026-06-30': (answers: 4, correct: 4),   // 100%
      };
      // last(100%) - first(50%) = +50%
      expect(accuracyDelta(log), closeTo(0.5, 0.001));
    });
  });
}
