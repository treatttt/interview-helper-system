import 'dart:async';

import 'package:flutter/material.dart';
import 'package:interview_helper_system/services/progress_service.dart';
import 'package:interview_helper_system/services/reminder_service.dart';
import 'package:interview_helper_system/services/theme_service.dart';
import 'package:interview_helper_system/widgets/app_dialog.dart';

/// Экран настроек: тема, ежедневные напоминания + деструктивный сброс прогресса.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    required this.themeService,
    required this.reminderService,
    required this.progress,
    super.key,
  });
  final ThemeService themeService;
  final ReminderService reminderService;
  final ProgressService progress;

  static const _themeOptions = <AppSelectionOption<ThemeMode>>[
    AppSelectionOption(
      value: ThemeMode.system,
      label: 'Как в системе',
      icon: Icons.brightness_auto_outlined,
    ),
    AppSelectionOption(
      value: ThemeMode.light,
      label: 'Светлая',
      icon: Icons.light_mode_outlined,
    ),
    AppSelectionOption(
      value: ThemeMode.dark,
      label: 'Тёмная',
      icon: Icons.dark_mode_outlined,
    ),
  ];

  static String _themeLabel(ThemeMode mode) => switch (mode) {
        ThemeMode.system => 'Как в системе',
        ThemeMode.light => 'Светлая',
        ThemeMode.dark => 'Тёмная',
      };

  Future<void> _pickTheme(BuildContext context) async {
    final picked = await showAppSelectionDialog<ThemeMode>(
      context: context,
      title: 'Тема оформления',
      options: _themeOptions,
      selected: themeService.mode,
    );
    if (picked != null) await themeService.setMode(picked);
  }

  Future<void> _toggleReminder(BuildContext context, bool value) async {
    final ok = await reminderService.setEnabled(value);
    if (!ok && value && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Разрешите уведомления, чтобы получать напоминания'),
        ),
      );
    }
  }

  Future<void> _pickReminderTime(BuildContext context) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: reminderService.time,
    );
    if (picked != null) await reminderService.setTime(picked);
  }

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
        listenable: Listenable.merge([themeService, reminderService]),
        builder: (context, _) => ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            _sectionLabel('Тема'),
            _SettingRow(
              icon: Icons.palette_outlined,
              title: 'Тема оформления',
              trailing: _themeLabel(themeService.mode),
              onTap: () => unawaited(_pickTheme(context)),
            ),
            const SizedBox(height: 20),
            _sectionLabel('Напоминания'),
            SwitchListTile(
              secondary: const Icon(Icons.notifications_outlined),
              title: const Text('Ежедневное напоминание'),
              subtitle: const Text('Подсказка вернуться к тренировкам'),
              value: reminderService.enabled,
              onChanged: (v) => unawaited(_toggleReminder(context, v)),
            ),
            _SettingRow(
              icon: Icons.schedule_outlined,
              title: 'Время напоминания',
              trailing: reminderService.time.format(context),
              enabled: reminderService.enabled,
              onTap: () => unawaited(_pickReminderTime(context)),
            ),
            const SizedBox(height: 28),
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

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(
        text,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// Строка настройки в стиле списка: иконка, заголовок и значение справа.
class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.icon,
    required this.title,
    required this.trailing,
    required this.onTap,
    this.enabled = true,
  });

  final IconData icon;
  final String title;
  final String trailing;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              trailing,
              style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant),
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, size: 20, color: cs.onSurfaceVariant),
          ],
        ),
        onTap: enabled ? onTap : null,
      ),
    );
  }
}
