import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:interview_helper_system/models/models.dart';
import 'package:interview_helper_system/screens/session_screen.dart';
import 'package:interview_helper_system/screens/topics_screen.dart';
import 'package:interview_helper_system/services/progress_service.dart';
import 'package:interview_helper_system/services/question_repository.dart';
import 'package:interview_helper_system/theme.dart';
import 'package:mocktail/mocktail.dart';

// --- Test doubles ----------------------------------------------------------
class MockQuestionRepository extends Mock implements QuestionRepository {}

class MockProgressService extends Mock implements ProgressService {}

// --- Builders --------------------------------------------------------------
Question _q(String id, {String? topic}) => Question(
      id: id,
      text: 't',
      options: const ['A', 'B'],
      correctIndexes: const [0],
      topic: topic,
    );

Grade _grade({
  required String id,
  required String title,
  int order = 0,
  List<Question> questions = const [],
}) =>
    Grade(id: id, title: title, order: order, questions: questions);

Track _track({
  required String id,
  required String title,
  int order = 0,
  String? description,
  List<Grade> grades = const [],
}) =>
    Track(
      id: id,
      title: title,
      order: order,
      description: description,
      grades: grades,
    );

void main() {
  late MockQuestionRepository repo;
  late MockProgressService progress;

  setUpAll(() {
    registerFallbackValue(<String, Set<String>>{});
  });

  setUp(() {
    repo = MockQuestionRepository();
    progress = MockProgressService();
    when(() => progress.masteredIds(any(), any())).thenReturn(<String>{});
    when(() => progress.loadIncompleteSession(any())).thenReturn(null);
    when(() => progress.loadIncompleteTopicSession(any())).thenReturn(null);
  });

  Future<void> pumpTopics(WidgetTester tester) {
    return tester.pumpWidget(
      MaterialApp(
        theme: buildLightTheme(),
        home: TopicsScreen(repository: repo, progress: progress),
      ),
    );
  }

  // Один трек с одним грейдом и заданными вопросами.
  Track oneGradeTrack(List<Question> questions) => _track(
        id: 't1',
        title: 'Аналитика',
        grades: [_grade(id: 'junior', title: 'Junior', questions: questions)],
      );

  // === Загрузка → пусто ====================================================
  testWidgets('идёт загрузка — спиннер; вопросов нет → пустое состояние',
    (tester) async {
      final completer = Completer<List<Track>>();
      when(() => repo.loadTracks()).thenAnswer((_) => completer.future);

      await pumpTopics(tester);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      completer.complete(<Track>[]);
      await tester.pumpAndSettle();

      expect(find.text('Тем пока нет'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    },
  );

  testWidgets('треки есть, но без тем у вопросов → пустое состояние',
    (tester) async {
      when(() => repo.loadTracks()).thenAnswer(
        (_) async => [
          oneGradeTrack([_q('q1'), _q('q2')]), // topic == null
        ],
      );

      await pumpTopics(tester);
      await tester.pumpAndSettle();

      expect(find.text('Тем пока нет'), findsOneWidget);
    },
  );

  // === Ошибка + повтор =====================================================
  testWidgets('ошибка показывает экран ошибки; повтор грузит заново',
    (tester) async {
      var calls = 0;
      when(() => repo.loadTracks()).thenAnswer((_) async {
        calls++;
        if (calls == 1) throw Exception('boom');
        return [
          oneGradeTrack([_q('q1', topic: 'SQL')]),
        ];
      });

      await pumpTopics(tester);
      await tester.pumpAndSettle();

      expect(find.text('Не удалось загрузить темы'), findsOneWidget);
      expect(find.text('Попробовать снова'), findsOneWidget);

      await tester.tap(find.text('Попробовать снова'));
      await tester.pumpAndSettle();

      expect(find.text('SQL'), findsOneWidget);
      expect(find.text('Не удалось загрузить темы'), findsNothing);
    },
  );

  // === Список тем: группировка, счётчики, порядок ==========================
  testWidgets('группирует вопросы по теме, считает mastered/total',
    (tester) async {
      when(() => repo.loadTracks()).thenAnswer(
        (_) async => [
          oneGradeTrack([
            _q('q1', topic: 'SQL'),
            _q('q2', topic: 'SQL'),
            _q('q3', topic: 'БД'),
          ]),
        ],
      );
      when(() => progress.masteredIds('t1', 'junior')).thenReturn({'q1'});

      await pumpTopics(tester);
      await tester.pumpAndSettle();

      expect(find.text('SQL'), findsOneWidget);
      expect(find.text('БД'), findsOneWidget);
      expect(find.text('1/2'), findsOneWidget); // SQL: q1 освоен из q1,q2
      expect(find.text('0/1'), findsOneWidget); // БД: q3 не освоен
      expect(find.byType(LinearProgressIndicator), findsNWidgets(2));

      // Порядок — по первому появлению темы: SQL раньше БД.
      final dySql = tester.getTopLeft(find.text('SQL')).dy;
      final dyDb = tester.getTopLeft(find.text('БД')).dy;
      expect(dySql, lessThan(dyDb));
    },
  );

  testWidgets(
    'полностью пройденная тема показывает «Все пройдены» + сброс',
    (tester) async {
      when(() => repo.loadTracks()).thenAnswer(
        (_) async => [
          oneGradeTrack([_q('q1', topic: 'SQL')]),
        ],
      );
      when(() => progress.masteredIds('t1', 'junior')).thenReturn({'q1'});

      await pumpTopics(tester);
      await tester.pumpAndSettle();

      expect(find.text('Все пройдены'), findsOneWidget);
      expect(find.byIcon(Icons.refresh), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsNothing);
      expect(find.text('1/1'), findsNothing);
    },
  );

  // === Навигация ===========================================================
  testWidgets('тап по теме с непройденными вопросами открывает SessionScreen',
    (tester) async {
      when(() => repo.loadTracks()).thenAnswer(
        (_) async => [
          oneGradeTrack([_q('q1', topic: 'SQL')]),
        ],
      );

      await pumpTopics(tester);
      await tester.pumpAndSettle();

      await tester.tap(find.text('SQL'));
      await tester.pumpAndSettle();

      expect(find.byType(SessionScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'тап по пройденной теме ведёт в сброс (диалог), не в сессию',
    (tester) async {
      when(() => repo.loadTracks()).thenAnswer(
        (_) async => [
          oneGradeTrack([_q('q1', topic: 'SQL')]),
        ],
      );
      when(() => progress.masteredIds('t1', 'junior')).thenReturn({'q1'});

      await pumpTopics(tester);
      await tester.pumpAndSettle();

      await tester.tap(find.text('SQL'));
      await tester.pumpAndSettle();

      expect(find.byType(SessionScreen), findsNothing);
      expect(find.text('Сбросить тему?'), findsOneWidget);

      await tester.tap(find.text('Отмена'));
      await tester.pumpAndSettle();
    },
  );

  // === Сброс темы ==========================================================
  testWidgets(
    'иконка сброса у частичной темы → подтверждение → сброс',
    (tester) async {
      when(() => repo.loadTracks()).thenAnswer(
        (_) async => [
          oneGradeTrack([_q('q1', topic: 'SQL'), _q('q2', topic: 'SQL')]),
        ],
      );
      // Частично пройдена → есть иконка сброса рядом со счётчиком.
      when(() => progress.masteredIds('t1', 'junior')).thenReturn({'q1'});
      when(() => progress.resetMastered(any())).thenAnswer((_) async {});
      when(
        () => progress.clearIncompleteTopicSession(
          topicTitle: any(named: 'topicTitle'),
        ),
      ).thenAnswer((_) async {});

      await pumpTopics(tester);
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.refresh));
      await tester.pumpAndSettle();
      expect(find.text('Сбросить тему?'), findsOneWidget);

      await tester.tap(find.text('Сбросить'));
      await tester.pumpAndSettle();

      verify(() => progress.resetMastered(any())).called(1);
      verify(
        () => progress.clearIncompleteTopicSession(topicTitle: 'SQL'),
      ).called(1);
    },
  );
}
