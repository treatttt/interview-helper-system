import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../controllers/session_controller.dart' show SessionResult;

/// Хранит прогресс пользователя на устройстве: XP, streak, рекорды по темам.
/// Данные лежат в SharedPreferences и переживают перезапуск приложения.
class ProgressService extends ChangeNotifier {
  static const _kXp = 'xp';
  static const _kStreak = 'streak';
  static const _kLastDay = 'last_active_day';
  static const _kTopics = 'topic_records';
  static const _kOnboardingDone = 'onboarding_done';

  /// Источник «сейчас». В проде — системные часы; в тестах подменяется,
  /// чтобы детерминированно проверять границы дня. Дефолт = поведение как было.
  final DateTime Function() _clock;

  ProgressService({DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  late SharedPreferences _prefs;

  int _xp = 0;
  int _streak = 0;
  String? _lastActiveDay;
  Map<String, int> _topicRecords = {};
  bool _onboardingDone = false;

  int get xp => _xp;

  int get streak => _streak;

  /// Кэшируется в init(), а НЕ читается из _prefs на лету.
  bool get onboardingDone => _onboardingDone;

  /// Была ли завершена хотя бы одна сессия за всё время.
  bool get hasTrainedEver => _lastActiveDay != null;

  int topicDone(String topicId) => _topicRecords[topicId] ?? 0;

  /// Сколько вопросов верно ответил пользователь в конкретном грейде.
  int gradeDone(String trackId, String gradeId) =>
      _topicRecords['${trackId}_$gradeId'] ?? 0;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _xp = _prefs.getInt(_kXp) ?? 0;
    _streak = _prefs.getInt(_kStreak) ?? 0;
    _lastActiveDay = _prefs.getString(_kLastDay);
    _onboardingDone = _prefs.getBool(_kOnboardingDone) ?? false;
    _topicRecords = _readTopicRecords();
    notifyListeners();
  }

  /// Толерантное чтение рекордов: битый JSON или нечисловые значения не валят старт.
  Map<String, int> _readTopicRecords() {
    final raw = _prefs.getString(_kTopics);
    if (raw == null) return {};
    try {
      final decoded = json.decode(raw);
      if (decoded is! Map) return {};
      final parsed = <String, int>{};
      decoded.forEach((k, v) {
        if (k is String && v is int) parsed[k] = v;
      });
      return parsed;
    } catch (e) {
      debugPrint('ProgressService: повреждён $_kTopics, сброс — $e');
      return {};
    }
  }

  /// Записать итог завершённой сессии: начислить XP, обновить streak и рекорд темы.
  Future<void> recordSession(String topicId, SessionResult result) async {
    final best = _topicRecords[topicId] ?? 0;

    // XP только за НОВЫЙ прогресс по теме: сколько верных сверх прежнего рекорда.
    if (result.correct > best) {
      final gain = result.correct - best;
      _xp += gain * 10;
      _topicRecords[topicId] = result.correct;
    }

    _updateStreak();
    await _save();
    notifyListeners();
  }

  /// Streak: дни подряд с занятиями. Засчитывается любой завершённой сессией.
  void _updateStreak() {
    final now = _clock();
    final todayKey = _dayKey(now);
    if (_lastActiveDay == todayKey) return; // сегодня уже занимались

    // «Вчера» через КАЛЕНДАРЬ (day - 1), а не вычитание 24ч: subtract(Duration)
    // на DST-переходе съезжает на лишний день и ложно рвёт серию около полуночи.
    // Конструктор DateTime нормализует переход через границу месяца/года.
    final yesterdayKey = _dayKey(DateTime(now.year, now.month, now.day - 1));
    if (_lastActiveDay == yesterdayKey) {
      _streak += 1; // занимались вчера — серия продолжается
    } else {
      _streak = 1; // пропуск (или первый раз) — серия начинается заново
    }
    _lastActiveDay = todayKey;
  }

  Future<void> markOnboardingDone() async {
    _onboardingDone = true;
    await _prefs.setBool(_kOnboardingDone, true);
  }

  /// Дата без времени, в виде строки YYYY-MM-DD — для сравнения по дням.
  String _dayKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _save() async {
    await _prefs.setInt(_kXp, _xp);
    await _prefs.setInt(_kStreak, _streak);
    if (_lastActiveDay != null) {
      await _prefs.setString(_kLastDay, _lastActiveDay!);
    }
    await _prefs.setString(_kTopics, json.encode(_topicRecords));
  }
}