import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:interview_helper_system/controllers/session_controller.dart'
    show AnswerOutcome, SessionResult;
import 'package:shared_preferences/shared_preferences.dart';

/// Статистика пользователя по одной теме (для дашборда).
class TopicStat {
  const TopicStat({
    required this.title,
    required this.attempts,
    required this.correct,
  });
  final String title;
  final int attempts;
  final int correct;
  double get accuracy => attempts == 0 ? 0.0 : correct / attempts;
}

class _TopicCount {
  _TopicCount(this.attempts, this.correct);
  int attempts;
  int correct;
}

/// Хранит прогресс пользователя: XP, streak, освоенные вопросы по грейдам,
/// статистику ответов по темам, незавершённую сессию.
///
/// Слоты незавершённых сессий два и независимы:
///   • грейдовый ([_kIncompleteSession]) — одна пауза полногрейдовой сессии,
///     ключуется по gradeKey;
///   • тема-слот ([_kIncompleteTopicSession]) — одна пауза тема-дрилла,
///     ключуется по названию темы.
/// Раздельность нужна, чтобы хождение по темам не затирало паузу грейда
/// (и наоборот): тема-дрилл крутится под реальным gradeKey, и общий слот
/// перетирал бы полногрейдовую паузу того же грейда.
/// Данные переживают перезапуск приложения.
class ProgressService extends ChangeNotifier {
  ProgressService({DateTime Function()? clock})
      : _clock = clock ?? DateTime.now;
  static const _kXp = 'xp';
  static const _kStreak = 'streak';
  static const _kLastDay = 'last_active_day';
  static const _kMasteredIds = 'mastered_ids'; // Map<gradeKey, List<questionId>>
  static const _kIncompleteSession = 'incomplete_session';
  static const _kIncompleteTopicSession = 'incomplete_topic_session';
  static const _kOnboardingDone = 'onboarding_done';
  static const _kTopicStats = 'topic_stats'; // Map<topic, {attempts, correct}>

  final DateTime Function() _clock;

  late SharedPreferences _prefs;

  int _xp = 0;
  int _streak = 0;
  String? _lastActiveDay;
  Map<String, Set<String>> _masteredIds = {}; // gradeKey → Set<questionId>
  Map<String, Object?>? _incompleteSession;
  Map<String, Object?>? _incompleteTopicSession;
  bool _onboardingDone = false;
  Map<String, _TopicCount> _topicStats = {}; // topic → counts

  int get xp => _xp;
  int get streak => _streak;
  bool get onboardingDone => _onboardingDone;
  bool get hasTrainedEver => _lastActiveDay != null;

  /// Суммарное количество освоенных вопросов по всем грейдам.
  int get totalMastered =>
      _masteredIds.values.fold(0, (sum, ids) => sum + ids.length);

  /// Общая точность по всем темам (0..1). Возвращает 0, если попыток нет.
  double get overallAccuracy {
    var totalAttempts = 0;
    var totalCorrect = 0;
    for (final c in _topicStats.values) {
      totalAttempts += c.attempts;
      totalCorrect += c.correct;
    }
    return totalAttempts == 0 ? 0.0 : totalCorrect / totalAttempts;
  }

  /// Топ-N самых слабых тем среди тех, где ≥ [minAttempts] попыток.
  /// Отсортированы по точности по возрастанию (сначала слабейшие).
  List<TopicStat> weakestTopics({int limit = 3, int minAttempts = 1}) {
    final stats = _topicStats.entries
        .where((e) => e.value.attempts >= minAttempts)
        .map(
          (e) => TopicStat(
        title: e.key,
        attempts: e.value.attempts,
        correct: e.value.correct,
      ),
    )
        .toList()
      ..sort((a, b) => a.accuracy.compareTo(b.accuracy));
    return stats.take(limit).toList();
  }

  /// Обратная совместимость для тестов: количество освоенных вопросов в теме.
  int topicDone(String topicId) => _masteredIds[topicId]?.length ?? 0;

  /// Сколько вопросов освоено в конкретном грейде.
  int gradeDone(String trackId, String gradeId) =>
      masteredIds(trackId, gradeId).length;

  /// Множество ID вопросов, верно отвеченных в грейде (для фильтрации пула).
  /// Возвращает неизменяемую копию — мутация не затрагивает внутреннее состояние.
  Set<String> masteredIds(String trackId, String gradeId) {
    final inner = _masteredIds['${trackId}_$gradeId'];
    return inner == null ? const {} : Set.unmodifiable(inner);
  }

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _xp = _prefs.getInt(_kXp) ?? 0;
    _streak = _prefs.getInt(_kStreak) ?? 0;
    _lastActiveDay = _prefs.getString(_kLastDay);
    _onboardingDone = _prefs.getBool(_kOnboardingDone) ?? false;
    _masteredIds = _readMasteredIds();
    _topicStats = _readTopicStats();
    _incompleteSession = _readSlot(_kIncompleteSession);
    _incompleteTopicSession = _readSlot(_kIncompleteTopicSession);
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
    } on Object catch (e) {
      debugPrint('ProgressService: повреждён $_kMasteredIds, сброс — $e');
      return {};
    }
  }

  Map<String, _TopicCount> _readTopicStats() {
    final raw = _prefs.getString(_kTopicStats);
    if (raw == null) return {};
    try {
      final decoded = json.decode(raw);
      if (decoded is! Map) return {};
      final result = <String, _TopicCount>{};
      decoded.forEach((k, v) {
        if (k is String && v is Map) {
          final a = v['attempts'];
          final c = v['correct'];
          if (a is int && c is int) {
            result[k] = _TopicCount(a, c);
          }
        }
      });
      return result;
    } on Object catch (e) {
      debugPrint('ProgressService: повреждён $_kTopicStats, сброс — $e');
      return {};
    }
  }

  Map<String, Object?>? _readSlot(String key) {
    final raw = _prefs.getString(key);
    if (raw == null) return null;
    try {
      final decoded = json.decode(raw);
      if (decoded is! Map) return null;
      return decoded.cast<String, Object?>();
    } on Object catch (_) {
      return null;
    }
  }

  /// Записать итог завершённой сессии: начислить XP за новые ID, обновить streak
  /// и обновить статистику точности по темам из [result.answers].
  ///
  /// [clearIncomplete] — сбрасывать ли грейдовый слот незавершённой сессии этого
  /// грейда. false передаёт тема-дрилл: он не должен затирать паузу
  /// полногрейдовой сессии, лежащую под тем же gradeKey (свой тема-слот он
  /// чистит сам через [clearIncompleteTopicSession]).
  Future<void> recordSession(
      String gradeKey,
      SessionResult result, {
        bool clearIncomplete = true,
      }) async {
    final existing = _masteredIds[gradeKey] ?? const <String>{};
    final gained = result.correctIds.difference(existing);

    if (gained.isNotEmpty) {
      _xp += gained.length * 10;
      _masteredIds[gradeKey] = {...existing, ...result.correctIds};
    }

    // Обновляем статистику по темам: перезапись результатами этой сессии.
    // Темы, встреченные в сессии, получают счётчики только этого прохода —
    // свежий хороший результат не «тонет» в накопленных старых ответах.
    // Темы, которых в сессии не было, не трогаем: их статистика хранится
    // от их последнего прохода.
    final sessionStats = <String, _TopicCount>{};
    for (final a in result.answers) {
      final topic = a.question.topic;
      if (topic == null || topic.isEmpty) continue;
      final count = sessionStats.putIfAbsent(topic, () => _TopicCount(0, 0));
      count.attempts++;
      if (a.outcome == AnswerOutcome.correct) count.correct++;
    }
    sessionStats.forEach((topic, count) {
      _topicStats[topic] = count;
    });

    // Сессия завершена — грейдовый слот для этого грейда сбрасывается.
    if (clearIncomplete && _incompleteSession?['gradeKey'] == gradeKey) {
      _incompleteSession = null;
      await _prefs.remove(_kIncompleteSession);
    }

    _updateStreak();
    await _save();
    notifyListeners();
  }

  // ── Грейдовый слот незавершённой сессии ───────────────────────────────────

  /// Вернуть сохранённую незавершённую сессию для gradeKey, или null.
  Map<String, Object?>? loadIncompleteSession(String gradeKey) {
    final s = _incompleteSession;
    if (s == null || s['gradeKey'] != gradeKey) return null;
    return s;
  }

  /// Сохранить незавершённую сессию (синхронно в памяти, асинхронно на диск).
  /// Вызывается из dispose() виджета — не должен блокировать.
  void saveIncompleteSessionSync(Map<String, Object?> data) {
    _incompleteSession = data;
    // Fire-and-forget: вызывается из dispose(), await невозможен.
    // ignore: discarded_futures
    _prefs.setString(_kIncompleteSession, json.encode(data));
  }

  /// Сохранить незавершённую сессию асинхронно (из обычных async-контекстов).
  Future<void> saveIncompleteSession(Map<String, Object?> data) async {
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

  // ── Тема-слот незавершённого дрилла ────────────────────────────────────────

  /// Вернуть сохранённую паузу тема-дрилла для [topicTitle], или null.
  Map<String, Object?>? loadIncompleteTopicSession(String topicTitle) {
    final s = _incompleteTopicSession;
    if (s == null || s['topicTitle'] != topicTitle) return null;
    return s;
  }

  /// Сохранить паузу тема-дрилла (синхронно в память, асинхронно на диск).
  /// Вызывается из dispose() — не должен блокировать.
  void saveIncompleteTopicSessionSync(Map<String, Object?> data) {
    _incompleteTopicSession = data;
    // ignore: discarded_futures
    _prefs.setString(_kIncompleteTopicSession, json.encode(data));
  }

  /// Очистить паузу тема-дрилла. [topicTitle] — только для этой темы;
  /// если null — безусловно.
  Future<void> clearIncompleteTopicSession({String? topicTitle}) async {
    if (topicTitle != null &&
        _incompleteTopicSession?['topicTitle'] != topicTitle) {
      return;
    }
    _incompleteTopicSession = null;
    await _prefs.remove(_kIncompleteTopicSession);
  }

  // ── Сбросы прогресса ──────────────────────────────────────────────────────

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

  /// Снять отметку «освоено» с конкретных вопросов внутри грейдов.
  /// [idsByGradeKey]: gradeKey → questionId, которые нужно вернуть в пул.
  ///
  /// Грейдовый слот незавершённой сессии не трогаем — сохранённая пауза
  /// реплеит своё подмножество вопросов и от снятия мастеринга не ломается.
  /// Тема-слот тоже не трогаем здесь — это делает вызывающий [resetTopic],
  /// который знает тему.
  Future<void> resetMastered(Map<String, Set<String>> idsByGradeKey) async {
    var changed = false;
    idsByGradeKey.forEach((key, ids) {
      final inner = _masteredIds[key];
      if (inner == null || ids.isEmpty) return;
      final before = inner.length;
      inner.removeAll(ids);
      if (inner.length != before) changed = true;
      if (inner.isEmpty) _masteredIds.remove(key);
    });
    if (!changed) return;
    await _save();
    notifyListeners();
  }

  void _updateStreak() {
    final now = _clock();
    final todayKey = _dayKey(now);
    if (_lastActiveDay == todayKey) return;
    final yesterdayKey = _dayKey(DateTime(now.year, now.month, now.day - 1));
    _streak = _lastActiveDay == yesterdayKey ? _streak + 1 : 1;
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

    final topicSerialized = _topicStats.map(
          (k, v) => MapEntry(k, {'attempts': v.attempts, 'correct': v.correct}),
    );
    await _prefs.setString(_kTopicStats, json.encode(topicSerialized));
  }
}
