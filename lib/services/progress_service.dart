import 'package:shared_preferences/shared_preferences.dart';

// Хранит прогресс пользователя локально на устройстве:
// XP, streak (дни подряд) и количество правильных ответов по темам.
class ProgressService {
  static const _kXp = 'xp';
  static const _kStreak = 'streak';
  static const _kLastDay = 'last_day';
  static const _kTopicPrefix = 'topic_done_';

  late SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _updateStreakOnOpen();
  }

  int get xp => _prefs.getInt(_kXp) ?? 0;
  int get streak => _prefs.getInt(_kStreak) ?? 0;

  int topicDone(String topicId) => _prefs.getInt('$_kTopicPrefix$topicId') ?? 0;

  Future<void> addXp(int amount) async {
    await _prefs.setInt(_kXp, xp + amount);
  }

  // Записываем максимум правильных ответов по теме (чтобы прогресс не падал).
  Future<void> setTopicDone(String topicId, int correctCount) async {
    final current = topicDone(topicId);
    if (correctCount > current) {
      await _prefs.setInt('$_kTopicPrefix$topicId', correctCount);
    }
  }

  // Простая логика streak: считаем «дни» по номеру дня от эпохи.
  void _updateStreakOnOpen() {
    final today = DateTime.now().difference(DateTime(2024)).inDays;
    final last = _prefs.getInt(_kLastDay) ?? -1;
    if (last == today) return; // уже заходил сегодня
    if (last == today - 1) {
      _prefs.setInt(_kStreak, streak + 1); // подряд
    } else {
      _prefs.setInt(_kStreak, 1); // сброс / первый заход
    }
    _prefs.setInt(_kLastDay, today);
  }
}
