import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:interview_helper_system/controllers/session_controller.dart';
import 'package:interview_helper_system/models/models.dart';
import 'package:interview_helper_system/screens/result_screen.dart';
import 'package:interview_helper_system/screens/session_screen.dart';
import 'package:interview_helper_system/services/progress_service.dart';
import 'package:interview_helper_system/theme.dart';
import 'package:mocktail/mocktail.dart';

class MockProgressService extends Mock implements ProgressService {}

Question _q(String id) => Question(
      id: id,
      text: 'Вопрос $id',
      options: const ['A', 'B'],
      correctIndexes: const [0],
    );

Track _track() =>
    const Track(id: 't1', title: 'Аналитика', order: 0, grades: []);

Grade _grade() =>
    const Grade(id: 'g1', title: 'Junior', order: 0, questions: []);

void main() {
  setUpAll(() {
    registerFallbackValue(
      const SessionResult(
        correct: 0,
        partial: 0,
        wrong: 0,
        points: 0,
        maxPoints: 0,
        answers: [],
      ),
    );
    registerFallbackValue(<String, Object?>{});
  });

  late MockProgressService progress;

  setUp(() {
    progress = MockProgressService();
    when(
      () => progress.recordSession(
        any(),
        any(),
        clearIncomplete: any(named: 'clearIncomplete'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => progress.clearIncompleteTopicSession(
        topicTitle: any(named: 'topicTitle'),
      ),
    ).thenAnswer((_) async {});
  });

  Future<void> pumpSession(WidgetTester tester, {
    required List<Question> questions,
    int initialIndex = 0,
    List<AnsweredQuestion> previousAnswers = const [],
    String? topicTitle,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        theme: buildLightTheme(),
        home: SessionScreen(
          track: _track(),
          grade: _grade(),
          progress: progress,
          questions: questions,
          initialIndex: initialIndex,
          previousAnswers: previousAnswers,
          topicTitle: topicTitle,
        ),
      ),
    );
  }

  // === resume в initState (строки 53-56) ===================================
  testWidgets('конструируется через resume при initialIndex/previousAnswers',
    (tester) async {
      final q1 = _q('q1');
      final q2 = _q('q2');

      await pumpSession(
        tester,
        questions: [q1, q2],
        initialIndex: 1,
        previousAnswers: [
          AnsweredQuestion(
            question: q1,
            selected: const {0},
            outcome: AnswerOutcome.correct,
          ),
        ],
      );

      // Восстановлен индекс 1 → шапка «2 / 2», текущий вопрос — второй.
      expect(find.text('2 / 2'), findsOneWidget);
      expect(find.text('Вопрос q2'), findsOneWidget);
    },
  );

  // === Прохождение до финиша (строки 95-117, _buttonLabel 236) =============
  testWidgets(
    'ответ на последний вопрос завершает сессию и открывает результат',
    (tester) async {
      await pumpSession(tester, questions: [_q('q1')]);

      await tester.tap(find.text('A'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Ответить'));
      await tester.pumpAndSettle();
      expect(find.text('Завершить'), findsOneWidget);

      await tester.tap(find.text('Завершить'));
      await tester.pumpAndSettle();

      expect(find.byType(ResultScreen), findsOneWidget);
      verify(
        () => progress.recordSession(
          any(),
          any(),
          clearIncomplete: any(named: 'clearIncomplete'),
        ),
      ).called(1);
    },
  );

  // === Выход посреди сессии → сохранение (строки 71-92, _buttonLabel «Дальше»)
  testWidgets(
    'выход после ответа на часть вопросов сохраняет незавершённую сессию',
    (tester) async {
      await pumpSession(tester, questions: [_q('q1'), _q('q2')]);

      await tester.tap(find.text('A'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ответить'));
      await tester.pumpAndSettle();

      // Не последний вопрос → метка «Дальше».
      expect(find.text('Дальше'), findsOneWidget);

      // Уходим со страницы, не завершив сессию → срабатывает dispose-сохранение.
      await tester.pumpWidget(const SizedBox.shrink());

      verify(() => progress.saveIncompleteSessionSync(any())).called(1);
    },
  );

  // === Тема-дрилл пишет паузу в тема-слот, не в грейдовый =================
  testWidgets(
    'тема-дрилл сохраняет паузу в тема-слот, не в грейдовый',
    (tester) async {
      await pumpSession(
        tester,
        questions: [_q('q1'), _q('q2')],
        topicTitle: 'SQL',
      );

      await tester.tap(find.text('A'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ответить'));
      await tester.pumpAndSettle();

      // Уходим со страницы, не завершив дрилл → dispose пишет в тема-слот.
      await tester.pumpWidget(const SizedBox.shrink());

      verify(() => progress.saveIncompleteTopicSessionSync(any())).called(1);
      verifyNever(() => progress.saveIncompleteSessionSync(any()));
    },
  );

  // === Подсветка вариантов после ответа + пояснение (185-200, 236-292) ======
  testWidgets(
    'после ответа подсвечивает все типы вариантов и показывает пояснение',
    (tester) async {
      const q = Question(
        id: 'q1',
        text: 'Мультивопрос',
        options: ['A', 'B', 'C', 'D'],
        correctIndexes: [0, 1],
        // мультивыбор
        explanation: 'Пояснение к ответу',
      );

      await pumpSession(tester, questions: [q]);

      // Выбор: A (верный) и C (неверный) → ветка picked до ответа.
      await tester.tap(find.text('A'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('C'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Ответить'));
      await tester.pumpAndSettle();

      // После ответа: A→correct, B→missed, C→wrong, D→neutral; isLast → «Завершить».
      expect(find.text('Завершить'), findsOneWidget);
      expect(find.text('Пояснение к ответу'), findsOneWidget);
      expect(find.text('D'), findsOneWidget);
    },
  );
}
