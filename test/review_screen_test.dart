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
  List<String>? importantToKnow,
}) =>
    Question(
      id: id,
      text: text,
      options: options,
      correctIndexes: correct,
      explanation: explanation,
      importantToKnow: importantToKnow,
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

  // === Список ошибок =======================================================
  testWidgets('показывает только неверные ответы, верные скрыты',
      (tester) async {
    final result = _result([
      _answer(
        question: _q(
          id: 'q1',
          text: 'ВЕРНЫЙ ВОПРОС',
          options: ['A', 'B'],
          correct: [0],
        ),
        selected: {0},
        outcome: AnswerOutcome.correct,
      ),
      _answer(
        question: _q(
          id: 'q2',
          text: 'ОШИБОЧНЫЙ ВОПРОС',
          options: ['A', 'B'],
          correct: [1],
        ),
        selected: {0},
        outcome: AnswerOutcome.wrong,
      ),
    ]);

    await pumpReview(tester, result);

    expect(find.text('ОШИБОЧНЫЙ ВОПРОС'), findsOneWidget);
    expect(find.text('ВЕРНЫЙ ВОПРОС'), findsNothing);
  });

  testWidgets('partial считается ошибкой и попадает в список', (tester) async {
    final result = _result([
      _answer(
        question: _q(
          id: 'q1',
          text: 'ЧАСТИЧНЫЙ ВОПРОС',
          options: ['A', 'B', 'C'],
          correct: [0, 1],
        ),
        selected: {0},
        outcome: AnswerOutcome.partial,
      ),
    ]);

    await pumpReview(tester, result);

    expect(find.text('ЧАСТИЧНЫЙ ВОПРОС'), findsOneWidget);
  });

  // === Сворачивание / разворачивание =======================================
  testWidgets('карточка свёрнута по умолчанию: разбор скрыт', (tester) async {
    final result = _result([
      _answer(
        question: _q(
          id: 'q1',
          text: 'Вопрос',
          options: ['Правильный вариант', 'Ошибочный'],
          correct: [0],
          explanation: 'Потому что так устроен индекс.',
        ),
        selected: {1},
        outcome: AnswerOutcome.wrong,
      ),
    ]);

    await pumpReview(tester, result);

    expect(find.text('Вопрос'), findsOneWidget);
    // До тапа разбор не показан.
    expect(find.text('ПРАВИЛЬНЫЙ ОТВЕТ'), findsNothing);
    expect(find.text('Правильный вариант'), findsNothing);
    expect(find.text('ПОЧЕМУ'), findsNothing);
    expect(find.text('Потому что так устроен индекс.'), findsNothing);
  });

  testWidgets(
      'тап разворачивает карточку: правильный ответ, «Почему» и смежные '
      'знания — без навигации', (tester) async {
    final result = _result([
      _answer(
        question: _q(
          id: 'q1',
          text: 'Вопрос',
          options: ['Правильный вариант', 'Ошибочный'],
          correct: [0],
          explanation: 'Потому что так устроен индекс.',
          importantToKnow: ['JOIN объединяет таблицы', 'LIMIT режет строки'],
        ),
        selected: {1},
        outcome: AnswerOutcome.wrong,
      ),
    ]);

    await pumpReview(tester, result);

    await tester.tap(find.text('Вопрос'));
    await tester.pumpAndSettle();

    expect(find.text('ПРАВИЛЬНЫЙ ОТВЕТ'), findsOneWidget);
    expect(find.text('Правильный вариант'), findsOneWidget);
    expect(find.text('ПОЧЕМУ'), findsOneWidget);
    expect(find.text('Потому что так устроен индекс.'), findsOneWidget);
    expect(find.text('ЧТО ЕЩЁ ВАЖНО ЗНАТЬ'), findsOneWidget);
    expect(find.text('JOIN объединяет таблицы'), findsOneWidget);
    expect(find.text('LIMIT режет строки'), findsOneWidget);
    // Остаёмся на том же экране — навигации не было.
    expect(find.byType(ReviewScreen), findsOneWidget);
    expect(find.byType(SessionScreen), findsNothing);
  });

  testWidgets('повторный тап сворачивает карточку обратно', (tester) async {
    final result = _result([
      _answer(
        question: _q(
          id: 'q1',
          text: 'Вопрос',
          options: ['Правильный вариант', 'Ошибочный'],
          correct: [0],
          explanation: 'Объяснение.',
        ),
        selected: {1},
        outcome: AnswerOutcome.wrong,
      ),
    ]);

    await pumpReview(tester, result);

    await tester.tap(find.text('Вопрос'));
    await tester.pumpAndSettle();
    expect(find.text('Объяснение.'), findsOneWidget);

    await tester.tap(find.text('Вопрос'));
    await tester.pumpAndSettle();
    expect(find.text('Объяснение.'), findsNothing);
  });

  testWidgets('без пояснения и смежных знаний разворот не падает и не '
      'показывает их секции', (tester) async {
    final result = _result([
      _answer(
        question: _q(
          id: 'q1',
          text: 'Вопрос',
          options: ['Правильный', 'Ошибочный'],
          correct: [0],
        ),
        selected: {1},
        outcome: AnswerOutcome.wrong,
      ),
    ]);

    await pumpReview(tester, result);

    await tester.tap(find.text('Вопрос'));
    await tester.pumpAndSettle();

    expect(find.text('ПРАВИЛЬНЫЙ ОТВЕТ'), findsOneWidget);
    expect(find.text('ПОЧЕМУ'), findsNothing);
    expect(find.text('ЧТО ЕЩЁ ВАЖНО ЗНАТЬ'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  // === Пустое состояние ====================================================
  testWidgets('когда всё верно — пустое состояние и кнопка «Ошибок нет»',
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
  });

  // === Нижние кнопки =======================================================
  testWidgets('при наличии ошибок кнопка активна и подписана «Проработать '
      'ошибки»', (tester) async {
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
  });

  // === Навигация ===========================================================
  testWidgets('«Проработать ошибки» открывает SessionScreen только с ошибками',
      (tester) async {
    final result = _result([
      _answer(
        question: _q(
          id: 'q1',
          text: 'ВЕРНЫЙ ВОПРОС',
          options: ['A', 'B'],
          correct: [0],
        ),
        selected: {0},
        outcome: AnswerOutcome.correct,
      ),
      _answer(
        question: _q(
          id: 'q2',
          text: 'ОШИБОЧНЫЙ ВОПРОС',
          options: ['A', 'B'],
          correct: [1],
        ),
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
  });

  testWidgets('«В меню» возвращает к первому маршруту (popUntil isFirst)',
      (tester) async {
    final result = _result([
      _answer(
        question:
            _q(id: 'q1', text: 'Вопрос', options: ['A', 'B'], correct: [1]),
        selected: {0},
        outcome: AnswerOutcome.wrong,
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
  });
}
