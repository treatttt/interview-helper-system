import 'dart:async';

import 'package:flutter/material.dart';
import 'package:interview_helper_system/services/progress_service.dart';
import 'package:interview_helper_system/services/theme_service.dart';

/// Экран настроек: выбор темы + деструктивный сброс прогресса.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    required this.themeService,
    required this.progress,
    super.key,
  });
  final ThemeService themeService;
  final ProgressService progress;

  Future<void> _confirmReset(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Сбросить весь прогресс?'),
        content: const Text('Действие необратимо.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Сбросить'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await progress.resetAll();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Прогресс сброшен')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Настройки')),
      body: ListenableBuilder(
        listenable: themeService,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(
                'Тема',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
            RadioGroup<ThemeMode>(
              groupValue: themeService.mode,
              onChanged: (m) {
                if (m != null) unawaited(themeService.setMode(m));
              },
              child: const Column(
                children: [
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
            const SizedBox(height: 32),
            const Divider(height: 1),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                ),
                onPressed: () => unawaited(_confirmReset(context)),
                child: const Text('Сбросить весь прогресс'),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
