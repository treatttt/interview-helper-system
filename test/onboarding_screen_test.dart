import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:interview_helper_system/screens/onboarding_screen.dart';

void main() {
  Widget host(
    void Function(String firstName, String? lastName) onFinish, {
    bool disableAnimations = false,
  }) {
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

  // === Тур + карточка имени + финальная кнопка ==============================
  testWidgets('«Далее» листает карточки; ввод имени активирует «Начать»',
      (tester) async {
    String? finishedName;
    await tester.pumpWidget(host((first, _) => finishedName = first));
    await tester.pumpAndSettle();

    expect(find.text('Тренируйся короткими сессиями'), findsOneWidget);

    await tester.tap(find.text('Далее'));
    await tester.pumpAndSettle();
    expect(find.text('Разбор после каждого ответа'), findsOneWidget);

    await tester.tap(find.text('Далее'));
    await tester.pumpAndSettle();
    expect(find.text('Возвращайся — серия растёт'), findsOneWidget);

    // Третий «Далее» ведёт на карточку имени.
    await tester.tap(find.text('Далее'));
    await tester.pumpAndSettle();
    expect(find.text('Как тебя зовут?'), findsOneWidget);

    // Пока имя пустое — «Начать» заблокирована.
    final btnBefore = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(btnBefore.onPressed, isNull);

    await tester.enterText(find.byType(TextField).first, 'Никита');
    await tester.pump();

    await tester.tap(find.text('Начать'));
    await tester.pumpAndSettle();
    expect(finishedName, 'Никита');
  });

  // === «Пропустить» → onFinish (с пустым именем) ============================
  testWidgets('«Пропустить» вызывает onFinish', (tester) async {
    var finished = false;
    await tester.pumpWidget(host((first, last) => finished = true));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Пропустить'));
    await tester.pumpAndSettle();

    expect(finished, isTrue);
  });

  // === Reduced-motion: контент сразу ========================================
  testWidgets('при отключённых анимациях контент показывается сразу',
      (tester) async {
    await tester.pumpWidget(host((_, __) {}, disableAnimations: true));
    await tester.pump();

    expect(find.text('Тренируйся короткими сессиями'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  // === dispose контроллеров =================================================
  testWidgets('освобождает контроллеры при размонтировании без ошибок',
      (tester) async {
    await tester.pumpWidget(host((_, __) {}));
    await tester.pump();

    await tester.pumpWidget(const SizedBox.shrink());

    expect(tester.takeException(), isNull);
  });
}
