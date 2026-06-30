import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:interview_helper_system/main.dart' as app;
import 'package:interview_helper_system/screens/main_shell.dart';
import 'package:interview_helper_system/screens/onboarding_screen.dart';
import 'package:interview_helper_system/services/progress_service.dart';
import 'package:interview_helper_system/services/reminder_service.dart';
import 'package:interview_helper_system/services/theme_service.dart';
import 'package:interview_helper_system/services/user_profile_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  // === main(): инициализация и запуск (строки 11-18, 32, 34) ===============
  testWidgets('main() инициализирует сервисы и запускает приложение',
      (tester) async {
    app.main();
    await tester.pump();

    expect(find.byType(app.InterviewHelperApp), findsOneWidget);
    // Онбординг не пройден → стартуем с него.
    expect(find.byType(OnboardingScreen), findsOneWidget);
  },);

  // === onFinish: помечает флаг и переходит в MainShell (строки 49-60) =======
  testWidgets('завершение онбординга открывает MainShell', (tester) async {
    // MainShell строит собственный JsonQuestionRepository и читает ассет.
    // Без обслуживания канала ассетов loadTracks() не завершится и экран
    // зависнет в загрузке (бесконечный спиннер → pumpAndSettle timeout).
    // Отдаём минимальный валидный банк, чтобы загрузка мгновенно осела.
    binding.defaultBinaryMessenger.setMockMessageHandler(
      'flutter/assets',
      (message) async {
        final key = const StringCodec().decodeMessage(message);
        if (key == 'assets/data/questions.json') {
          return const StringCodec().encodeMessage('{"tracks":[]}');
        }
        return null;
      },
    );
    addTearDown(
      () => binding.defaultBinaryMessenger
          .setMockMessageHandler('flutter/assets', null),
    );

    final progress = ProgressService();
    await progress.init();
    final themeService = ThemeService();
    await themeService.init();
    final reminderService = ReminderService();
    await reminderService.init();
    final userProfile = UserProfileService();
    await userProfile.init();

    await tester.pumpWidget(
      app.InterviewHelperApp(
        progress: progress,
        themeService: themeService,
        reminderService: reminderService,
        userProfile: userProfile,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(OnboardingScreen), findsOneWidget);

    // Три инфо-карточки, затем финальная карточка ввода имени.
    await tester.tap(find.text('Далее'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Далее'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Далее'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'Тест');
    await tester.pump();
    await tester.tap(find.text('Начать'));
    await tester.pumpAndSettle();

    expect(find.byType(MainShell), findsOneWidget);
  });
}
