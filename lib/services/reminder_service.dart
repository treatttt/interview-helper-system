import 'package:flutter/material.dart';
import 'package:interview_helper_system/services/notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Хранит настройки ежедневного напоминания (включено / время) на устройстве
/// и держит системное расписание уведомлений в синхронизации.
///
/// По образцу ThemeService: ChangeNotifier + SharedPreferences, init() при старте.
class ReminderService extends ChangeNotifier {
  ReminderService({ReminderScheduler? scheduler})
      : _notifications = scheduler ?? NotificationService.instance;

  static const _kEnabled = 'reminder_enabled';
  static const _kHour = 'reminder_hour';
  static const _kMinute = 'reminder_minute';

  /// Время напоминания по умолчанию — вечер, когда удобно позаниматься.
  static const TimeOfDay defaultTime = TimeOfDay(hour: 19, minute: 0);

  final ReminderScheduler _notifications;
  late SharedPreferences _prefs;

  bool _enabled = false;
  TimeOfDay _time = defaultTime;

  bool get enabled => _enabled;
  TimeOfDay get time => _time;

  /// Загрузка сохранённых настроек. Вызывать один раз при старте.
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _enabled = _prefs.getBool(_kEnabled) ?? false;
    final hour = _prefs.getInt(_kHour);
    final minute = _prefs.getInt(_kMinute);
    if (hour != null && minute != null) {
      _time = TimeOfDay(hour: hour, minute: minute);
    }
    // Перепланируем расписание на старте, чтобы оно пережило перезапуск/смену
    // часового пояса. Разрешение уже было выдано при включении.
    if (_enabled) {
      await _notifications.scheduleDailyReminder(_time);
    }
    notifyListeners();
  }

  /// Включает/выключает напоминания. При включении спрашивает разрешение и
  /// планирует уведомление; при выключении — снимает расписание.
  ///
  /// Возвращает true, если итоговое состояние совпало с запрошенным
  /// (например, при включении пользователь дал разрешение).
  // ignore: avoid_positional_boolean_parameters
  Future<bool> setEnabled(bool value) async {
    if (value) {
      final granted = await _notifications.requestPermission();
      if (!granted) {
        // Без разрешения оставляем выключенным.
        if (_enabled) {
          _enabled = false;
          await _prefs.setBool(_kEnabled, false);
          notifyListeners();
        }
        return false;
      }
      await _notifications.scheduleDailyReminder(_time);
    } else {
      await _notifications.cancelReminder();
    }
    _enabled = value;
    await _prefs.setBool(_kEnabled, value);
    notifyListeners();
    return true;
  }

  /// Меняет время напоминания. Если напоминания включены — перепланирует.
  Future<void> setTime(TimeOfDay time) async {
    if (time == _time) return;
    _time = time;
    await _prefs.setInt(_kHour, time.hour);
    await _prefs.setInt(_kMinute, time.minute);
    if (_enabled) {
      await _notifications.scheduleDailyReminder(time);
    }
    notifyListeners();
  }
}
