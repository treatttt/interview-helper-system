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
        builder: (context, _) => ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text('Тема',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            ),
            RadioListTile<ThemeMode>(
              title: const Text('Как в системе'),
              value: ThemeMode.system,
              groupValue: themeService.mode,
              onChanged: (m) => themeService.setMode(m!),
            ),
            RadioListTile<ThemeMode>(
              title: const Text('Светлая'),
              value: ThemeMode.light,
              groupValue: themeService.mode,
              onChanged: (m) => themeService.setMode(m!),
            ),
            RadioListTile<ThemeMode>(
              title: const Text('Тёмная'),
              value: ThemeMode.dark,
              groupValue: themeService.mode,
              onChanged: (m) => themeService.setMode(m!),
            ),
          ],
        ),
      ),
    );
  }
}
