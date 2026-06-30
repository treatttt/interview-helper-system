import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:interview_helper_system/services/notification_service.dart';
import 'package:interview_helper_system/services/reminder_service.dart';
import 'package:interview_helper_system/utils/reminder_prompt.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeScheduler implements ReminderScheduler {
  _FakeScheduler({this.permission = true});
  bool permission;
  int scheduleCalls = 0;
  TimeOfDay? lastScheduled;

  @override
  Future<bool> requestPermission() async => permission;
  @override
  Future<void> scheduleDailyReminder(TimeOfDay time) async {
    scheduleCalls++;
    lastScheduled = time;
  }

  @override
  Future<void> cancelReminder() async {}
}

Future<ReminderService> _service({bool permission = true}) async {
  SharedPreferences.setMockInitialValues({});
  final service = ReminderService(scheduler: _FakeScheduler(permission: permission));
  await service.init();
  return service;
}

Widget _host(ReminderService service) {
  return MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) => Center(
          child: ElevatedButton(
            onPressed: () => enableRemindersWithPrompt(context, service),
            child: const Text('go'),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('подтверждение времени включает напоминания', (tester) async {
    final service = await _service();
    await tester.pumpWidget(_host(service));

    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Готово'));
    await tester.pumpAndSettle();

    expect(service.enabled, isTrue);
  });

  testWidgets('отмена выбора оставляет напоминания выключенными',
      (tester) async {
    final service = await _service();
    await tester.pumpWidget(_host(service));

    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Отмена'));
    await tester.pumpAndSettle();

    expect(service.enabled, isFalse);
  });
}
