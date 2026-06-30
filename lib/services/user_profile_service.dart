import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Хранит личные данные пользователя: имя (фамилия — опционально), выбранное
/// направление и целевой грейд. Идентификаторы направления/грейда ссылаются на
/// каталог треков (`Track.id` / `Grade.id`); разрешение в названия делает UI.
///
/// По образцу ThemeService: ChangeNotifier + SharedPreferences, init() при старте.
class UserProfileService extends ChangeNotifier {
  static const _kFirstName = 'profile_first_name';
  static const _kLastName = 'profile_last_name';
  static const _kDirection = 'profile_direction_track';
  static const _kTargetGrade = 'profile_target_grade';

  /// Подпись-заглушка, когда имя ещё не задано.
  static const fallbackName = 'Гость';

  late SharedPreferences _prefs;

  String _firstName = '';
  String? _lastName;
  String? _directionTrackId;
  String? _targetGradeId;

  String get firstName => _firstName;
  String? get lastName => _lastName;
  String? get directionTrackId => _directionTrackId;
  String? get targetGradeId => _targetGradeId;

  /// Имя для шапки профиля: «Имя Фамилия» (фамилия — если задана),
  /// либо [fallbackName], когда имя пустое.
  String get displayName {
    final full = [_firstName, _lastName ?? '']
        .where((p) => p.trim().isNotEmpty)
        .join(' ')
        .trim();
    return full.isEmpty ? fallbackName : full;
  }

  /// Загрузка сохранённого профиля. Вызывать один раз при старте.
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _firstName = _prefs.getString(_kFirstName) ?? '';
    _lastName = _prefs.getString(_kLastName);
    _directionTrackId = _prefs.getString(_kDirection);
    _targetGradeId = _prefs.getString(_kTargetGrade);
    notifyListeners();
  }

  /// Сохраняет имя (и опциональную фамилию). Пустая фамилия очищает поле —
  /// «только имя» полностью допустимо.
  Future<void> setName(String first, [String? last]) async {
    final firstTrimmed = first.trim();
    final lastTrimmed = last?.trim();
    final normalizedLast =
        (lastTrimmed == null || lastTrimmed.isEmpty) ? null : lastTrimmed;
    if (firstTrimmed == _firstName && normalizedLast == _lastName) return;

    _firstName = firstTrimmed;
    _lastName = normalizedLast;
    await _prefs.setString(_kFirstName, firstTrimmed);
    if (normalizedLast == null) {
      await _prefs.remove(_kLastName);
    } else {
      await _prefs.setString(_kLastName, normalizedLast);
    }
    notifyListeners();
  }

  /// Меняет выбранное направление. Смена направления сбрасывает целевой грейд,
  /// так как грейды у разных направлений разные.
  Future<void> setDirection(String trackId) async {
    if (trackId == _directionTrackId) return;
    _directionTrackId = trackId;
    _targetGradeId = null;
    await _prefs.setString(_kDirection, trackId);
    await _prefs.remove(_kTargetGrade);
    notifyListeners();
  }

  /// Меняет целевой грейд внутри выбранного направления.
  Future<void> setTargetGrade(String gradeId) async {
    if (gradeId == _targetGradeId) return;
    _targetGradeId = gradeId;
    await _prefs.setString(_kTargetGrade, gradeId);
    notifyListeners();
  }
}
