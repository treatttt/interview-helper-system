import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:interview_helper_system/services/notification_service.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

void main() {
  setUpAll(tzdata.initializeTimeZones);

  group('nextDailyInstant', () {
    late final tz.Location utc;
    setUpAll(() => utc = tz.getLocation('UTC'));

    test('время сегодня ещё впереди → планирует на сегодня', () {
      final now = tz.TZDateTime(utc, 2026, 6, 30, 10);
      final next =
          nextDailyInstant(const TimeOfDay(hour: 19, minute: 0), utc, now);

      expect(next.year, 2026);
      expect(next.month, 6);
      expect(next.day, 30);
      expect(next.hour, 19);
      expect(next.minute, 0);
    });

    // Граница `!isAfter`: ровно текущее время считается прошедшим, и при этом
    // перенос на завтра корректно перескакивает через конец месяца.
    test('время уже наступило → завтра (с переходом через конец месяца)', () {
      final now = tz.TZDateTime(utc, 2026, 6, 30, 19);
      final next =
          nextDailyInstant(const TimeOfDay(hour: 19, minute: 0), utc, now);

      expect(next.day, 1); // 1 июля
      expect(next.month, 7);
      expect(next.hour, 19);
    });
  });

  group('locationForOffset', () {
    final at = DateTime.utc(2026, 6, 30, 12);

    test('UTC-смещение возвращает зону с нулевым смещением', () {
      final loc = locationForOffset(Duration.zero, at: at);
      expect(tz.TZDateTime.from(at, loc).timeZoneOffset, Duration.zero);
    });

    test('подбирает зону с совпадающим смещением (+3 ч)', () {
      const offset = Duration(hours: 3);
      final loc = locationForOffset(offset, at: at);
      expect(tz.TZDateTime.from(at, loc).timeZoneOffset, offset);
    });

    test('неизвестное смещение откатывается к UTC', () {
      // 17 минут — не существует ни в одной зоне.
      final loc = locationForOffset(const Duration(minutes: 17), at: at);
      expect(loc.name, 'UTC');
    });
  });
}
