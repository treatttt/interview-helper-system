import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:interview_helper_system/controllers/session_controller.dart';
import 'package:interview_helper_system/models/models.dart';
import 'package:interview_helper_system/screens/result_screen.dart';
import 'package:interview_helper_system/screens/review_screen.dart';
import 'package:interview_helper_system/services/progress_service.dart';
import 'package:interview_helper_system/theme.dart';
import 'package:mocktail/mocktail.dart';

// ResultScreen читает у прогресса только streak (для метрики «серия дней») и
// прокидывает сервис в ReviewScreen. Достаточно застабить streak.
class MockProgressService extends Mock implements ProgressService {}

// --- Builders --------------------------------------------------------------
AnsweredQuestion _answer({
  String topic = 'SQL',
  AnswerOutcome outcome = AnswerOutcome.correct,
}) =>
    AnsweredQuestion(
      question: Question(
        id: 'q-$topic-${outcome.name}',
        text: 'Вопрос',
        options: const ['A', 'B'],
        correctIndexes: const [0],
        topic: topic,
      ),
      selected: const {0},
      outcome: outcome,
    );

SessionResult _result({
  int correct = 0,
  int partial = 0,
  int wrong = 0,
  List<AnsweredQuestion> answers = const [],
  Map<String, int> correctXp = const {},
}) =>
    SessionResult(
      correct: correct,
      partial: partial,
      wrong: wrong,
      points: correct,
      maxPoints: correct + partial + wrong,
      answers: answers,
      correctXp: correctXp,
    );

Track _track() =>
    const Track(id: 't1', title: 'Аналитика', order: 0, grades: []);

Grade _grade() =>
    const Grade(id: 'g1', title: 'Junior', order: 0, questions: []);

void main() {
  late MockProgressService progress;

  setUp(() {
    progress = MockProgressService();
    when(() => progress.streak).thenReturn(2);
  });

  Future<void> pumpResult(
    WidgetTester tester,
    SessionResult result, {
    Duration? elapsed,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        theme: buildLightTheme(),
        // Гасим бесконечную волну во всех маршрутах, чтобы pumpAndSettle не завис.
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(disableAnimations: true),
          child: child!,
        ),
        home: ResultScreen(
          result: result,
          track: _track(),
          grade: _grade(),
          progress: progress,
          elapsed: elapsed,
        ),
      ),
    );
  }

  // === Процент и «X из Y» в круге ==========================================
  testWidgets('круг показывает процент верных и «X из Y»', (tester) async {
    // 3 верно из 4 → 75%.
    await pumpResult(
      tester,
      _result(correct: 3, wrong: 1),
    );

    expect(find.text('75%'), findsOneWidget);
    expect(find.text('3 из 4'), findsOneWidget);
  });

  testWidgets('пустая сессия → 0% без краша', (tester) async {
    await pumpResult(tester, _result());
    expect(find.text('0%'), findsOneWidget);
    expect(find.text('0 из 0'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  // === Похвала по порогам ==================================================
  testWidgets('похвала зависит от процента верных', (tester) async {
    await pumpResult(tester, _result(correct: 1, wrong: 1)); // 50%
    expect(find.text('Неплохой результат'), findsOneWidget);
  });

  testWidgets('меньше 50% → «подготовиться лучше»', (tester) async {
    await pumpResult(tester, _result(correct: 1, wrong: 3)); // 25%
    expect(find.text('Тебе нужно подготовиться лучше'), findsOneWidget);
  });

  testWidgets('90%+ → «Отличный результат»', (tester) async {
    await pumpResult(tester, _result(correct: 10)); // 100%
    expect(find.text('Отличный результат'), findsOneWidget);
  });

  // === Легенда верно/частично/неверно ======================================
  testWidgets('легенда показывает счётчики', (tester) async {
    await pumpResult(tester, _result(correct: 5, partial: 2, wrong: 1));
    expect(find.text('Верно 5'), findsOneWidget);
    expect(find.text('Частично 2'), findsOneWidget);
    expect(find.text('Неверно 1'), findsOneWidget);
  });

  // === Метрики ==============================================================
  testWidgets('XP считается из наград вопросов, не хардкод', (tester) async {
    await pumpResult(
      tester,
      _result(correct: 2, correctXp: const {'a': 15, 'b': 25}),
    );
    expect(find.text('+40'), findsOneWidget); // 15 + 25
    expect(find.text('2'), findsOneWidget); // серия дней
  });

  testWidgets('метрика времени появляется только с elapsed', (tester) async {
    await pumpResult(
      tester,
      _result(correct: 1),
      elapsed: const Duration(minutes: 9),
    );
    expect(find.text('9 мин'), findsOneWidget);
    expect(find.text('в сессии'), findsOneWidget);
  });

  // === «Стоит повторить» ===================================================
  testWidgets('слабые темы сессии показаны с процентом', (tester) async {
    // Круг считает 3/4 = 75%, тема «Подзапросы» — 1/2 = 50%: проценты различны,
    // поэтому «50%» однозначно относится к теме.
    await pumpResult(
      tester,
      _result(
        correct: 3,
        wrong: 1,
        answers: [
          _answer(topic: 'Подзапросы'),
          _answer(topic: 'Подзапросы', outcome: AnswerOutcome.wrong),
        ],
      ),
    );

    expect(find.text('Стоит повторить'), findsOneWidget);
    expect(find.text('Подзапросы'), findsOneWidget);
    expect(find.text('75%'), findsOneWidget); // круг
    expect(find.text('50%'), findsOneWidget); // тема: 1 из 2
  });

  testWidgets('без ошибок по темам блок «Стоит повторить» скрыт',
      (tester) async {
    await pumpResult(
      tester,
      _result(correct: 1, answers: [_answer(topic: 'Индексы')]),
    );
    expect(find.text('Стоит повторить'), findsNothing);
  });

  // === Навигация ===========================================================
  testWidgets('«Разбор ошибок» открывает ReviewScreen', (tester) async {
    await pumpResult(
      tester,
      _result(correct: 1, answers: [_answer()]),
    );

    await tester.tap(find.text('Разбор ошибок'));
    await tester.pumpAndSettle();

    expect(find.byType(ReviewScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('«Продолжить» возвращает к первому маршруту', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildLightTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: Scaffold(
          body: Builder(
            builder: (ctx) => Center(
              child: ElevatedButton(
                onPressed: () => Navigator.of(ctx).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ResultScreen(
                      result: _result(correct: 1),
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
    expect(find.text('Сессия завершена'), findsOneWidget);

    await tester.tap(find.text('Продолжить'));
    await tester.pumpAndSettle();

    expect(find.text('Сессия завершена'), findsNothing);
    expect(find.text('ГЛАВНАЯ'), findsOneWidget);
  });
}
