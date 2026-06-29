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
    when(() => progress.streak).thenReturn(0);
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
        // Экран результата (его пушит pushReplacement) крутит бесконечную волну —
        // гасим анимации во всех маршрутах, иначе pumpAndSettle не сходится.
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
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

  // === Окно неверного ответа: «Неверно», правильный ответ без креста ========
  testWidgets(
    'неверный ответ → «Неверно», правильные варианты в рамке, чужие скрыты',
    (tester) async {
      const q = Question(
        id: 'q1',
        text: 'Мультивопрос',
        options: ['A', 'B', 'C', 'D'],
        correctIndexes: [0, 1],
        explanation: 'Пояснение к ответу',
      );

      await pumpSession(tester, questions: [q]);

      // Выбор: A (верный) и C (неверный) → исход partial → «Неверно».
      await tester.tap(find.text('A'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('C'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ответить'));
      await tester.pumpAndSettle();

      expect(find.text('Неверно'), findsOneWidget);
      expect(find.text('Верно'), findsNothing);
      expect(find.text('+10 XP'), findsNothing);
      // Пояснение под «Почему».
      expect(find.text('Почему'), findsOneWidget);
      expect(find.text('Пояснение к ответу'), findsOneWidget);
      // В рамке только правильные ответы (A, B); чужие варианты не показываются.
      expect(find.text('A'), findsOneWidget);
      expect(find.text('B'), findsOneWidget);
      expect(find.text('C'), findsNothing);
      expect(find.text('D'), findsNothing);
      // Крест (✗) — только в бейдже «Неверно»; в рамках правильных ответов
      // стоят галочки (по одной на каждый верный вариант), без крестов.
      expect(find.byIcon(Icons.cancel), findsOneWidget);
      expect(find.byIcon(Icons.check), findsNWidgets(2));
    },
  );

  // === Окно верного ответа: «Верно» + «+10 XP» + «Важно знать» ==============
  testWidgets(
    'верный ответ → «Верно», «+10 XP» и блок «Важно знать» из данных',
    (tester) async {
      const q = Question(
        id: 'q1',
        text: 'Вопрос',
        options: ['A', 'B'],
        correctIndexes: [0],
        explanation: 'Потому что A',
        importantToKnow: ['Смежный факт 1', 'Смежный факт 2'],
        mustRepeat: ['Это не должно показаться'],
      );

      await pumpSession(tester, questions: [q]);

      await tester.tap(find.text('A'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ответить'));
      await tester.pumpAndSettle();

      expect(find.text('Верно'), findsOneWidget);
      expect(find.text('+10 XP'), findsOneWidget);
      expect(find.text('Неверно'), findsNothing);
      // Блок «Важно знать» из данных вопроса (не хардкод).
      expect(find.text('Важно знать'), findsOneWidget);
      expect(find.text('Смежный факт 1'), findsOneWidget);
      expect(find.text('Смежный факт 2'), findsOneWidget);
      // «Нужно повторить» не показывается при верном ответе.
      expect(find.text('Нужно повторить'), findsNothing);
      expect(find.text('Это не должно показаться'), findsNothing);
    },
  );

  // === Неверный ответ показывает «Нужно повторить» из данных ================
  testWidgets(
    'неверный ответ → блок «Нужно повторить» из данных вопроса',
    (tester) async {
      const q = Question(
        id: 'q1',
        text: 'Вопрос',
        options: ['A', 'B'],
        correctIndexes: [0],
        importantToKnow: ['Это не должно показаться'],
        mustRepeat: ['Повтори тему X', 'Повтори тему Y'],
      );

      await pumpSession(tester, questions: [q]);

      // Выбираем неверный B.
      await tester.tap(find.text('B'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ответить'));
      await tester.pumpAndSettle();

      expect(find.text('Неверно'), findsOneWidget);
      expect(find.text('Нужно повторить'), findsOneWidget);
      expect(find.text('Повтори тему X'), findsOneWidget);
      expect(find.text('Повтори тему Y'), findsOneWidget);
      expect(find.text('Важно знать'), findsNothing);
    },
  );
}
