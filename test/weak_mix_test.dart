import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:interview_helper_system/controllers/home_controller.dart';
import 'package:interview_helper_system/controllers/session_controller.dart';
import 'package:interview_helper_system/models/models.dart';
import 'package:interview_helper_system/services/progress_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

Question _q(String id, String topic) => Question(
      id: id,
      text: 't',
      options: const ['A', 'B'],
      correctIndexes: const [0],
      topic: topic,
    );

AnsweredQuestion _ans(Question q, AnswerOutcome outcome) => AnsweredQuestion(
      question: q,
      selected: const {0},
      outcome: outcome,
    );

Track _track(String id, List<Grade> grades) =>
    Track(id: id, title: id, order: 0, grades: grades);

Grade _grade(String id, List<Question> qs) =>
    Grade(id: id, title: id, order: 0, questions: qs);

void main() {
  group('recordMixedSession — раскладка по грейдам', () {
    late ProgressService progress;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      progress = ProgressService(clock: () => DateTime(2026, 6, 29, 9));
      await progress.init();
    });

    test('верные ответы попадают в свои gradeKey, не смешиваясь', () async {
      final qa = _q('a1', 'SQL'); // analytics_junior
      final qb = _q('d1', 'ООП'); // development_junior
      final qc = _q('a2', 'SQL'); // analytics_junior, отвечен неверно
      final result = SessionResult(
        correct: 2,
        partial: 0,
        wrong: 1,
        points: 2,
        maxPoints: 3,
        answers: [
          _ans(qa, AnswerOutcome.correct),
          _ans(qb, AnswerOutcome.correct),
          _ans(qc, AnswerOutcome.wrong),
        ],
        correctIds: {'a1', 'd1'},
      );

      await progress.recordMixedSession(result, {
        'a1': 'analytics_junior',
        'd1': 'development_junior',
        'a2': 'analytics_junior',
      });

      // Каждый верный id ушёл в свой грейд, без перекрёстного загрязнения.
      expect(progress.masteredIds('analytics', 'junior'), {'a1'});
      expect(progress.masteredIds('development', 'junior'), {'d1'});
      expect(progress.totalMastered, 2);
      expect(progress.xp, 20);
    });

    test('серия и дневной счётчик обновляются один раз', () async {
      final result = SessionResult(
        correct: 1,
        partial: 0,
        wrong: 1,
        points: 1,
        maxPoints: 2,
        answers: [
          _ans(_q('a1', 'SQL'), AnswerOutcome.correct),
          _ans(_q('d1', 'ООП'), AnswerOutcome.wrong),
        ],
        correctIds: {'a1'},
      );

      await progress.recordMixedSession(result, {
        'a1': 'analytics_junior',
        'd1': 'development_junior',
      });

      expect(progress.streak, 1);
      expect(progress.answeredToday, 2);
      // Статистика тем пополнилась: ООП теперь слабая (1 попытка, 0 верных).
      final weak = progress.weakestTopics().map((t) => t.title).toList();
      expect(weak, contains('ООП'));
    });
  });

  group('HomeController.generateMix — гейтинг и состав', () {
    Future<ProgressService> withPrefs(Map<String, Object> prefs) async {
      SharedPreferences.setMockInitialValues(prefs);
      final p = ProgressService(clock: () => DateTime(2026, 6, 29));
      await p.init();
      return p;
    }

    final tracks = [
      _track('analytics', [
        _grade('junior', [_q('a1', 'SQL'), _q('a2', 'API')]),
      ]),
      _track('development', [
        _grade('junior', [_q('d1', 'ООП')]),
      ]),
    ];

    test('одна слабая тема → микса нет (нужно ≥2)', () async {
      final p = await withPrefs({
        'topic_stats': json.encode({
          'SQL': {'attempts': 3, 'correct': 0},
        }),
      });
      expect(HomeController(tracks: tracks, progress: p).generateMix(), isNull);
    });

    test('две слабые темы → набор id из обеих, без освоенных', () async {
      final p = await withPrefs({
        'topic_stats': json.encode({
          'SQL': {'attempts': 3, 'correct': 0},
          'ООП': {'attempts': 2, 'correct': 1},
        }),
      });
      final ids = HomeController(tracks: tracks, progress: p).generateMix()!;
      // a1/a2 (SQL/API в analytics — обе слабые? нет: только SQL и ООП слабые)
      // Слабые темы: SQL (analytics) и ООП (development). a2 (API) не слабая.
      expect(ids.toSet(), {'a1', 'd1'});
    });

    test('освоенный вопрос не попадает в микс', () async {
      final p = await withPrefs({
        'topic_stats': json.encode({
          'SQL': {'attempts': 3, 'correct': 0},
          'ООП': {'attempts': 2, 'correct': 1},
        }),
        // Единственный вопрос ООП освоен → остаётся лишь SQL → <2 тем.
        'mastered_ids': json.encode({
          'development_junior': ['d1'],
        }),
      });
      expect(HomeController(tracks: tracks, progress: p).generateMix(), isNull);
    });
  });

  group('HomeController.practiceMixView — счётчик X/N', () {
    final tracks = [
      _track('analytics', [
        _grade('junior', [_q('a1', 'SQL'), _q('a2', 'API')]),
      ]),
      _track('development', [
        _grade('junior', [_q('d1', 'ООП')]),
      ]),
    ];

    test('нет сохранённого микса → view == null', () async {
      SharedPreferences.setMockInitialValues({});
      final p = ProgressService(clock: () => DateTime(2026, 6, 29));
      await p.init();
      expect(HomeController(tracks: tracks, progress: p).practiceMixView(),
          isNull,);
    });

    test('считает освоенные как X из N, остальные — в remaining', () async {
      SharedPreferences.setMockInitialValues({
        'practice_mix': json.encode(['a1', 'a2', 'd1']),
        'mastered_ids': json.encode({
          'analytics_junior': ['a1'], // 1 из 3 освоен
        }),
      });
      final p = ProgressService(clock: () => DateTime(2026, 6, 29));
      await p.init();

      final view = HomeController(tracks: tracks, progress: p)
          .practiceMixView()!;
      expect(view.total, 3);
      expect(view.mastered, 1);
      expect(view.isComplete, isFalse);
      expect(view.remaining.map((q) => q.id).toSet(), {'a2', 'd1'});
      // Карта грейдов для нерешённых ведёт в их реальные грейды.
      expect(view.questionGradeKeys['a2'], 'analytics_junior');
      expect(view.questionGradeKeys['d1'], 'development_junior');
    });

    test('все вопросы освоены → isComplete', () async {
      SharedPreferences.setMockInitialValues({
        'practice_mix': json.encode(['a1', 'd1']),
        'mastered_ids': json.encode({
          'analytics_junior': ['a1'],
          'development_junior': ['d1'],
        }),
      });
      final p = ProgressService(clock: () => DateTime(2026, 6, 29));
      await p.init();

      final view = HomeController(tracks: tracks, progress: p)
          .practiceMixView()!;
      expect(view.mastered, 2);
      expect(view.total, 2);
      expect(view.isComplete, isTrue);
      expect(view.remaining, isEmpty);
    });

    test('исчезнувший из каталога вопрос → view == null (невалиден)', () async {
      SharedPreferences.setMockInitialValues({
        'practice_mix': json.encode(['a1', 'ghost']),
      });
      final p = ProgressService(clock: () => DateTime(2026, 6, 29));
      await p.init();
      expect(HomeController(tracks: tracks, progress: p).practiceMixView(),
          isNull,);
    });
  });
}
