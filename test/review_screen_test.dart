import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:interview_helper_system/controllers/session_controller.dart';
import 'package:interview_helper_system/models/models.dart';
import 'package:interview_helper_system/screens/review_screen.dart';
import 'package:interview_helper_system/screens/session_screen.dart';
import 'package:interview_helper_system/services/progress_service.dart';
import 'package:interview_helper_system/theme.dart';
import 'package:mocktail/mocktail.dart';

// --- Test double -----------------------------------------------------------
// ReviewScreen.build не трогает ProgressService — сервис лишь прокидывается
// в SessionScreen при тапе «Проработать ошибки». Достаточно пустого мока.
class MockProgressService extends Mock implements ProgressService {}

// --- Builders --------------------------------------------------------------
Question _q({
  required String id,
  required String text,
  required List<String> options,
  required List<int> correct,
  String? explanation,
}) =>
    Question(
      id: id,
      text: text,
      options: options,
      correctIndexes: correct,
      explanation: explanation,
    );

AnsweredQuestion _answer({
  required Question question,
  required Set<int> selected,
  required AnswerOutcome outcome,
}) =>
    AnsweredQuestion(
      question: question,
      selected: selected,
      outcome: outcome,
    );

SessionResult _result(List<AnsweredQuestion> answers) => SessionResult(
      correct: answers.where((a) => a.outcome == AnswerOutcome.correct).length,
      partial: answers.where((a) => a.outcome == AnswerOutcome.partial).length,
      wrong: answers.where((a) => a.outcome == AnswerOutcome.wrong).length,
      points: 0,
      maxPoints: 0,
      answers: answers,
    );

Track _track() =>
    const Track(id: 't1', title: 'Аналитика', order: 0, grades: []);

Grade _grade() =>
    const Grade(id: 'g1', title: 'Junior', order: 0, questions: []);

void main() {
  late MockProgressService progress;

  setUp(() {
    progress = MockProgressService();
  });

  Future<void> pumpReview(
    WidgetTester tester,
    SessionResult result,
  ) {
    return tester.pumpWidget(
      MaterialApp(
        theme: buildLightTheme(),
        home: ReviewScreen(
          result: result,
          track: _track(),
          grade: _grade(),
          progress: progress,
        ),
      ),
    );
  }

  // === Карточки ============================================================
  testWidgets('рендерит по карточке на каждый отвеченный вопрос',
      (tester) async {
    final result = _result([
      _answer(
        question: _q(
            id: 'q1',
            text: 'Что такое нормализация?',
            options: ['A', 'B'],
            correct: [0],),
        selected: {0},
        outcome: AnswerOutcome.correct,
      ),
      _answer(
        question: _q(
            id: 'q2',
            text: 'Что делает GROUP BY?',
            options: ['A', 'B'],
            correct: [1],),
        selected: {0},
        outcome: AnswerOutcome.wrong,
      ),
    ]);

    await pumpReview(tester, result);

    expect(find.text('Что такое нормализация?'), findsOneWidget);
    expect(find.text('Что делает GROUP BY?'), findsOneWidget);
  },);

  // === Поэлементный разбор: одиночный выбор, неверно =======================
  testWidgets(
      'одиночный выбор с ошибкой: правильный → «верно», '
      'выбранный неверный → «лишнее», badge «Неверно»', (tester) async {
    final result = _result([
      _answer(
        question: _q(
            id: 'q1',
            text: 'Вопрос',
            options: ['Правильный', 'Ошибочный'],
            correct: [0],),
        selected: {1},
        outcome: AnswerOutcome.wrong,
      ),
    ]);

    await pumpReview(tester, result);

    expect(find.text('верно'), findsOneWidget);
    expect(find.text('лишнее'), findsOneWidget);
    expect(find.text('Неверно'), findsOneWidget);
    expect(find.text('пропущено'), findsNothing);
  },);

  // === Поэлементный разбор: мультивыбор, частично ==========================
  testWidgets('мультивыбор: все четыре состояния и badge «Частично»',
      (tester) async {
    // correct = {0,1}; выбрано {0,2}.
    // 0: верный+выбран → «верно»; 1: верный+пропущен → «пропущено»;
    // 2: неверный+выбран → «лишнее»; 3: нейтральный → без тега.
    final result = _result([
      _answer(
        question: _q(
          id: 'q1',
          text: 'Вопрос',
          options: ['A', 'B', 'C', 'D'],
          correct: [0, 1],
        ),
        selected: {0, 2},
        outcome: AnswerOutcome.partial,
      ),
    ]);

    await pumpReview(tester, result);

    expect(find.text('верно'), findsOneWidget);
    expect(find.text('пропущено'), findsOneWidget);
    expect(find.text('лишнее'), findsOneWidget);
    expect(find.text('Частично'), findsOneWidget);
    // Нейтральный вариант отрисован, но без тега (всего три тега на карточке).
    expect(find.text('D'), findsOneWidget);
  },);

  // === Поэлементный разбор: одиночный выбор, верно =========================
  testWidgets(
      'верный одиночный ответ: badge «Верно», правильный → «верно», '
      'без «лишнее»/«пропущено»', (tester) async {
    final result = _result([
      _answer(
        question: _q(
            id: 'q1',
            text: 'Вопрос',
            options: ['Правильный', 'Другой'],
            correct: [0],),
        selected: {0},
        outcome: AnswerOutcome.correct,
      ),
    ]);

    await pumpReview(tester, result);

    expect(find.text('Верно'), findsOneWidget);
    expect(find.text('верно'), findsOneWidget);
    expect(find.text('лишнее'), findsNothing);
    expect(find.text('пропущено'), findsNothing);
  },);

  // === Пояснение ===========================================================
  testWidgets('показывает пояснение, когда оно задано', (tester) async {
    final result = _result([
      _answer(
        question: _q(
          id: 'q1',
          text: 'Вопрос',
          options: ['A', 'B'],
          correct: [0],
          explanation: 'Потому что так работает индекс.',
        ),
        selected: {0},
        outcome: AnswerOutcome.correct,
      ),
    ]);

    await pumpReview(tester, result);

    expect(find.text('Потому что так работает индекс.'), findsOneWidget);
  });

  testWidgets('не показывает блок пояснения, когда оно пустое/пробельное',
      (tester) async {
    final result = _result([
      _answer(
        question: _q(
            id: 'q1', text: 'Без пояснения', options: ['A', 'B'], correct: [0],),
        selected: {0},
        outcome: AnswerOutcome.correct,
      ),
      _answer(
        question: _q(
          id: 'q2',
          text: 'Пробельное пояснение',
          options: ['A', 'B'],
          correct: [0],
          explanation: '   ',
        ),
        selected: {0},
        outcome: AnswerOutcome.correct,
      ),
    ]);

    await pumpReview(tester, result);

    // Карточки на месте, но пробельное пояснение не порождает блок.
    expect(find.text('Без пояснения'), findsOneWidget);
    expect(find.text('Пробельное пояснение'), findsOneWidget);
    expect(find.text('   '), findsNothing);
  },);

  // === Нижние кнопки =======================================================
  testWidgets(
      'при наличии ошибок кнопка активна и подписана '
      '«Проработать ошибки»', (tester) async {
    final result = _result([
      _answer(
        question:
            _q(id: 'q1', text: 'Вопрос', options: ['A', 'B'], correct: [0]),
        selected: {1},
        outcome: AnswerOutcome.wrong,
      ),
    ]);

    await pumpReview(tester, result);

    expect(find.text('Проработать ошибки'), findsOneWidget);
    expect(find.text('Ошибок нет'), findsNothing);

    final button = tester.widget<OutlinedButton>(find.byType(OutlinedButton));
    expect(button.onPressed, isNotNull);
  },);

  testWidgets('partial считается ошибкой: кнопка «Проработать ошибки» активна',
      (tester) async {
    final result = _result([
      _answer(
        question: _q(
            id: 'q1',
            text: 'Вопрос',
            options: ['A', 'B', 'C'],
            correct: [0, 1],),
        selected: {0},
        outcome: AnswerOutcome.partial,
      ),
    ]);

    await pumpReview(tester, result);

    expect(find.text('Проработать ошибки'), findsOneWidget);
    final button = tester.widget<OutlinedButton>(find.byType(OutlinedButton));
    expect(button.onPressed, isNotNull);
  },);

  testWidgets('когда всё верно — кнопка «Ошибок нет» и она неактивна',
      (tester) async {
    final result = _result([
      _answer(
        question:
            _q(id: 'q1', text: 'Вопрос', options: ['A', 'B'], correct: [0]),
        selected: {0},
        outcome: AnswerOutcome.correct,
      ),
    ]);

    await pumpReview(tester, result);

    expect(find.text('Ошибок нет'), findsOneWidget);
    expect(find.text('Проработать ошибки'), findsNothing);

    final button = tester.widget<OutlinedButton>(find.byType(OutlinedButton));
    expect(button.onPressed, isNull);
  },);

  // === Навигация ===========================================================
  testWidgets('«Проработать ошибки» открывает SessionScreen только с ошибками',
      (tester) async {
    final result = _result([
      _answer(
        question: _q(
            id: 'q1', text: 'ВЕРНЫЙ ВОПРОС', options: ['A', 'B'], correct: [0],),
        selected: {0},
        outcome: AnswerOutcome.correct,
      ),
      _answer(
        question: _q(
            id: 'q2',
            text: 'ОШИБОЧНЫЙ ВОПРОС',
            options: ['A', 'B'],
            correct: [1],),
        selected: {0},
        outcome: AnswerOutcome.wrong,
      ),
    ]);

    await pumpReview(tester, result);

    await tester.tap(find.text('Проработать ошибки'));
    await tester.pumpAndSettle();

    expect(find.byType(SessionScreen), findsOneWidget);
    // В сессию попал только ошибочный вопрос.
    expect(find.text('ОШИБОЧНЫЙ ВОПРОС'), findsOneWidget);
    expect(find.text('ВЕРНЫЙ ВОПРОС'), findsNothing);
    expect(tester.takeException(), isNull);
  },);

  testWidgets('«В меню» возвращает к первому маршруту (popUntil isFirst)',
      (tester) async {
    final result = _result([
      _answer(
        question:
            _q(id: 'q1', text: 'Вопрос', options: ['A', 'B'], correct: [0]),
        selected: {0},
        outcome: AnswerOutcome.correct,
      ),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildLightTheme(),
        home: Scaffold(
          body: Builder(
            builder: (ctx) => Center(
              child: ElevatedButton(
                onPressed: () => Navigator.of(ctx).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ReviewScreen(
                      result: result,
                      track: _track(),
                      grade: _grade(),
                      progress: progress,
                    ),
                  ),
                ),
                child: const Text('ГЛАВНАЯ'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('ГЛАВНАЯ'));
    await tester.pumpAndSettle();
    expect(find.text('Разбор ответов'), findsOneWidget);

    await tester.tap(find.text('В меню'));
    await tester.pumpAndSettle();

    expect(find.text('Разбор ответов'), findsNothing);
    expect(find.text('ГЛАВНАЯ'), findsOneWidget);
  },);
}
