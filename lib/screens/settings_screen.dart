import 'package:flutter/material.dart';
import '../services/theme_service.dart';

/// Минимальный экран настроек. Сейчас — только выбор темы.
/// Сюда же позже ляжет смена роли (когда ролей станет несколько).
class SettingsScreen extends StatelessWidget {
  final ThemeService themeService;

  const SettingsScreen({super.key, required this.themeService});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Настройки')),
      // Слушаем сервис: отметка радио обновится сразу после выбора.
      body: ListenableBuilder(
        listenable: themeService,
        builder: (context, _) => RadioGroup<ThemeMode>(
          // groupValue + onChanged переехали с каждой плитки на общий предок
          // (Radio API redesign, Flutter 3.32+). Плитки несут только value.
          groupValue: themeService.mode,
          onChanged: (m) {
            if (m != null) themeService.setMode(m);
          },
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: const [
              Padding(
                padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text('Тема',
                    style:
                        TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              ),
              RadioListTile<ThemeMode>(
                title: Text('Как в системе'),
                value: ThemeMode.system,
              ),
              RadioListTile<ThemeMode>(
                title: Text('Светлая'),
                value: ThemeMode.light,
              ),
              RadioListTile<ThemeMode>(
                title: Text('Тёмная'),
                value: ThemeMode.dark,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
