import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:interview_helper_system/models/models.dart';
import 'package:interview_helper_system/screens/grades_screen.dart';
import 'package:interview_helper_system/screens/topics_screen.dart';
import 'package:interview_helper_system/services/progress_service.dart';
import 'package:interview_helper_system/services/question_repository.dart';
import 'package:interview_helper_system/theme.dart';
import 'package:mocktail/mocktail.dart';

// --- Test doubles ----------------------------------------------------------
class MockQuestionRepository extends Mock implements QuestionRepository {}

class MockProgressService extends Mock implements ProgressService {}

// --- Builders --------------------------------------------------------------
Question _q(String id) => Question(
      id: id,
      text: 't',
      options: const ['A', 'B'],
      correctIndexes: const [0],
    );

Grade _grade({
  required String id,
  required String title,
  int order = 0,
  String? description,
  List<Question> questions = const [],
}) =>
    Grade(
      id: id,
      title: title,
      order: order,
      description: description,
      questions: questions,
    );

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

  setUp(() {
    repo = MockQuestionRepository();
    progress = MockProgressService();
    when(() => progress.masteredIds(any(), any())).thenReturn(<String>{});
    when(() => progress.loadIncompleteSession(any())).thenReturn(null);
  });

  Future<void> pumpTopics(WidgetTester tester) {
    return tester.pumpWidget(
      MaterialApp(
        theme: buildLightTheme(),
        home: TopicsScreen(repository: repo, progress: progress),
      ),
    );
  }

  // === Загрузка → пусто ====================================================
  testWidgets('пока идёт загрузка — спиннер; пустой ответ → пустое состояние',
      (tester) async {
    final completer = Completer<List<Track>>();
    when(() => repo.loadTracks()).thenAnswer((_) => completer.future);

    await pumpTopics(tester);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    completer.complete(<Track>[]);
    await tester.pumpAndSettle();

    expect(find.text('Вопросов пока нет'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  },);

  // === Ошибка + повтор =====================================================
  testWidgets('ошибка загрузки показывает экран ошибки; повтор грузит заново',
      (tester) async {
    var calls = 0;
    when(() => repo.loadTracks()).thenAnswer((_) async {
      calls++;
      if (calls == 1) throw Exception('boom');
      return [_track(id: 't1', title: 'Аналитика')];
    });

    await pumpTopics(tester);
    await tester.pumpAndSettle();

    expect(find.text('Не удалось загрузить направления'), findsOneWidget);
    expect(find.text('Попробовать снова'), findsOneWidget);

    await tester.tap(find.text('Попробовать снова'));
    await tester.pumpAndSettle();

    expect(find.text('Аналитика'), findsOneWidget);
    expect(find.text('Не удалось загрузить направления'), findsNothing);
  },);

  // === Список + сортировка по order ========================================
  testWidgets('рендерит карточки треков, отсортированные по order',
      (tester) async {
    when(() => repo.loadTracks()).thenAnswer(
      (_) async => [
        _track(id: 't2', title: 'Тестирование', order: 1),
        _track(id: 't1', title: 'Аналитика'),
      ],
    );

    await pumpTopics(tester);
    await tester.pumpAndSettle();

    expect(find.text('Аналитика'), findsOneWidget);
    expect(find.text('Тестирование'), findsOneWidget);

    final dyAnalytics = tester.getTopLeft(find.text('Аналитика')).dy;
    final dyTesting = tester.getTopLeft(find.text('Тестирование')).dy;
    expect(dyAnalytics, lessThan(dyTesting));
  },);

  // === Карточка: счётчик и прогресс-бар =====================================
  testWidgets('карточка показывает mastered/total и прогресс-бар при вопросах',
      (tester) async {
    when(() => repo.loadTracks()).thenAnswer(
      (_) async => [
        _track(
          id: 't1',
          title: 'Аналитика',
          grades: [
            _grade(id: 'g1', title: 'Junior', questions: [_q('q1'), _q('q2')]),
          ],
        ),
      ],
    );
    when(() => progress.masteredIds('t1', 'g1')).thenReturn({'q1'});

    await pumpTopics(tester);
    await tester.pumpAndSettle();

    expect(find.text('1/2'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
  },);

  testWidgets('без вопросов: счётчик 0/0 и прогресс-бар не рисуется',
      (tester) async {
    when(() => repo.loadTracks()).thenAnswer(
      (_) async => [
        _track(
          id: 't1',
          title: 'Аналитика',
          grades: [_grade(id: 'g1', title: 'Junior')],
        ),
      ],
    );

    await pumpTopics(tester);
    await tester.pumpAndSettle();

    expect(find.text('0/0'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  },);

  // === Описание ============================================================
  testWidgets('показывает описание трека, когда оно задано', (tester) async {
    when(() => repo.loadTracks()).thenAnswer(
      (_) async => [
        _track(
          id: 't1',
          title: 'Аналитика',
          description: 'Сбор и анализ требований',
          grades: [
            _grade(id: 'g1', title: 'Junior', questions: [_q('q1')]),
          ],
        ),
      ],
    );

    await pumpTopics(tester);
    await tester.pumpAndSettle();

    expect(find.text('Сбор и анализ требований'), findsOneWidget);
  });

  // === Навигация ===========================================================
  testWidgets('тап по карточке открывает GradesScreen', (tester) async {
    when(() => repo.loadTracks()).thenAnswer(
      (_) async => [
        _track(
          id: 't1',
          title: 'Аналитика',
          grades: [
            _grade(id: 'g1', title: 'Junior', questions: [_q('q1')]),
          ],
        ),
      ],
    );

    await pumpTopics(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Аналитика'));
    await tester.pumpAndSettle();

    expect(find.byType(GradesScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
