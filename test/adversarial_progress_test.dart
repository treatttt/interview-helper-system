import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:interview_helper_system/controllers/session_controller.dart';
import 'package:interview_helper_system/models/models.dart';
import 'package:interview_helper_system/services/progress_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

SessionResult r(Set<String> ids, {int wrong = 0}) => SessionResult(
      correct: ids.length,
      partial: 0,
      wrong: wrong,
      points: ids.length,
      maxPoints: ids.length + wrong,
      answers: const [],
      correctIds: ids,
    );

Future<ProgressService> fresh() async {
  SharedPreferences.setMockInitialValues({});
  final p = ProgressService();
  await p.init();
  return p;
}

void main() {
  // ─── XP ────────────────────────────────────────────────────────────────────
  group('XP — попытки накрутки и уведения в минус', () {
    test('XP не уходит в минус при любых входных данных', () async {
      final p = await fresh();
      await p.recordSession('t_j', r(const {})); // ноль верных
      await p.recordSession('t_j', r(const {}, wrong: 100));
      expect(p.xp, 0);
    });

    test('100 одинаковых сессий дают столько же XP, сколько одна', () async {
      final p = await fresh();
      for (var i = 0; i < 100; i++) {
        await p.recordSession('t_j', r({'q1', 'q2'}));
      }
      expect(p.xp, 20);
    });

    test('перекрывающиеся correctIds в двух сессиях — XP только за новые', () async {
      final p = await fresh();
      await p.recordSession('t_j', r({'q1', 'q2', 'q3'})); // +30
      await p.recordSession('t_j', r({'q2', 'q3', 'q4', 'q5'})); // новые: q4, q5 → +20
      expect(p.xp, 50);
    });

    test('после resetGrade XP накапливается заново для тех же ID', () async {
      final p = await fresh();
      await p.recordSession('t_j', r({'q1', 'q2'})); // +20
      await p.resetGrade('t', 'j');
      await p.recordSession('t_j', r({'q1', 'q2'})); // q1,q2 снова новые → +20
      expect(p.xp, 40);
    });

    test('XP из двух грейдов не влияют друг на друга', () async {
      final p = await fresh();
      await p.recordSession('t_junior', r({'q1', 'q2'})); // +20
      await p.recordSession('t_middle', r({'q1', 'q2'})); // те же ID, другой грейд → +20
      expect(p.xp, 40);
    });
  });

  // ─── masteredIds — изоляция внутреннего состояния ──────────────────────────
  group('masteredIds — утечка мутабельного Set', () {
    test('мутация возвращённого Set не меняет внутренние данные сервиса', () async {
      final p = await fresh();
      await p.recordSession('t_j', r({'q1', 'q2'}));

      final leaked = p.masteredIds('t', 'j');
      try {
        leaked.add('injected'); // попытка мутировать внутреннее состояние
      } catch (_) {
        // UnsupportedError — сет защищён, тест уже проходит
        return;
      }
      // Если add не бросил — внутренний стейт не должен был испортиться
      expect(
        p.masteredIds('t', 'j'),
        isNot(contains('injected')),
        reason: 'masteredIds должен возвращать защищённую копию, не ссылку',
      );
    });

    test('два последовательных вызова masteredIds возвращают равные множества', () async {
      final p = await fresh();
      await p.recordSession('t_j', r({'q1', 'q2', 'q3'}));
      expect(p.masteredIds('t', 'j'), p.masteredIds('t', 'j'));
    });

    test('masteredIds несуществующего грейда возвращает пустое множество, не крашится', () async {
      final p = await fresh();
      expect(() => p.masteredIds('ghost', 'grade'), returnsNormally);
      expect(p.masteredIds('ghost', 'grade'), isEmpty);
    });

    test('gradeDone несуществующего грейда возвращает 0', () async {
      final p = await fresh();
      expect(p.gradeDone('ghost', 'grade'), 0);
    });
  });

  // ─── незавершённая сессия — изоляция слотов ────────────────────────────────
  group('незавершённая сессия — атаки на слот', () {
    final slot = {
      'gradeKey': 'track_junior',
      'questionIds': ['q1', 'q2'],
      'currentIndex': 1,
      'answeredData': <dynamic>[],
    };

    test('loadIncompleteSession с чужим ключом возвращает null', () async {
      final p = await fresh();
      await p.saveIncompleteSession(slot);
      expect(p.loadIncompleteSession('track_middle'), isNull);
    });

    test('второй saveIncompleteSession перезаписывает первый', () async {
      final p = await fresh();
      await p.saveIncompleteSession(slot);
      await p.saveIncompleteSession({
        'gradeKey': 'other_grade',
        'questionIds': <dynamic>[],
        'currentIndex': 0,
        'answeredData': <dynamic>[],
      });
      expect(p.loadIncompleteSession('track_junior'), isNull); // вытеснена
      expect(p.loadIncompleteSession('other_grade'), isNotNull);
    });

    test('clearIncompleteSession с чужим gradeKey не удаляет чужую сессию', () async {
      final p = await fresh();
      await p.saveIncompleteSession(slot);
      await p.clearIncompleteSession(gradeKey: 'completely_different');
      expect(p.loadIncompleteSession('track_junior'), isNotNull);
    });

    test('clearIncompleteSession без аргумента удаляет любую сессию', () async {
      final p = await fresh();
      await p.saveIncompleteSession(slot);
      await p.clearIncompleteSession();
      expect(p.loadIncompleteSession('track_junior'), isNull);
    });

    test('recordSession очищает незавершённую сессию только своего грейда', () async {
      final p = await fresh();
      // Сессия middle осталась незавершённой
      await p.saveIncompleteSession({
        'gradeKey': 't_middle',
        'questionIds': ['q9'],
        'currentIndex': 0,
        'answeredData': <dynamic>[],
      });
      // Завершаем junior — middle не должен быть затронут
      await p.recordSession('t_junior', r({'q1'}));
      expect(p.loadIncompleteSession('t_middle'), isNotNull);
    });

    test('recordSession очищает незавершённую сессию своего грейда', () async {
      final p = await fresh();
      await p.saveIncompleteSession({
        'gradeKey': 't_j',
        'questionIds': ['q1'],
        'currentIndex': 0,
        'answeredData': <dynamic>[],
      });
      await p.recordSession('t_j', r({'q1'}));
      expect(p.loadIncompleteSession('t_j'), isNull);
    });
  });

  // ─── persistence — корректность перезапуска ─────────────────────────────────
  group('persistence — данные переживают пересоздание сервиса', () {
    test('masteredIds и XP доступны после пересоздания сервиса', () async {
      SharedPreferences.setMockInitialValues({});
      final p1 = ProgressService();
      await p1.init();
      await p1.recordSession('t_j', r({'q1', 'q2', 'q3'}));

      final p2 = ProgressService(); // тот же mock-стор
      await p2.init();
      expect(p2.xp, 30);
      expect(p2.masteredIds('t', 'j'), containsAll(['q1', 'q2', 'q3']));
    });

    test('незавершённая сессия переживает пересоздание сервиса', () async {
      SharedPreferences.setMockInitialValues({});
      final p1 = ProgressService();
      await p1.init();
      await p1.saveIncompleteSession({
        'gradeKey': 't_j',
        'questionIds': ['q1', 'q2'],
        'currentIndex': 1,
        'answeredData': <dynamic>[],
      });

      final p2 = ProgressService();
      await p2.init();
      expect(p2.loadIncompleteSession('t_j'), isNotNull);
    });

    test('повреждённый JSON mastered_ids — graceful fallback к пустому состоянию', () async {
      SharedPreferences.setMockInitialValues({'mastered_ids': 'NOT}VALID{JSON'});
      final p = ProgressService();
      await p.init();
      expect(p.xp, 0);
      expect(p.gradeDone('any', 'grade'), 0);
      expect(() => p.masteredIds('any', 'grade'), returnsNormally);
    });

    test('повреждённый JSON incomplete_session — graceful fallback к null', () async {
      SharedPreferences.setMockInitialValues({'incomplete_session': '}{broken'});
      final p = ProgressService();
      await p.init();
      expect(p.loadIncompleteSession('any'), isNull);
    });

    test('mastered_ids с нечисловыми значениями — игнорируются без краша', () async {
      SharedPreferences.setMockInitialValues({
        'mastered_ids': '{"t_j": 42}', // число вместо списка → должно быть проигнорировано
      });
      final p = ProgressService();
      await p.init();
      expect(p.gradeDone('t', 'j'), 0);
    });
  });

  // ─── resetGrade — изоляция ──────────────────────────────────────────────────
  group('resetGrade — не затрагивает соседние грейды', () {
    test('сброс одного грейда не трогает другой грейд того же трека', () async {
      final p = await fresh();
      await p.recordSession('analytics_junior', r({'q1'}));
      await p.recordSession('analytics_middle', r({'q2'}));
      await p.resetGrade('analytics', 'junior');
      expect(p.gradeDone('analytics', 'junior'), 0);
      expect(p.gradeDone('analytics', 'middle'), 1);
    });

    test('сброс несуществующего грейда не крашится', () async {
      final p = await fresh();
      expect(() => p.resetGrade('ghost', 'grade'), returnsNormally);
    });

    test('XP сохраняется при сбросе другого грейда', () async {
      final p = await fresh();
      await p.recordSession('t_junior', r({'q1'}));
      final xpBefore = p.xp;
      await p.resetGrade('t', 'middle'); // другой грейд
      expect(p.xp, xpBefore);
    });
  });

  // ─── streak — не должен уйти в минус или задвоиться ────────────────────────
  group('streak — атаки на счётчик серии', () {
    test('streak не уходит в минус при любых входных данных', () async {
      final p = await fresh();
      await p.recordSession('t', r({'q1'}));
      expect(p.streak, greaterThanOrEqualTo(0));
    });

    test('две сессии в один день — streak остаётся 1', () async {
      final p = await fresh();
      await p.recordSession('t1', r({'q1'}));
      await p.recordSession('t2', r({'q2'}));
      expect(p.streak, 1);
    });
  });

  // ─── topic_stats — повреждённые данные в prefs ────────────────────────────
  group('topic_stats — повреждённые данные из prefs', () {
    test(
      'attempts=0 correct=5 в prefs — accuracy для этой темы = 0.0 (защита от деления на ноль)',
      () async {
        SharedPreferences.setMockInitialValues({
          'topic_stats': json.encode({'SQL': {'attempts': 0, 'correct': 5}}),
        });
        final p = ProgressService();
        await p.init();
        final topics = p.weakestTopics();
        // attempts=0 < minAttempts=1, тема не появляется в weakestTopics
        expect(topics, isEmpty);
        // overallAccuracy: attempts=0 → guard возвращает 0.0
        expect(p.overallAccuracy, 0.0);
      },
    );

    test(
      'attempts=1 correct=5 в prefs — overallAccuracy превышает 1.0',
      () async {
        // FIXME: выявляет баг — _readTopicStats не клампирует correct <= attempts.
        // TopicStat.accuracy = 5/1 = 5.0, overallAccuracy = 5.0 > 1.0.
        SharedPreferences.setMockInitialValues({
          'topic_stats': json.encode({'SQL': {'attempts': 1, 'correct': 5}}),
        });
        final p = ProgressService();
        await p.init();
        expect(p.overallAccuracy, greaterThan(1.0));
      },
    );

    test('повреждённый topic_stats JSON (не Map) → graceful fallback, нет краша', () async {
      SharedPreferences.setMockInitialValues({
        'topic_stats': '}{NOT_VALID',
      });
      final p = ProgressService();
      await p.init();
      expect(p.overallAccuracy, 0.0);
      expect(p.weakestTopics(), isEmpty);
    });

    test('тема с нечисловыми attempts/correct → строка игнорируется без краша', () async {
      SharedPreferences.setMockInitialValues({
        'topic_stats': json.encode({
          'SQL': {'attempts': 'много', 'correct': 'все'}, // строки, не int
        }),
      });
      final p = ProgressService();
      await p.init();
      expect(p.weakestTopics(), isEmpty);
      expect(p.overallAccuracy, 0.0);
    });
  });

  // ─── topic_stats — семантика перезаписи, а не накопления ─────────────────
  group('topic_stats — перезапись результатами сессии, не накопление', () {
    Question tq(String id, String topic) => Question(
          id: id,
          text: 'Q',
          options: const ['A', 'B'],
          correctIndexes: const [0],
          topic: topic,
        );

    AnsweredQuestion answered(Question q, AnswerOutcome o) =>
        AnsweredQuestion(question: q, selected: const {0}, outcome: o);

    SessionResult topicResult(List<AnsweredQuestion> answers) {
      final correctIds =
          answers.where((a) => a.outcome == AnswerOutcome.correct).map((a) => a.question.id).toSet();
      return SessionResult(
        correct: correctIds.length,
        partial: 0,
        wrong: answers.where((a) => a.outcome == AnswerOutcome.wrong).length,
        points: correctIds.length,
        maxPoints: answers.length,
        answers: answers,
        correctIds: correctIds,
      );
    }

    test(
      'две сессии по одной теме: weakestTopics отражает только вторую (перезапись)',
      () async {
        final p = await fresh();
        // Первая: 1 верный из 4 → точность 25 %
        await p.recordSession(
          't_j',
          topicResult([
            answered(tq('q1', 'SQL'), AnswerOutcome.correct),
            answered(tq('q2', 'SQL'), AnswerOutcome.wrong),
            answered(tq('q3', 'SQL'), AnswerOutcome.wrong),
            answered(tq('q4', 'SQL'), AnswerOutcome.wrong),
          ]),
        );
        // Вторая: 2 верных из 2 → точность 100 %
        await p.recordSession(
          't_j',
          topicResult([
            answered(tq('q5', 'SQL'), AnswerOutcome.correct),
            answered(tq('q6', 'SQL'), AnswerOutcome.correct),
          ]),
        );

        final topics = p.weakestTopics();
        expect(topics, hasLength(1));
        expect(topics.single.attempts, 2); // только вторая сессия, не 4+2=6
        expect(topics.single.correct, 2);
      },
    );

    test(
      'тема вне текущей сессии сохраняет свои старые значения',
      () async {
        final p = await fresh();
        // Первая сессия: SQL 1/4
        await p.recordSession(
          't_j',
          topicResult([
            answered(tq('q1', 'SQL'), AnswerOutcome.correct),
            answered(tq('q2', 'SQL'), AnswerOutcome.wrong),
            answered(tq('q3', 'SQL'), AnswerOutcome.wrong),
            answered(tq('q4', 'SQL'), AnswerOutcome.wrong),
          ]),
        );
        // Вторая сессия: только API, SQL не трогаем
        await p.recordSession(
          't_j',
          topicResult([
            answered(tq('q5', 'API'), AnswerOutcome.correct),
            answered(tq('q6', 'API'), AnswerOutcome.correct),
          ]),
        );

        final topics = p.weakestTopics(limit: 10);
        final sql = topics.firstWhere((t) => t.title == 'SQL');
        final api = topics.firstWhere((t) => t.title == 'API');

        // SQL должен остаться 1/4 — вторая сессия его не затронула
        expect(sql.attempts, 4);
        expect(sql.correct, 1);
        // API — результат второй сессии
        expect(api.attempts, 2);
        expect(api.correct, 2);
      },
    );
  });
}
