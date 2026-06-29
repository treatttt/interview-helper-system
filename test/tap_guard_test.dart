import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:interview_helper_system/models/models.dart';
import 'package:interview_helper_system/screens/grades_screen.dart';
import 'package:interview_helper_system/screens/home_screen.dart';
import 'package:interview_helper_system/screens/practice_topics_screen.dart';
import 'package:interview_helper_system/screens/session_screen.dart';
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

Grade _grade(List<Question> questions) =>
    Grade(id: 'junior', title: 'Junior', order: 0, questions: questions);

Track _track(List<Question> questions) => Track(
      id: 't1',
      title: 'Аналитика',
      order: 0,
      grades: [_grade(questions)],
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
    when(() => progress.incompleteSession).thenReturn(null);
    when(() => progress.incompleteTopicSession).thenReturn(null);
    // Метрики «Главной».
    when(() => progress.overallAccuracy).thenReturn(0);
    when(() => progress.hasTrainedEver).thenReturn(true);
    when(() => progress.streak).thenReturn(0);
    when(() => progress.totalMastered).thenReturn(0);
    when(() => progress.answeredToday).thenReturn(0);
    when(
      () => progress.weakestTopics(
        limit: any(named: 'limit'),
        minAttempts: any(named: 'minAttempts'),
      ),
    ).thenReturn(const <TopicStat>[]);
  });

  // === Практика (темы трека): двойной тап по теме ==========================
  testWidgets('двойной тап по теме открывает ровно один SessionScreen',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildLightTheme(),
        home: PracticeTopicsScreen(
          track: _track([_q('q1', topic: 'SQL')]),
          progress: progress,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Два тапа подряд до построения сессии — лок держится на awaited-пуше.
    await tester.tap(find.text('SQL'));
    await tester.tap(find.text('SQL'));
    await tester.pumpAndSettle();

    expect(find.byType(SessionScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  },);

  // === «Главная»: двойной тап по карточке «Начать» ========================
  testWidgets('двойной тап по карточке «Начать» открывает один SessionScreen',
      (tester) async {
    when(() => repo.loadTracks()).thenAnswer(
      (_) async => [
        _track([_q('q1', topic: 'SQL')]),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: buildLightTheme(),
        home: HomeScreen(repository: repo, progress: progress),
      ),
    );
    await tester.pumpAndSettle();

    // Два тапа подряд до построения сессии — лок держится на awaited-пуше.
    await tester.tap(find.text('Начать'));
    await tester.tap(find.text('Начать'));
    await tester.pumpAndSettle();

    expect(find.byType(SessionScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  },);

  // === «Главная»: двойной тап по строке направления =======================
  testWidgets('двойной тап по направлению открывает один GradesScreen',
      (tester) async {
    when(() => repo.loadTracks()).thenAnswer(
      (_) async => [
        _track([_q('q1', topic: 'SQL')]),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: buildLightTheme(),
        home: HomeScreen(repository: repo, progress: progress),
      ),
    );
    await tester.pumpAndSettle();

    // «Аналитика» теперь и в заголовке карточки «Начать», и в строке
    // направления — целимся в строку направления (последнее вхождение).
    await tester.tap(find.text('Аналитика').last);
    await tester.tap(find.text('Аналитика').last);
    await tester.pumpAndSettle();

    expect(find.byType(GradesScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  },);
}
