import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:interview_helper_system/models/models.dart';
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
  late MockProgressService progress;

  setUp(() {
    progress = MockProgressService();
  });

  Future<void> pumpSession(
    WidgetTester tester, {
    required List<Question> questions,
    bool reduceMotion = false,
  }) {
    final screen = SessionScreen(
      track: _track(),
      grade: _grade(),
      progress: progress,
      questions: questions,
    );
    return tester.pumpWidget(
      MaterialApp(
        theme: buildLightTheme(),
        home: Builder(
          builder: (context) {
            if (!reduceMotion) return screen;
            // Сохраняем реальные метрики экрана, переопределяя только флаг.
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: screen,
            );
          },
        ),
      ),
    );
  }

  // Отвечает на текущий вопрос (выбор A → «Ответить»).
  Future<void> answerCurrent(WidgetTester tester) async {
    await tester.tap(find.text('A'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ответить'));
    await tester.pumpAndSettle();
  }

  testWidgets('переход между вопросами не ломает навигацию (фейд дренится)',
      (tester) async {
    await pumpSession(tester, questions: [_q('q1'), _q('q2')]);

    await answerCurrent(tester);
    await tester.tap(find.text('Дальше'));
    await tester.pumpAndSettle(); // дренируем кросс-фейд (220мс)

    expect(find.text('Вопрос q2'), findsOneWidget);
    expect(find.text('Вопрос q1'), findsNothing);
    expect(tester.takeException(), isNull);
  },);

  testWidgets('reduce-motion: смена вопроса мгновенна (один кадр)',
      (tester) async {
    await pumpSession(
      tester,
      questions: [_q('q1'), _q('q2')],
      reduceMotion: true,
    );

    await answerCurrent(tester);
    await tester.tap(find.text('Дальше'));
    await tester.pump(); // один кадр — при zero-duration переход уже завершён

    expect(find.text('Вопрос q2'), findsOneWidget);
    expect(find.text('Вопрос q1'), findsNothing); // старый ушёл сразу
    expect(tester.takeException(), isNull);
  },);
}
