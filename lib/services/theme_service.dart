import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Хранит выбранный режим темы (светлая / тёмная / как в системе) на устройстве.
/// По образцу ProgressService: ChangeNotifier + SharedPreferences, init() при старте.
class ThemeService extends ChangeNotifier {
  static const _kThemeMode = 'theme_mode';

  late SharedPreferences _prefs;
  ThemeMode _mode = ThemeMode.system;

  ThemeMode get mode => _mode;

  /// Загрузка сохранённого режима. Вызывать один раз при старте.
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _mode = switch (_prefs.getString(_kThemeMode)) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system, // нет значения или 'system'
    };
    notifyListeners(); // если init() не дожидались — MaterialApp подхватит тему
  }

  Future<void> setMode(ThemeMode mode) async {
    if (mode == _mode) return;
    _mode = mode;
    await _prefs.setString(
      _kThemeMode,
      mode.name,
    ); // 'light' / 'dark' / 'system'
    notifyListeners();
  }
}
