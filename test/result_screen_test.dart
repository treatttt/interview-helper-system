import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:interview_helper_system/controllers/session_controller.dart';
import 'package:interview_helper_system/models/models.dart';
import 'package:interview_helper_system/screens/result_screen.dart';
import 'package:interview_helper_system/screens/review_screen.dart';
import 'package:interview_helper_system/services/progress_service.dart';
import 'package:interview_helper_system/theme.dart';
import 'package:mocktail/mocktail.dart';

// ResultScreen.build не обращается к ProgressService — он лишь прокидывается
// дальше в ReviewScreen. Достаточно объекта без настроенных ответов.
class MockProgressService extends Mock implements ProgressService {}

// --- Builders --------------------------------------------------------------
AnsweredQuestion _answer() => const AnsweredQuestion(
      question: Question(
        id: 'q1',
        text: 'Вопрос',
        options: ['A', 'B'],
        correctIndexes: [0],
      ),
      selected: {0},
      outcome: AnswerOutcome.correct,
    );

SessionResult _result({
  int correct = 0,
  int partial = 0,
  int wrong = 0,
  int points = 0,
  int maxPoints = 0,
  List<AnsweredQuestion> answers = const [],
}) =>
    SessionResult(
      correct: correct,
      partial: partial,
      wrong: wrong,
      points: points,
      maxPoints: maxPoints,
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

  Future<void> pumpResult(WidgetTester tester, SessionResult result) {
    return tester.pumpWidget(
      MaterialApp(
        theme: buildLightTheme(),
        home: ResultScreen(
          result: result,
          track: _track(),
          grade: _grade(),
          progress: progress,
        ),
      ),
    );
  }

  // === Очки и процент ======================================================
  testWidgets('показывает баллы и округлённый процент', (tester) async {
    await pumpResult(tester, _result(points: 3, maxPoints: 4));

    expect(find.text('3 из 4 баллов'), findsOneWidget);
    expect(find.text('75%'), findsOneWidget);
  });

  testWidgets('при maxPoints == 0 процент равен 0% и нет краша',
      (tester) async {
    await pumpResult(tester, _result());

    expect(find.text('0 из 0 баллов'), findsOneWidget);
    expect(find.text('0%'), findsOneWidget);
    expect(tester.takeException(), isNull);
  },);

  // === Строки статистики ===================================================
  testWidgets('показывает счётчики верно/частично/неверно', (tester) async {
    await pumpResult(
      tester,
      _result(correct: 5, partial: 2, wrong: 1, points: 4, maxPoints: 8),
    );

    expect(find.text('Верно'), findsOneWidget);
    expect(find.text('Частично'), findsOneWidget);
    expect(find.text('Неверно'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
  });

  // === Навигация ===========================================================
  testWidgets('«Разбор ответов» открывает ReviewScreen', (tester) async {
    await pumpResult(
      tester,
      _result(correct: 1, points: 1, maxPoints: 1, answers: [_answer()]),
    );

    await tester.tap(find.text('Разбор ответов'));
    await tester.pumpAndSettle();

    expect(find.byType(ReviewScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('«На главный экран» возвращает к первому маршруту',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildLightTheme(),
        home: Scaffold(
          body: Builder(
            builder: (ctx) => Center(
              child: ElevatedButton(
                onPressed: () => Navigator.of(ctx).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ResultScreen(
                      result: _result(points: 1, maxPoints: 1),
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
    expect(find.text('Результат'), findsOneWidget);

    await tester.tap(find.text('На главный экран'));
    await tester.pumpAndSettle();

    expect(find.text('Результат'), findsNothing);
    expect(find.text('ГЛАВНАЯ'), findsOneWidget);
  },);
}
