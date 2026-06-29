import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:interview_helper_system/models/models.dart';
import 'package:interview_helper_system/screens/profile_screen.dart';
import 'package:interview_helper_system/services/notification_service.dart';
import 'package:interview_helper_system/services/progress_service.dart';
import 'package:interview_helper_system/services/question_repository.dart';
import 'package:interview_helper_system/services/reminder_service.dart';
import 'package:interview_helper_system/services/theme_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeRepository implements QuestionRepository {
  @override
  Future<List<Track>> loadTracks() async => [];
}

class _NoopScheduler implements ReminderScheduler {
  @override
  Future<bool> requestPermission() async => true;
  @override
  Future<void> scheduleDailyReminder(TimeOfDay time) async {}
  @override
  Future<void> cancelReminder() async {}
}

Future<Widget> _buildProfile() async {
  SharedPreferences.setMockInitialValues({});
  final progress = ProgressService();
  await progress.init();
  final theme = ThemeService();
  await theme.init();
  final reminders = ReminderService(scheduler: _NoopScheduler());
  await reminders.init();

  return MaterialApp(
    home: ProfileScreen(
      progress: progress,
      themeService: theme,
      reminderService: reminders,
      repository: _FakeRepository(),
    ),
  );
}

void main() {
  testWidgets('шапка профиля показывает заглушки имени и аватара',
      (tester) async {
    await tester.pumpWidget(await _buildProfile());
    await tester.pumpAndSettle();

    expect(find.text('Имя Фамилия'), findsOneWidget);
    expect(find.byIcon(Icons.person_outline), findsOneWidget);
  });
}
