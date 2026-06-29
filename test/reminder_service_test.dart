import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:interview_helper_system/services/notification_service.dart';
import 'package:interview_helper_system/services/reminder_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Подменный планировщик: фиксирует вызовы и управляемо выдаёт разрешение.
class _FakeScheduler implements ReminderScheduler {
  _FakeScheduler({this.permission = true});

  bool permission;
  int permissionRequests = 0;
  int cancelCalls = 0;
  TimeOfDay? lastScheduled;
  int scheduleCalls = 0;

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return permission;
  }

  @override
  Future<void> scheduleDailyReminder(TimeOfDay time) async {
    scheduleCalls++;
    lastScheduled = time;
  }

  @override
  Future<void> cancelReminder() async {
    cancelCalls++;
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('ReminderService', () {
    test('по умолчанию выключен и ничего не планирует', () async {
      final fake = _FakeScheduler();
      final service = ReminderService(scheduler: fake);
      await service.init();

      expect(service.enabled, isFalse);
      expect(service.time, ReminderService.defaultTime);
      expect(fake.scheduleCalls, 0);
    });

    test('включение с разрешением планирует и сохраняет состояние', () async {
      final fake = _FakeScheduler();
      final service = ReminderService(scheduler: fake);
      await service.init();

      final ok = await service.setEnabled(true);

      expect(ok, isTrue);
      expect(service.enabled, isTrue);
      expect(fake.permissionRequests, 1);
      expect(fake.scheduleCalls, 1);
      expect(fake.lastScheduled, ReminderService.defaultTime);

      // Перезагрузка читает сохранённое «включено» и перепланирует на старте.
      final reloaded = ReminderService(scheduler: _FakeScheduler());
      await reloaded.init();
      expect(reloaded.enabled, isTrue);
    });

    test('без разрешения остаётся выключенным', () async {
      final fake = _FakeScheduler(permission: false);
      final service = ReminderService(scheduler: fake);
      await service.init();

      final ok = await service.setEnabled(true);

      expect(ok, isFalse);
      expect(service.enabled, isFalse);
      expect(fake.scheduleCalls, 0);
    });

    test('выключение снимает расписание', () async {
      final fake = _FakeScheduler();
      final service = ReminderService(scheduler: fake);
      await service.init();
      await service.setEnabled(true);

      await service.setEnabled(false);

      expect(service.enabled, isFalse);
      expect(fake.cancelCalls, greaterThanOrEqualTo(1));
    });

    test('смена времени при включённых напоминаниях перепланирует', () async {
      final fake = _FakeScheduler();
      final service = ReminderService(scheduler: fake);
      await service.init();
      await service.setEnabled(true);

      const newTime = TimeOfDay(hour: 8, minute: 30);
      await service.setTime(newTime);

      expect(service.time, newTime);
      expect(fake.lastScheduled, newTime);
      expect(fake.scheduleCalls, 2); // включение + смена времени
    });

    test('смена времени при выключенных не планирует, но сохраняется', () async {
      final fake = _FakeScheduler();
      final service = ReminderService(scheduler: fake);
      await service.init();

      const newTime = TimeOfDay(hour: 7, minute: 15);
      await service.setTime(newTime);

      expect(service.time, newTime);
      expect(fake.scheduleCalls, 0);
    });
  });
}
