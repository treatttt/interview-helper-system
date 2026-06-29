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
  String? category,
}) =>
    Track(id: id, title: title, order: order, grades: grades, category: category);

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
    when(() => progress.answeredToday).thenReturn(0);
    when(() => progress.masteredIds(any(), any())).thenReturn(<String>{});
    when(() => progress.incompleteSession).thenReturn(null);
    when(() => progress.incompleteTopicSession).thenReturn(null);
    when(() => progress.loadIncompleteSession(any())).thenReturn(null);
    when(() => progress.loadIncompleteTopicSession(any())).thenReturn(null);
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
        home: HomeScreen(
          repository: repo,
          progress: progress,
          // Детерминированная дата для шапки.
          clock: () => DateTime(2026, 6, 29),
        ),
      ),
    );
  }

  // === Шапка ================================================================
  testWidgets('шапка показывает дату, заголовок «Главная» и серию',
      (tester) async {
    when(() => progress.streak).thenReturn(3);
    when(() => repo.loadTracks()).thenAnswer((_) async => <Track>[]);

    await pumpHome(tester);
    await tester.pumpAndSettle();

    expect(find.text('Главная'), findsOneWidget);
    expect(find.text('ПОНЕДЕЛЬНИК, 29 ИЮНЯ'), findsOneWidget);
    expect(find.text('3'), findsOneWidget); // значок серии
  });

  // === Ошибка + повтор ======================================================
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
    },
  );

  // === Карточка «Начать»: свежий старт рекомендованной сессии ===============
  testWidgets('карточка «Начать» запускает SessionScreen для рекомендации',
      (tester) async {
    when(() => repo.loadTracks()).thenAnswer(
      (_) async => [
        _track(
          id: 'analytics',
          title: 'Аналитика',
          grades: [
            _grade(
              id: 'junior',
              title: 'Junior',
              questions: [_q(id: 'q1', topic: 'SQL')],
            ),
          ],
        ),
      ],
    );

    await pumpHome(tester);
    await tester.pumpAndSettle();

    // Заголовок карточки — тема первого непройденного вопроса.
    expect(find.text('SQL'), findsOneWidget);
    expect(find.text('Аналитика · Junior'), findsOneWidget);
    expect(find.text('Вопрос 0 / 1'), findsOneWidget);

    await tester.tap(find.text('Начать'));
    await tester.pumpAndSettle();

    expect(find.byType(SessionScreen), findsOneWidget);
  });

  // === Карточка «Продолжить»: резюм грейдовой паузы =========================
  testWidgets('карточка «Продолжить» возобновляет сохранённую сессию',
      (tester) async {
    when(() => repo.loadTracks()).thenAnswer(
      (_) async => [
        _track(
          id: 'analytics',
          title: 'Аналитика',
          grades: [
            _grade(
              id: 'junior',
              title: 'Junior',
              questions: [
                _q(id: 'q1', topic: 'SQL'),
                _q(id: 'q2', topic: 'SQL'),
              ],
            ),
          ],
        ),
      ],
    );
    when(() => progress.incompleteSession).thenReturn(<String, Object?>{
      'gradeKey': 'analytics_junior',
      'questionIds': ['q1', 'q2'],
      'currentIndex': 1,
      'answeredData': [
        {'id': 'q1', 'selected': [0], 'outcome': 'correct'},
      ],
    });

    await pumpHome(tester);
    await tester.pumpAndSettle();

    expect(find.text('ПРОДОЛЖИТЬ'), findsOneWidget);
    expect(find.text('Вопрос 2 / 2'), findsOneWidget);

    await tester.tap(find.text('Продолжить'));
    await tester.pumpAndSettle();

    expect(find.byType(SessionScreen), findsOneWidget);
  });

  // === Дневная цель =========================================================
  testWidgets('карточка дневной цели показывает прогресс и остаток',
      (tester) async {
    when(() => progress.answeredToday).thenReturn(6);
    when(() => repo.loadTracks()).thenAnswer((_) async => <Track>[]);

    await pumpHome(tester);
    await tester.pumpAndSettle();

    expect(find.text('Ежедневная цель'), findsOneWidget);
    expect(find.text('6/10'), findsOneWidget);
    expect(find.text('Ещё 4 вопроса до цели дня'), findsOneWidget);
  });

  // === Направления: тап открывает грейды ====================================
  testWidgets('тап по направлению открывает GradesScreen', (tester) async {
    when(() => repo.loadTracks()).thenAnswer(
      (_) async => [
        _track(
          id: 'analytics',
          title: 'Аналитика',
          grades: [
            _grade(id: 'junior', title: 'Junior', questions: [_q(id: 'q1')]),
          ],
        ),
      ],
    );

    await pumpHome(tester);
    await tester.pumpAndSettle();

    expect(find.text('ВАШИ НАПРАВЛЕНИЯ'), findsOneWidget);
    // «Аналитика» встречается дважды: в карточке и в списке направлений.
    await tester.tap(find.text('Аналитика').last);
    await tester.pumpAndSettle();

    expect(find.byType(GradesScreen), findsOneWidget);
  });

  // === Разбиение направлений: начатые → «ваши», прочие → «другие» ===========
  testWidgets('начатые направления попадают в «ваши», прочие — в «другие»',
      (tester) async {
    when(() => repo.loadTracks()).thenAnswer(
      (_) async => [
        _track(
          id: 'analytics',
          title: 'Аналитика',
          grades: [
            _grade(id: 'junior', title: 'Junior', questions: [_q(id: 'q1')]),
          ],
        ),
        _track(
          id: 'testing',
          title: 'Тестирование',
          order: 1,
          grades: [
            _grade(id: 'junior', title: 'Junior', questions: [_q(id: 'q2')]),
          ],
        ),
      ],
    );
    // Аналитика начата (есть освоенный вопрос), Тестирование — нет.
    when(() => progress.masteredIds('analytics', 'junior'))
        .thenReturn({'q1'});

    await pumpHome(tester);
    await tester.pumpAndSettle();

    expect(find.text('ВАШИ НАПРАВЛЕНИЯ'), findsOneWidget);
    expect(find.text('ДРУГИЕ НАПРАВЛЕНИЯ'), findsOneWidget);
  });

  // === Языковые треки скрыты =================================================
  testWidgets('трек с category language не отображается среди направлений',
      (tester) async {
    when(() => repo.loadTracks()).thenAnswer(
      (_) async => [
        _track(
          id: 'analytics',
          title: 'Аналитика',
          grades: [
            _grade(id: 'junior', title: 'Junior', questions: [_q(id: 'q1')]),
          ],
        ),
        _track(id: 'go', title: 'Go', order: 1, category: 'language'),
      ],
    );

    await pumpHome(tester);
    await tester.pumpAndSettle();

    expect(find.text('Go'), findsNothing);
  });

  // === Трек без валидных вопросов помечен «Скоро» и не открывает грейды ======
  testWidgets('трек без валидных вопросов показывает «Скоро»', (tester) async {
    when(() => repo.loadTracks()).thenAnswer(
      (_) async => [
        _track(
          id: 'analytics',
          title: 'Аналитика',
          grades: [_grade(id: 'junior', title: 'Junior')],
        ),
      ],
    );

    await pumpHome(tester);
    await tester.pumpAndSettle();

    expect(find.text('Скоро'), findsOneWidget);

    await tester.tap(find.text('Аналитика').last);
    await tester.pumpAndSettle();

    expect(find.byType(GradesScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
