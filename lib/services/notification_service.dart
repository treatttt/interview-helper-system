import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Абстракция планировщика напоминаний — то, что нужно ReminderService от
/// системы уведомлений. Позволяет подменять реализацию в тестах.
abstract class ReminderScheduler {
  /// Запрашивает разрешение на уведомления. true — если оно есть.
  Future<bool> requestPermission();

  /// Планирует (или перепланирует) ежедневное напоминание на [time].
  Future<void> scheduleDailyReminder(TimeOfDay time);

  /// Снимает запланированное напоминание.
  Future<void> cancelReminder();
}

/// Тонкая обёртка над flutter_local_notifications: инициализация, запрос
/// разрешений и планирование ежедневного напоминания «приходи позаниматься».
///
/// Логика «включено/в какое время» живёт в ReminderService — этот класс
/// отвечает только за взаимодействие с системой уведомлений.
class NotificationService implements ReminderScheduler {
  NotificationService._();

  /// Единственный экземпляр — уведомления глобальны для приложения.
  static final NotificationService instance = NotificationService._();

  static const _channelId = 'daily_reminder';
  static const _channelName = 'Напоминания';
  static const _channelDescription =
      'Ежедневное напоминание продолжить тренировки';

  /// Постоянный id запланированного напоминания — переиспользуем при перепланах.
  static const _reminderNotificationId = 1001;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  /// Готовит плагин и базу часовых поясов. Безопасно вызывать повторно.
  Future<void> init() async {
    if (_initialized) return;

    tzdata.initializeTimeZones();
    tz.setLocalLocation(_resolveLocalLocation());

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinInit = DarwinInitializationSettings(
      // Разрешения спрашиваем явно при включении напоминаний, а не при старте.
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _plugin.initialize(
      const InitializationSettings(
        android: androidInit,
        iOS: darwinInit,
        macOS: darwinInit,
      ),
    );

    _initialized = true;
  }

  /// Запрашивает у пользователя разрешение на показ уведомлений.
  /// Возвращает true, если разрешение получено (или платформа его не требует).
  @override
  Future<bool> requestPermission() async {
    await init();

    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      final granted = await android.requestNotificationsPermission();
      return granted ?? true;
    }

    final darwin = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (darwin != null) {
      final granted = await darwin.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return granted ?? false;
    }

    return true;
  }

  /// Планирует (или перепланирует) ежедневное напоминание на время [time].
  @override
  Future<void> scheduleDailyReminder(TimeOfDay time) async {
    await init();
    await cancelReminder();

    await _plugin.zonedSchedule(
      _reminderNotificationId,
      'Тебя ждут новые вопросы',
      'Пройди тренировку и продли свою серию! 🔥',
      _nextInstanceOf(time),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
        macOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      // Повтор каждый день в одно и то же время.
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  /// Снимает запланированное напоминание.
  @override
  Future<void> cancelReminder() async {
    await init();
    await _plugin.cancel(_reminderNotificationId);
  }

  /// Ближайшее наступление времени [time] в локальном поясе (сегодня или завтра).
  tz.TZDateTime _nextInstanceOf(TimeOfDay time) =>
      nextDailyInstant(time, tz.local, tz.TZDateTime.now(tz.local));

  /// Подбирает локацию из базы tz по текущему смещению устройства.
  ///
  /// Без плагина определения IANA-зоны берём любую зону с тем же текущим
  /// UTC-смещением — для ежедневного напоминания этого достаточно (возможна
  /// расхождение в ±1 ч при иных правилах перехода на летнее время). Если
  /// подходящей зоны нет — остаёмся на UTC.
  tz.Location _resolveLocalLocation() =>
      locationForOffset(DateTime.now().timeZoneOffset);
}

/// Ближайший момент, когда местное время станет [time]: сегодня, если он ещё
/// впереди, иначе завтра. Чистая функция — вынесена для тестов.
@visibleForTesting
tz.TZDateTime nextDailyInstant(
  TimeOfDay time,
  tz.Location location,
  tz.TZDateTime now,
) {
  var scheduled = tz.TZDateTime(
    location,
    now.year,
    now.month,
    now.day,
    time.hour,
    time.minute,
  );
  if (!scheduled.isAfter(now)) {
    scheduled = scheduled.add(const Duration(days: 1));
  }
  return scheduled;
}

/// Подбирает локацию из базы tz, чьё текущее UTC-смещение совпадает с [offset].
/// Если такой нет — UTC. Чистая функция — вынесена для тестов.
@visibleForTesting
tz.Location locationForOffset(Duration offset, {DateTime? at}) {
  final nowUtc = (at ?? DateTime.now()).toUtc();
  for (final location in tz.timeZoneDatabase.locations.values) {
    final zoneOffset =
        tz.TZDateTime.from(nowUtc, location).timeZoneOffset.inMinutes;
    if (zoneOffset == offset.inMinutes) {
      return location;
    }
  }
  return tz.getLocation('UTC');
}
