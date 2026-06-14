import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../controllers/session_controller.dart' show SessionResult;

/// Хранит прогресс пользователя на устройстве: XP, streak, рекорды по темам.
/// Данные лежат в SharedPreferences и переживают перезапуск приложения.
class ProgressService extends ChangeNotifier {
  static const _kXp = 'xp';
  static const _kStreak = 'streak';
  static const _kLastDay = 'last_active_day'; // дата последней активности
  static const _kTopics = 'topic_records';    // рекорды верных по темам (JSON)

  late SharedPreferences _prefs;

  int _xp = 0;
  int _streak = 0;
  String? _lastActiveDay;
  Map<String, int> _topicRecords = {};

  int get xp => _xp;
  int get streak => _streak;

  /// Лучший результат (число верных) по теме. Для прогресс-бара на главном.
  int topicDone(String topicId) => _topicRecords[topicId] ?? 0;

  /// Загрузка сохранённого прогресса. Вызывать один раз при старте приложения.
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _xp = _prefs.getInt(_kXp) ?? 0;
    _streak = _prefs.getInt(_kStreak) ?? 0;
    _lastActiveDay = _prefs.getString(_kLastDay);
    final raw = _prefs.getString(_kTopics);
    if (raw != null) {
      _topicRecords =
          (json.decode(raw) as Map<String, dynamic>).cast<String, int>();
    }
  }

  /// Записать итог завершённой сессии: начислить XP, обновить streak и рекорд темы.
  Future<void> recordSession(String topicId, SessionResult result) async {
    // XP: 10 за каждый набранный балл.
    _xp += result.points * 10;

    // Рекорд по теме: храним лучшее число верных ответов, бар только растёт.
    final best = _topicRecords[topicId] ?? 0;
    if (result.correct > best) {
      _topicRecords[topicId] = result.correct;
    }

    _updateStreak();
    await _save();
    notifyListeners();
  }

  /// Streak: дни подряд с занятиями. Засчитывается любой завершённой сессией.
  void _updateStreak() {
    final today = _dayKey(DateTime.now());
    if (_lastActiveDay == today) return; // сегодня уже занимались — не меняем

    final yesterday = _dayKey(DateTime.now().subtract(const Duration(days: 1)));
    if (_lastActiveDay == yesterday) {
      _streak += 1; // занимались вчера — серия продолжается
    } else {
      _streak = 1; // пропуск (или первый раз) — серия начинается заново
    }
    _lastActiveDay = today;
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