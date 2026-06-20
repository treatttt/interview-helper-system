import 'package:flutter_test/flutter_test.dart';
import 'package:interview_helper_system/controllers/session_controller.dart';
import 'package:interview_helper_system/models/models.dart';
import 'package:interview_helper_system/services/progress_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  // Результат сессии с нужным числом верных.
  // correctIds: 'q1'..'qN' — уникальны по позиции, имитируют реальные ID.
  SessionResult res(int correct, {int total = 4}) => SessionResult(
    correct: correct,
    partial: 0,
    wrong: total - correct,
    points: correct,
    maxPoints: total,
    answers: const [],
    correctIds: {for (int i = 0; i < correct; i++) 'q${i + 1}'},
  );

  // Свежий проинициализированный сервис на чистом хранилище.
  Future<ProgressService> freshService() async {
    SharedPreferences.setMockInitialValues({});
    final p = ProgressService();
    await p.init();
    return p;
  }

  group('ProgressService — экономика XP (защита от фарма и регресса)', () {
    test('первое прохождение начисляет XP за все верные', () async {
      final p = await freshService();
      await p.recordSession('t1', res(4));
      expect(p.xp, 40); // 4 верных * 10
      expect(p.topicDone('t1'), 4);
    });

    test('повтор пройденной темы без улучшения НЕ начисляет XP (анти-фарм)',
            () async {
          final p = await freshService();
          await p.recordSession('t1', res(4)); // 40 XP
          await p.recordSession('t1', res(4)); // повтор того же результата
          await p.recordSession('t1', res(4)); // и ещё раз
          expect(p.xp, 40); // не выросло — фарм закрыт
          expect(p.topicDone('t1'), 4);
        });

    test('частичное улучшение начисляет XP только за прирост', () async {
      final p = await freshService();
      await p.recordSession('t1', res(2)); // 0→2: +20
      expect(p.xp, 20);
      await p.recordSession('t1', res(4)); // 2→4: доплата только за 2
      expect(p.xp, 40); // 20 + 20, не 20 + 40
      expect(p.topicDone('t1'), 4);
    });

    test('результат ХУЖЕ прежнего рекорда не отнимает XP и не уводит в минус',
            () async {
          final p = await freshService();
          await p.recordSession('t1', res(4)); // рекорд 4, XP 40
          await p.recordSession('t1', res(1)); // регресс: прошёл хуже
          expect(p.xp, 40); // XP не уменьшился
          expect(p.topicDone('t1'), 4); // рекорд темы не откатился вниз
        });

    test('две разные темы копят XP независимо', () async {
      final p = await freshService();
      await p.recordSession('t1', res(3));
      await p.recordSession('t2', res(2));
      expect(p.xp, 50); // 30 + 20
      expect(p.topicDone('t1'), 3);
      expect(p.topicDone('t2'), 2);
    });

    test('ноль верных не даёт XP и не создаёт ложный рекорд', () async {
      final p = await freshService();
      await p.recordSession('t1', res(0));
      expect(p.xp, 0);
      expect(p.topicDone('t1'), 0);
    });
  });

  group('ProgressService — streak и hasTrainedEver', () {
    test('до первой сессии: streak 0, hasTrainedEver false', () async {
      final p = await freshService();
      expect(p.streak, 0);
      expect(p.hasTrainedEver, isFalse);
    });

    test('первая сессия: streak становится 1, hasTrainedEver true', () async {
      final p = await freshService();
      await p.recordSession('t1', res(2));
      expect(p.streak, 1);
      expect(p.hasTrainedEver, isTrue);
    });

    test('две сессии в один день не увеличивают streak', () async {
      final p = await freshService();
      await p.recordSession('t1', res(2));
      await p.recordSession('t2', res(2)); // тот же день
      expect(p.streak, 1); // не 2 — занятие засчитано один раз за день
    });

    test('persistence: XP и рекорд переживают пересоздание сервиса', () async {
      // setMockInitialValues + init записали в общий мок-стор; новый сервис
      // на том же сторе должен прочитать сохранённое.
      SharedPreferences.setMockInitialValues({});
      final p1 = ProgressService();
      await p1.init();
      await p1.recordSession('t1', res(3)); // 30 XP, рекорд 3

      final p2 = ProgressService(); // не сбрасываем мок-стор
      await p2.init();
      expect(p2.xp, 30);
      expect(p2.topicDone('t1'), 3);
      expect(p2.hasTrainedEver, isTrue);
    });
  });

  // ── Вспомогательные функции для тестов точности по темам ─────────────────

  /// Создаёт Question с заданной темой.
  Question q(String id, {String? topic}) => Question(
        id: id,
        text: 'Q $id',
        options: const ['A', 'B'],
        correctIndexes: const [0],
        topic: topic,
      );

  /// Создаёт AnsweredQuestion с нужным исходом.
  AnsweredQuestion answered(
    Question question,
    AnswerOutcome outcome,
  ) =>
      AnsweredQuestion(
        question: question,
        selected: const {0},
        outcome: outcome,
      );

  /// SessionResult с реальными ответами (для обновления topic stats).
  SessionResult resWithAnswers(List<AnsweredQuestion> answers) {
    final correctIds = answers
        .where((a) => a.outcome == AnswerOutcome.correct)
        .map((a) => a.question.id)
        .toSet();
    return SessionResult(
      correct: correctIds.length,
      partial: answers.where((a) => a.outcome == AnswerOutcome.partial).length,
      wrong: answers.where((a) => a.outcome == AnswerOutcome.wrong).length,
      points: correctIds.length,
      maxPoints: answers.length,
      answers: answers,
      correctIds: correctIds,
    );
  }

  group('ProgressService — точность и слабые темы', () {
    test('overallAccuracy равна 0 при отсутствии попыток', () async {
      final p = await freshService();
      expect(p.overallAccuracy, 0.0);
    });

    test('overallAccuracy корректно вычисляется по ответам', () async {
      final p = await freshService();
      // 2 верных из 4 — точность 0.5
      await p.recordSession(
        't1',
        resWithAnswers([
          answered(q('q1', topic: 'SQL'), AnswerOutcome.correct),
          answered(q('q2', topic: 'SQL'), AnswerOutcome.correct),
          answered(q('q3', topic: 'SQL'), AnswerOutcome.wrong),
          answered(q('q4', topic: 'SQL'), AnswerOutcome.wrong),
        ]),
      );
      expect(p.overallAccuracy, closeTo(0.5, 0.001));
    });

    test('вопросы без темы не попадают в topic stats', () async {
      final p = await freshService();
      await p.recordSession(
        't1',
        resWithAnswers([
          answered(q('q1'), AnswerOutcome.correct), // topic == null
        ]),
      );
      expect(p.weakestTopics(minAttempts: 1), isEmpty);
      expect(p.overallAccuracy, 0.0);
    });

    test('weakestTopics фильтрует темы ниже порога minAttempts', () async {
      final p = await freshService();
      // SQL — 2 попытки (ниже порога 3)
      await p.recordSession(
        't1',
        resWithAnswers([
          answered(q('q1', topic: 'SQL'), AnswerOutcome.wrong),
          answered(q('q2', topic: 'SQL'), AnswerOutcome.wrong),
        ]),
      );
      expect(p.weakestTopics(), isEmpty);
      // Порог 2 — тема появляется.
      expect(p.weakestTopics(minAttempts: 2), hasLength(1));
    });

    test('weakestTopics сортирует по точности по возрастанию', () async {
      final p = await freshService();
      // ООП: 1/3 ≈ 33%
      await p.recordSession(
        't1',
        resWithAnswers([
          answered(q('o1', topic: 'ООП'), AnswerOutcome.correct),
          answered(q('o2', topic: 'ООП'), AnswerOutcome.wrong),
          answered(q('o3', topic: 'ООП'), AnswerOutcome.wrong),
        ]),
      );
      // SQL: 2/3 ≈ 67%
      await p.recordSession(
        't2',
        resWithAnswers([
          answered(q('s1', topic: 'SQL'), AnswerOutcome.correct),
          answered(q('s2', topic: 'SQL'), AnswerOutcome.correct),
          answered(q('s3', topic: 'SQL'), AnswerOutcome.wrong),
        ]),
      );
      final topics = p.weakestTopics();
      expect(topics, hasLength(2));
      expect(topics.first.title, 'ООП'); // слабейшая — первая
      expect(topics.last.title, 'SQL');
    });

    test('weakestTopics возвращает не более limit тем', () async {
      final p = await freshService();
      for (var i = 0; i < 5; i++) {
        await p.recordSession(
          'g$i',
          resWithAnswers([
            answered(q('x${i}a', topic: 'Тема$i'), AnswerOutcome.wrong),
            answered(q('x${i}b', topic: 'Тема$i'), AnswerOutcome.wrong),
            answered(q('x${i}c', topic: 'Тема$i'), AnswerOutcome.wrong),
          ]),
        );
      }
      expect(p.weakestTopics(limit: 2), hasLength(2));
    });

    test('topic stats переживают пересоздание сервиса', () async {
      SharedPreferences.setMockInitialValues({});
      final p1 = ProgressService();
      await p1.init();
      await p1.recordSession(
        't1',
        resWithAnswers([
          answered(q('q1', topic: 'SQL'), AnswerOutcome.correct),
          answered(q('q2', topic: 'SQL'), AnswerOutcome.wrong),
          answered(q('q3', topic: 'SQL'), AnswerOutcome.wrong),
        ]),
      );
      expect(p1.overallAccuracy, closeTo(1 / 3, 0.001));

      final p2 = ProgressService();
      await p2.init();
      expect(p2.overallAccuracy, closeTo(1 / 3, 0.001));
      final topics = p2.weakestTopics();
      expect(topics, hasLength(1));
      expect(topics.first.title, 'SQL');
      expect(topics.first.attempts, 3);
      expect(topics.first.correct, 1);
    });

    test('повреждённый topic_stats JSON не роняет init', () async {
      SharedPreferences.setMockInitialValues({'topic_stats': '{not valid json'});
      final p = ProgressService();
      await p.init(); // не бросает исключение
      expect(p.overallAccuracy, 0.0);
      expect(p.weakestTopics(), isEmpty);
    });

    test('partial outcome не засчитывается как верный в topic stats', () async {
      final p = await freshService();
      await p.recordSession(
        't1',
        resWithAnswers([
          answered(q('q1', topic: 'SQL'), AnswerOutcome.partial),
          answered(q('q2', topic: 'SQL'), AnswerOutcome.partial),
          answered(q('q3', topic: 'SQL'), AnswerOutcome.partial),
        ]),
      );
      // 0 верных из 3 — точность 0
      expect(p.overallAccuracy, 0.0);
      final topics = p.weakestTopics();
      expect(topics.first.correct, 0);
    });
  });
}