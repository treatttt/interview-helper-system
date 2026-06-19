import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../controllers/session_controller.dart' show SessionResult;

/// Хранит прогресс пользователя: XP, streak, освоенные вопросы по грейдам,
/// незавершённую сессию (один слот). Данные переживают перезапуск приложения.
class ProgressService extends ChangeNotifier {
  static const _kXp = 'xp';
  static const _kStreak = 'streak';
  static const _kLastDay = 'last_active_day';
  static const _kMasteredIds = 'mastered_ids'; // Map<gradeKey, List<questionId>>
  static const _kIncompleteSession = 'incomplete_session';
  static const _kOnboardingDone = 'onboarding_done';

  final DateTime Function() _clock;

  ProgressService({DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  late SharedPreferences _prefs;

  int _xp = 0;
  int _streak = 0;
  String? _lastActiveDay;
  Map<String, Set<String>> _masteredIds = {}; // gradeKey → Set<questionId>
  Map<String, dynamic>? _incompleteSession;
  bool _onboardingDone = false;

  int get xp => _xp;
  int get streak => _streak;
  bool get onboardingDone => _onboardingDone;
  bool get hasTrainedEver => _lastActiveDay != null;

  /// Обратная совместимость для тестов: количество освоенных вопросов в теме.
  int topicDone(String topicId) => _masteredIds[topicId]?.length ?? 0;

  /// Сколько вопросов освоено в конкретном грейде.
  int gradeDone(String trackId, String gradeId) =>
      masteredIds(trackId, gradeId).length;

  /// Множество ID вопросов, верно отвеченных в грейде (для фильтрации пула).
  Set<String> masteredIds(String trackId, String gradeId) =>
      _masteredIds['${trackId}_$gradeId'] ?? const {};

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _xp = _prefs.getInt(_kXp) ?? 0;
    _streak = _prefs.getInt(_kStreak) ?? 0;
    _lastActiveDay = _prefs.getString(_kLastDay);
    _onboardingDone = _prefs.getBool(_kOnboardingDone) ?? false;
    _masteredIds = _readMasteredIds();
    _incompleteSession = _readIncompleteSession();
    notifyListeners();
  }

  Map<String, Set<String>> _readMasteredIds() {
    final raw = _prefs.getString(_kMasteredIds);
    if (raw == null) return {};
    try {
      final decoded = json.decode(raw);
      if (decoded is! Map) return {};
      final result = <String, Set<String>>{};
      decoded.forEach((k, v) {
        if (k is String && v is List) {
          result[k] = v.whereType<String>().toSet();
        }
      });
      return result;
    } catch (e) {
      debugPrint('ProgressService: повреждён $_kMasteredIds, сброс — $e');
      return {};
    }
  }

  Map<String, dynamic>? _readIncompleteSession() {
    final raw = _prefs.getString(_kIncompleteSession);
    if (raw == null) return null;
    try {
      final decoded = json.decode(raw);
      if (decoded is! Map) return null;
      return decoded.cast<String, dynamic>();
    } catch (_) {
      return null;
    }
  }

  /// Записать итог завершённой сессии: начислить XP за новые ID, обновить streak.
  Future<void> recordSession(String gradeKey, SessionResult result) async {
    final existing = _masteredIds[gradeKey] ?? const <String>{};
    final gained = result.correctIds.difference(existing);

    if (gained.isNotEmpty) {
      _xp += gained.length * 10;
      _masteredIds[gradeKey] = {...existing, ...result.correctIds};
    }

    // Сессия завершена — слот незавершённой сессии для этого грейда сбрасывается.
    if (_incompleteSession?['gradeKey'] == gradeKey) {
      _incompleteSession = null;
      await _prefs.remove(_kIncompleteSession);
    }

    _updateStreak();
    await _save();
    notifyListeners();
  }

  /// Вернуть сохранённую незавершённую сессию для gradeKey, или null.
  Map<String, dynamic>? loadIncompleteSession(String gradeKey) {
    final s = _incompleteSession;
    if (s == null || s['gradeKey'] != gradeKey) return null;
    return s;
  }

  /// Сохранить незавершённую сессию (синхронно в памяти, асинхронно на диск).
  /// Вызывается из dispose() виджета — не должен блокировать.
  // ignore: discarded_futures
  void saveIncompleteSessionSync(Map<String, dynamic> data) {
    _incompleteSession = data;
    _prefs.setString(_kIncompleteSession, json.encode(data));
  }

  /// Сохранить незавершённую сессию асинхронно (из обычных async-контекстов).
  Future<void> saveIncompleteSession(Map<String, dynamic> data) async {
    _incompleteSession = data;
    await _prefs.setString(_kIncompleteSession, json.encode(data));
  }

  /// Очистить незавершённую сессию. [gradeKey] — только для этого грейда;
  /// если null — безусловно.
  Future<void> clearIncompleteSession({String? gradeKey}) async {
    if (gradeKey != null && _incompleteSession?['gradeKey'] != gradeKey) return;
    _incompleteSession = null;
    await _prefs.remove(_kIncompleteSession);
  }

  /// Сбросить прогресс грейда: очистить освоенные вопросы и незавершённую сессию.
  Future<void> resetGrade(String trackId, String gradeId) async {
    final key = '${trackId}_$gradeId';
    _masteredIds.remove(key);
    if (_incompleteSession?['gradeKey'] == key) {
      _incompleteSession = null;
      await _prefs.remove(_kIncompleteSession);
    }
    await _save();
    notifyListeners();
  }

  void _updateStreak() {
    final now = _clock();
    final todayKey = _dayKey(now);
    if (_lastActiveDay == todayKey) return;
    final yesterdayKey = _dayKey(DateTime(now.year, now.month, now.day - 1));
    if (_lastActiveDay == yesterdayKey) {
      _streak += 1;
    } else {
      _streak = 1;
    }
    _lastActiveDay = todayKey;
  }

  Future<void> markOnboardingDone() async {
    _onboardingDone = true;
    await _prefs.setBool(_kOnboardingDone, true);
  }

  String _dayKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _save() async {
    await _prefs.setInt(_kXp, _xp);
    await _prefs.setInt(_kStreak, _streak);
    if (_lastActiveDay != null) {
      await _prefs.setString(_kLastDay, _lastActiveDay!);
    }
    final serialized = _masteredIds.map((k, v) => MapEntry(k, v.toList()));
    await _prefs.setString(_kMasteredIds, json.encode(serialized));
  }
}
