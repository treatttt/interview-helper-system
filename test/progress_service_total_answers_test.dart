import 'package:flutter_test/flutter_test.dart';
import 'package:interview_helper_system/controllers/session_controller.dart';
import 'package:interview_helper_system/models/models.dart';
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

  Future<ProgressService> freshService() async {
    SharedPreferences.setMockInitialValues({});
    final p = ProgressService();
    await p.init();
    return p;
  }

  group('ProgressService — totalAnswers', () {
    test('начальное значение равно 0', () async {
      final p = await freshService();
      expect(p.totalAnswers, 0);
    });

    test('отсутствующий ключ в хранилище читается как 0 (обратная совместимость)',
        () async {
      SharedPreferences.setMockInitialValues({'xp': 50, 'streak': 3});
      final p = ProgressService();
      await p.init();
      expect(p.totalAnswers, 0);
    });

    test('recordSession инкрементирует на answers.length', () async {
      final p = await freshService();
      final r = resWithAnswers([
        answered(q('q1'), AnswerOutcome.correct),
        answered(q('q2'), AnswerOutcome.wrong),
        answered(q('q3'), AnswerOutcome.correct),
      ]);
      await p.recordSession('t1', r);
      expect(p.totalAnswers, 3);
    });

    test('recordMixedSession тоже инкрементирует', () async {
      final p = await freshService();
      final r = resWithAnswers([
        answered(q('q1'), AnswerOutcome.correct),
        answered(q('q2'), AnswerOutcome.wrong),
      ]);
      await p.recordMixedSession(r, {'q1': 't1_j'});
      expect(p.totalAnswers, 2);
    });

    test('счётчик накапливается по всем сессиям', () async {
      final p = await freshService();
      await p.recordSession(
        't1',
        resWithAnswers([
          answered(q('q1'), AnswerOutcome.correct),
          answered(q('q2'), AnswerOutcome.correct),
        ]),
      );
      await p.recordSession(
        't2',
        resWithAnswers([
          answered(q('q3'), AnswerOutcome.wrong),
        ]),
      );
      expect(p.totalAnswers, 3);
    });

    test('totalAnswers переживает пересоздание сервиса (persist)', () async {
      SharedPreferences.setMockInitialValues({});
      final p1 = ProgressService();
      await p1.init();
      await p1.recordSession(
        't1',
        resWithAnswers([
          answered(q('q1'), AnswerOutcome.correct),
          answered(q('q2'), AnswerOutcome.wrong),
        ]),
      );
      expect(p1.totalAnswers, 2);

      final p2 = ProgressService();
      await p2.init();
      expect(p2.totalAnswers, 2);
    });

    test('resetAll сбрасывает totalAnswers в 0', () async {
      final p = await freshService();
      await p.recordSession(
        't1',
        resWithAnswers([answered(q('q1'), AnswerOutcome.correct)]),
      );
      await p.resetAll();
      expect(p.totalAnswers, 0);
    });

    test('после resetAll totalAnswers переживает перезапуск как 0', () async {
      SharedPreferences.setMockInitialValues({});
      final p1 = ProgressService();
      await p1.init();
      await p1.recordSession(
        't1',
        resWithAnswers([answered(q('q1'), AnswerOutcome.correct)]),
      );
      await p1.resetAll();

      final p2 = ProgressService();
      await p2.init();
      expect(p2.totalAnswers, 0);
    });

    test('сессия с пустым answers.length не меняет счётчик', () async {
      final p = await freshService();
      const empty = SessionResult(
        correct: 0,
        partial: 0,
        wrong: 0,
        points: 0,
        maxPoints: 0,
        answers: [],
      );
      await p.recordSession('t1', empty);
      expect(p.totalAnswers, 0);
    });
  });
}
