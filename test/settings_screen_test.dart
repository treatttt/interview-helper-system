import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:interview_helper_system/screens/settings_screen.dart';
import 'package:interview_helper_system/services/notification_service.dart';
import 'package:interview_helper_system/services/progress_service.dart';
import 'package:interview_helper_system/services/reminder_service.dart';
import 'package:interview_helper_system/services/theme_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Планировщик-заглушка: фиксирует вызовы, не трогает платформенные каналы.
class _FakeScheduler implements ReminderScheduler {
  _FakeScheduler({this.permission = true});
  bool permission;
  int scheduleCalls = 0;

  @override
  Future<bool> requestPermission() async => permission;

  @override
  Future<void> scheduleDailyReminder(TimeOfDay time) async => scheduleCalls++;

  @override
  Future<void> cancelReminder() async {}
}

Future<Widget> _buildSettings({_FakeScheduler? scheduler}) async {
  SharedPreferences.setMockInitialValues({});
  final progress = ProgressService();
  await progress.init();
  final theme = ThemeService();
  await theme.init();
  final reminders = ReminderService(scheduler: scheduler ?? _FakeScheduler());
  await reminders.init();

  return MaterialApp(
    home: SettingsScreen(
      themeService: theme,
      reminderService: reminders,
      progress: progress,
    ),
  );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('SettingsScreen — тема', () {
    testWidgets('строка темы показывает текущее значение', (tester) async {
      await tester.pumpWidget(await _buildSettings());

      expect(find.text('Тема оформления'), findsOneWidget);
      expect(find.text('Как в системе'), findsOneWidget);
    });

    testWidgets('выбор «Тёмная» в диалоге меняет подпись строки',
        (tester) async {
      await tester.pumpWidget(await _buildSettings());

      await tester.tap(find.text('Тема оформления'));
      await tester.pumpAndSettle();

      // В диалоге есть все три варианта.
      expect(find.text('Тёмная'), findsOneWidget);
      await tester.tap(find.text('Тёмная'));
      await tester.pumpAndSettle();

      // Диалог закрыт, подпись строки обновилась.
      expect(find.text('Тёмная'), findsOneWidget); // теперь в trailing строки
      expect(find.text('Как в системе'), findsNothing);
    });
  });

  group('SettingsScreen — напоминания', () {
    testWidgets('переключатель по умолчанию выключен', (tester) async {
      await tester.pumpWidget(await _buildSettings());

      final sw = tester.widget<SwitchListTile>(find.byType(SwitchListTile));
      expect(sw.value, isFalse);
    });

    testWidgets('включение с разрешением активирует напоминания',
        (tester) async {
      final fake = _FakeScheduler();
      await tester.pumpWidget(await _buildSettings(scheduler: fake));

      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();

      final sw = tester.widget<SwitchListTile>(find.byType(SwitchListTile));
      expect(sw.value, isTrue);
      expect(fake.scheduleCalls, greaterThanOrEqualTo(1));
    });

    testWidgets('без разрешения переключатель остаётся выключенным и показывает подсказку',
        (tester) async {
      final fake = _FakeScheduler(permission: false);
      await tester.pumpWidget(await _buildSettings(scheduler: fake));

      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();

      final sw = tester.widget<SwitchListTile>(find.byType(SwitchListTile));
      expect(sw.value, isFalse);
      expect(find.byType(SnackBar), findsOneWidget);
    });

    testWidgets('показывает строку времени напоминания', (tester) async {
      await tester.pumpWidget(await _buildSettings());

      expect(find.text('Время напоминания'), findsOneWidget);
      // 19:00 рендерится как «7:00 PM» в дефолтной локали тестов — проверяем
      // лишь наличие отформатированного времени (содержит «:00»).
      expect(find.textContaining(':00'), findsWidgets);
    });
  });
}
