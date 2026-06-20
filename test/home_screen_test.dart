import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:interview_helper_system/models/models.dart';
import 'package:interview_helper_system/screens/grades_screen.dart';
import 'package:interview_helper_system/screens/home_screen.dart';
import 'package:interview_helper_system/screens/session_screen.dart';
import 'package:interview_helper_system/services/progress_service.dart';
import 'package:interview_helper_system/services/question_repository.dart';
import 'package:interview_helper_system/theme.dart';
import 'package:mocktail/mocktail.dart';

// --- Test doubles ----------------------------------------------------------
class MockQuestionRepository extends Mock implements QuestionRepository {}

class MockProgressService extends Mock implements ProgressService {}

// --- Builders --------------------------------------------------------------
Question _q({required String id, String? topic}) => Question(
      id: id,
      text: 'Вопрос $id',
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
  List<Grade> grades = const [],
}) =>
    Track(id: id, title: title, order: order, grades: grades);

void main() {
  late MockQuestionRepository repo;
  late MockProgressService progress;

  setUp(() {
    repo = MockQuestionRepository();
    progress = MockProgressService();
    when(() => progress.overallAccuracy).thenReturn(0);
    when(() => progress.hasTrainedEver).thenReturn(false);
    when(() => progress.streak).thenReturn(0);
    when(() => progress.totalMastered).thenReturn(0);
    when(() => progress.masteredIds(any(), any())).thenReturn(<String>{});
    when(() => progress.loadIncompleteSession(any())).thenReturn(null);
    when(
      () => progress.weakestTopics(
        limit: any(named: 'limit'),
        minAttempts: any(named: 'minAttempts'),
      ),
    ).thenReturn(<TopicStat>[]);
  });

  Future<void> pumpHome(WidgetTester tester) {
    return tester.pumpWidget(
      MaterialApp(
        theme: buildLightTheme(),
        home: HomeScreen(repository: repo, progress: progress),
      ),
    );
  }

  // === Ошибка + повтор (строки 364-369) ====================================
  testWidgets(
      'ошибка загрузки → экран ошибки; «Попробовать снова» грузит заново',
      (tester) async {
    var calls = 0;
    when(() => repo.loadTracks()).thenAnswer((_) async {
      calls++;
      if (calls == 1) throw Exception('boom');
      return <Track>[];
    });

    await pumpHome(tester);
    await tester.pumpAndSettle();
    expect(find.text('Не удалось загрузить вопросы'), findsOneWidget);

    await tester.tap(find.text('Попробовать снова'));
    await tester.pumpAndSettle();

    expect(find.text('Не удалось загрузить вопросы'), findsNothing);
    expect(tester.takeException(), isNull);
  },);

  // === Карточка слабых тем (строки 435-500) + дрилл по теме (96-141) ========
  testWidgets('карточка слабых тем рендерится; тап по теме открывает дрилл',
      (tester) async {
    when(
      () => progress.weakestTopics(
        limit: any(named: 'limit'),
        minAttempts: any(named: 'minAttempts'),
      ),
    ).thenReturn(const [TopicStat(title: 'SQL', attempts: 4, correct: 1)]);
    when(() => repo.loadTracks()).thenAnswer(
      (_) async => [
        _track(
          id: 't1',
          title: 'Аналитика',
          grades: [
            _grade(
              id: 'g1',
              title: 'Junior',
              questions: [
                _q(id: 'q1', topic: 'SQL'),
                _q(id: 'q2', topic: 'ООП'),
              ],
            ),
          ],
        ),
      ],
    );

    await pumpHome(tester);
    await tester.pumpAndSettle();

    expect(find.text('SQL'), findsOneWidget);
    expect(find.text('25%'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);

    await tester.tap(find.text('SQL'));
    await tester.pumpAndSettle();

    // Непройденный вопрос темы есть → стартует тема-дрилл (SessionScreen).
    expect(find.byType(SessionScreen), findsOneWidget);
  },);

  // === Дрилл по теме без остатка → снэкбар (строки 111-122) =================
  testWidgets('все вопросы темы пройдены → показывает снэкбар, без сессии',
      (tester) async {
    when(
      () => progress.weakestTopics(
        limit: any(named: 'limit'),
        minAttempts: any(named: 'minAttempts'),
      ),
    ).thenReturn(const [TopicStat(title: 'SQL', attempts: 4, correct: 1)]);
    when(() => repo.loadTracks()).thenAnswer(
      (_) async => [
        _track(
          id: 't1',
          title: 'Аналитика',
          grades: [
            _grade(
              id: 'g1',
              title: 'Junior',
              questions: [_q(id: 'q1', topic: 'SQL')],
            ),
          ],
        ),
      ],
    );
    // Единственный вопрос темы уже освоен → остатка нет.
    when(() => progress.masteredIds('t1', 'g1')).thenReturn({'q1'});

    await pumpHome(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.text('SQL'));
    await tester.pump();

    expect(find.textContaining('Все вопросы темы'), findsOneWidget);
    expect(find.byType(SessionScreen), findsNothing);
  },);

  // === CTA: слабая тема → грейд (строки 54-71, 143-151) =====================
  testWidgets('CTA по слабой теме открывает GradesScreen', (tester) async {
    when(
      () => progress.weakestTopics(
        limit: any(named: 'limit'),
        minAttempts: any(named: 'minAttempts'),
      ),
    ).thenReturn(const [TopicStat(title: 'SQL', attempts: 4, correct: 1)]);
    when(() => repo.loadTracks()).thenAnswer(
      (_) async => [
        _track(
          id: 't1',
          title: 'Аналитика',
          grades: [
            _grade(
              id: 'g1',
              title: 'Junior',
              questions: [_q(id: 'q1', topic: 'SQL')],
            ),
          ],
        ),
      ],
    );

    await pumpHome(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Начать тренировку'));
    await tester.pumpAndSettle();

    expect(find.byType(GradesScreen), findsOneWidget);
  });

  // === CTA: фолбэк на первый трек с непройденными (строки 75-84) ============
  testWidgets('без слабых тем CTA открывает первый трек с непройденными',
      (tester) async {
    when(() => repo.loadTracks()).thenAnswer(
      (_) async => [
        _track(
          id: 't1',
          title: 'Аналитика',
          grades: [
            _grade(id: 'g1', title: 'Junior', questions: [_q(id: 'q1')]),
          ],
        ),
      ],
    );

    await pumpHome(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Начать тренировку'));
    await tester.pumpAndSettle();

    expect(find.byType(GradesScreen), findsOneWidget);
  },);

  // === CTA: всё освоено → открываем первый трек (строки 87-88) ==============
  testWidgets('всё освоено → CTA всё равно открывает первый трек',
      (tester) async {
    when(() => repo.loadTracks()).thenAnswer(
      (_) async => [
        _track(
          id: 't1',
          title: 'Аналитика',
          grades: [
            _grade(id: 'g1', title: 'Junior', questions: [_q(id: 'q1')]),
          ],
        ),
      ],
    );
    when(() => progress.masteredIds('t1', 'g1')).thenReturn({'q1'});

    await pumpHome(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Начать тренировку'));
    await tester.pumpAndSettle();

    expect(find.byType(GradesScreen), findsOneWidget);
  },);

  // === CTA с пустым списком треков → ранний выход (строки 54-55) ============
  testWidgets('пустой список треков → CTA ничего не открывает и не падает',
      (tester) async {
    when(() => repo.loadTracks()).thenAnswer((_) async => <Track>[]);

    await pumpHome(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Начать тренировку'));
    await tester.pumpAndSettle();

    expect(find.byType(GradesScreen), findsNothing);
    expect(find.byType(SessionScreen), findsNothing);
    expect(tester.takeException(), isNull);
  },);

  // === Метрики при наличии истории (ветка accuracyLabel, строка 194) ========
  testWidgets('при наличии тренировок точность показывается в процентах',
      (tester) async {
    when(() => progress.hasTrainedEver).thenReturn(true);
    when(() => progress.overallAccuracy).thenReturn(0.8);
    when(() => repo.loadTracks()).thenAnswer((_) async => <Track>[]);

    await pumpHome(tester);
    await tester.pumpAndSettle();

    expect(find.text('80%'), findsOneWidget);
    expect(find.text('Продолжить тренировку'), findsOneWidget);
  },);
}
