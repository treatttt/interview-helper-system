import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:interview_helper_system/services/theme_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  // === setMode (строки 25-35) ==============================================
  test('setMode с тем же режимом — без записи и без уведомления', () async {
    final service = ThemeService();
    await service.init(); // _mode = system (значения нет)

    var notified = 0;
    service.addListener(() => notified++);

    await service.setMode(ThemeMode.system); // == текущему → ранний выход

    expect(service.mode, ThemeMode.system);
    expect(notified, 0);
  });

  test('setMode меняет режим, уведомляет и сохраняет на устройстве', () async {
    final service = ThemeService();
    await service.init();

    var notified = 0;
    service.addListener(() => notified++);

    await service.setMode(ThemeMode.dark);

    expect(service.mode, ThemeMode.dark);
    expect(notified, 1);

    // Персистентность: новый сервис читает сохранённое значение.
    final reloaded = ThemeService();
    await reloaded.init();
    expect(reloaded.mode, ThemeMode.dark);
  });
}
