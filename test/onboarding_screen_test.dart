import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:interview_helper_system/screens/onboarding_screen.dart';

void main() {
  Widget host(VoidCallback onFinish, {bool disableAnimations = false}) {
    final screen = OnboardingScreen(onFinish: onFinish);
    return MaterialApp(
      home: disableAnimations
          ? MediaQuery(
              data: const MediaQueryData(disableAnimations: true),
              child: screen,
            )
          : screen,
    );
  }

  // === Тур + финальная кнопка (строки 61-63, 74-79, 87-89, 188-191, 277-313)
  testWidgets('«Далее» листает карточки, финальная кнопка вызывает onFinish',
      (tester) async {
    var finished = false;
    await tester.pumpWidget(host(() => finished = true));
    await tester.pumpAndSettle();

    expect(find.text('Тренируйся короткими сессиями'), findsOneWidget);

    await tester.tap(find.text('Далее'));
    await tester.pumpAndSettle();
    expect(find.text('Разбор после каждого ответа'), findsOneWidget);

    await tester.tap(find.text('Далее'));
    await tester.pumpAndSettle();
    expect(find.text('Возвращайся — серия растёт'), findsOneWidget);
    expect(find.text('Начать первую сессию'), findsOneWidget);

    await tester.tap(find.text('Начать первую сессию'));
    await tester.pumpAndSettle();
    expect(finished, isTrue);
  },);

  // === «Пропустить» → onFinish (строка 106) =================================
  testWidgets('«Пропустить» вызывает onFinish', (tester) async {
    var finished = false;
    await tester.pumpWidget(host(() => finished = true));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Пропустить'));
    await tester.pumpAndSettle();

    expect(finished, isTrue);
  });

  // === Reduced-motion: контент сразу (строки 92-94) =========================
  testWidgets('при отключённых анимациях контент показывается сразу',
      (tester) async {
    await tester.pumpWidget(host(() {}, disableAnimations: true));
    await tester.pump();

    expect(find.text('Тренируйся короткими сессиями'), findsOneWidget);
    expect(tester.takeException(), isNull);
  },);

  // === dispose контроллеров (строки 69-71) ==================================
  testWidgets('освобождает контроллеры при размонтировании без ошибок',
      (tester) async {
    await tester.pumpWidget(host(() {}));
    await tester.pump();

    await tester.pumpWidget(const SizedBox.shrink());

    expect(tester.takeException(), isNull);
  },);
}
