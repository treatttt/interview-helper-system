import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:interview_helper_system/models/models.dart';
import 'package:interview_helper_system/screens/practice_screen.dart';
import 'package:interview_helper_system/screens/practice_topics_screen.dart';
import 'package:interview_helper_system/screens/session_screen.dart';
import 'package:interview_helper_system/services/progress_service.dart';
import 'package:interview_helper_system/services/question_repository.dart';
import 'package:interview_helper_system/theme.dart';
import 'package:mocktail/mocktail.dart';

class MockQuestionRepository extends Mock implements QuestionRepository {}

class MockProgressService extends Mock implements ProgressService {}

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
  String? description,
  String? category,
  List<Grade> grades = const [],
}) =>
    Track(
      id: id,
      title: title,
      order: order,
      description: description,
      category: category,
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
    when(() => progress.incompleteSession).thenReturn(null);
    when(() => progress.incompleteTopicSession).thenReturn(null);
    when(() => progress.answeredToday).thenReturn(0);
    when(() => progress.practiceMix).thenReturn(<String>[]);
    when(() => progress.savePracticeMix(any())).thenAnswer((_) async {});
    when(() => progress.clearPracticeMix()).thenAnswer((_) async {});
    when(
      () => progress.weakestTopics(
        limit: any(named: 'limit'),
        minAttempts: any(named: 'minAttempts'),
      ),
    ).thenReturn(<TopicStat>[]);
  });

  Future<void> pumpPractice(WidgetTester tester) {
    return tester.pumpWidget(
      MaterialApp(
        theme: buildLightTheme(),
        home: PracticeScreen(repository: repo, progress: progress),
      ),
    );
  }

  // === Frame 1: выбор направления ==========================================
  testWidgets('без микса «Тренировка дня» скрыта, направления видны',
      (tester) async {
    when(() => repo.loadTracks()).thenAnswer(
      (_) async => [
        _track(
          id: 'analytics',
          title: 'Аналитика',
          description: 'Системный анализ, требования',
          grades: [
            _grade(
              id: 'junior',
              title: 'Junior',
              questions: [_q(id: 'a1', topic: 'SQL'), _q(id: 'a2', topic: 'API')],
            ),
          ],
        ),
        _track(id: 'go', title: 'Go', order: 9, category: 'language'),
      ],
    );

    await pumpPractice(tester);
    await tester.pumpAndSettle();

    expect(find.text('Практика'), findsOneWidget);
    // Сохранённого микса нет (practiceMix → []) → карточка скрыта.
    expect(find.text('Тренировка дня'), findsNothing);
    expect(find.text('ВЫБЕРИТЕ НАПРАВЛЕНИЕ'), findsOneWidget);
    expect(find.text('Аналитика'), findsOneWidget);
    // Тэглайн: краткое описание + число тем.
    expect(find.text('Системный анализ · 2 темы'), findsOneWidget);
    // Языковой трек скрыт.
    expect(find.text('Go'), findsNothing);
  });

  testWidgets('сохранённый микс показывает карточку со счётчиком X/N',
      (tester) async {
    when(() => repo.loadTracks()).thenAnswer(
      (_) async => [
        _track(
          id: 'analytics',
          title: 'Аналитика',
          grades: [
            _grade(id: 'junior', title: 'Junior', questions: [
              _q(id: 'a1', topic: 'SQL'),
              _q(id: 'a2', topic: 'API'),
            ],),
          ],
        ),
      ],
    );
    // Микс из двух вопросов, ни один не освоен → 0/2.
    when(() => progress.practiceMix).thenReturn(['a1', 'a2']);

    await pumpPractice(tester);
    await tester.pumpAndSettle();

    expect(find.text('Тренировка дня'), findsOneWidget);
    expect(find.text('0/2'), findsOneWidget);
  });

  testWidgets('тап по направлению открывает PracticeTopicsScreen',
      (tester) async {
    when(() => repo.loadTracks()).thenAnswer(
      (_) async => [
        _track(
          id: 'analytics',
          title: 'Аналитика',
          grades: [
            _grade(id: 'junior', title: 'Junior', questions: [_q(id: 'a1', topic: 'SQL')]),
          ],
        ),
      ],
    );

    await pumpPractice(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Аналитика'));
    await tester.pumpAndSettle();

    expect(find.byType(PracticeTopicsScreen), findsOneWidget);
  });

  testWidgets('«Тренировка дня» запускает микс (SessionScreen)',
      (tester) async {
    when(() => repo.loadTracks()).thenAnswer(
      (_) async => [
        _track(
          id: 'analytics',
          title: 'Аналитика',
          grades: [
            _grade(id: 'junior', title: 'Junior', questions: [
              _q(id: 'a1', topic: 'SQL'),
              _q(id: 'a2', topic: 'API'),
            ],),
          ],
        ),
      ],
    );
    when(() => progress.practiceMix).thenReturn(['a1', 'a2']);

    await pumpPractice(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Начать'));
    await tester.pumpAndSettle();

    expect(find.byType(SessionScreen), findsOneWidget);
  });

  // === Frame 2: темы внутри направления ====================================
  testWidgets('экран тем: заголовок направления, фильтр грейдов, список тем',
      (tester) async {
    final track = _track(
      id: 'analytics',
      title: 'Аналитика',
      grades: [
        _grade(id: 'junior', title: 'Junior', order: 1, questions: [
          _q(id: 'a1', topic: 'SQL и реляционные БД'),
          _q(id: 'a2', topic: 'SQL и реляционные БД'),
        ],),
        _grade(id: 'middle', title: 'Middle', order: 2, questions: [
          _q(id: 'a3', topic: 'API и интеграции'),
        ],),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: buildLightTheme(),
        home: PracticeTopicsScreen(track: track, progress: progress),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('НАПРАВЛЕНИЕ'), findsOneWidget);
    expect(find.text('Аналитика'), findsOneWidget);
    expect(find.text('ТЕМЫ · 3 ВОПРОСА'), findsOneWidget);
    // Чипы грейдов (есть два грейда с вопросами → фильтр показывается).
    expect(find.text('Все'), findsOneWidget);
    expect(find.text('Junior'), findsOneWidget);
    expect(find.text('Middle'), findsOneWidget);
    // Темы из обоих грейдов.
    expect(find.text('SQL и реляционные БД'), findsOneWidget);
    expect(find.text('API и интеграции'), findsOneWidget);
  });

  testWidgets('фильтр по грейду сужает список тем', (tester) async {
    final track = _track(
      id: 'analytics',
      title: 'Аналитика',
      grades: [
        _grade(id: 'junior', title: 'Junior', order: 1, questions: [
          _q(id: 'a1', topic: 'SQL и реляционные БД'),
        ],),
        _grade(id: 'middle', title: 'Middle', order: 2, questions: [
          _q(id: 'a3', topic: 'API и интеграции'),
        ],),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: buildLightTheme(),
        home: PracticeTopicsScreen(track: track, progress: progress),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Junior'));
    await tester.pumpAndSettle();

    expect(find.text('SQL и реляционные БД'), findsOneWidget);
    expect(find.text('API и интеграции'), findsNothing);
  });

  testWidgets('тап по теме запускает SessionScreen', (tester) async {
    final track = _track(
      id: 'analytics',
      title: 'Аналитика',
      grades: [
        _grade(id: 'junior', title: 'Junior', order: 1, questions: [
          _q(id: 'a1', topic: 'SQL и реляционные БД'),
        ],),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: buildLightTheme(),
        home: PracticeTopicsScreen(track: track, progress: progress),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('SQL и реляционные БД'));
    await tester.pumpAndSettle();

    expect(find.byType(SessionScreen), findsOneWidget);
  });
}
