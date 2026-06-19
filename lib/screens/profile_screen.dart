import 'dart:async';

import 'package:flutter/material.dart';
import 'package:interview_helper_system/services/progress_service.dart';
import 'package:interview_helper_system/services/theme_service.dart';
import 'package:interview_helper_system/theme.dart';

/// Экран «Профиль»: статистика пользователя + настройки темы.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({
    required this.progress,
    required this.themeService,
    super.key,
  });

  final ProgressService progress;
  final ThemeService themeService;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Профиль', style: TextStyle(fontWeight: FontWeight.w500)),
      ),
      body: ListenableBuilder(
        listenable: Listenable.merge([progress, themeService]),
        builder: (context, _) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _StatsSection(progress: progress),
            const SizedBox(height: 24),
            _ThemeSection(themeService: themeService),
          ],
        ),
      ),
    );
  }
}

class _StatsSection extends StatelessWidget {
  const _StatsSection({required this.progress});

  final ProgressService progress;

  @override
  Widget build(BuildContext context) {
    final s = AppSemanticColors.of(context);
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            'Статистика',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: cs.onSurfaceVariant,
            ),
          ),
        ),
        // XP — info-tinted, как на главном экране
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: s.infoBg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Твой прогресс',
                  style: TextStyle(color: s.infoFg, fontSize: 13),),
              const SizedBox(height: 4),
              Text('${progress.xp} XP',
                  style: TextStyle(
                      color: s.infoFg,
                      fontSize: 22,
                      fontWeight: FontWeight.w500,),),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _StatRow(
          icon: Icons.local_fire_department,
          iconColor: const Color(0xFFF5871F),
          label: 'Серия дней',
          value: progress.hasTrainedEver ? '${progress.streak} д.' : '—',
        ),
        _StatRow(
          icon: Icons.check_circle_outline,
          iconColor: s.successFg,
          label: 'Вопросов освоено',
          value: '${progress.totalMastered}',
        ),
      ],
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(icon, size: 22, color: iconColor),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(fontSize: 15)),
          const Spacer(),
          Text(value,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),),
        ],
      ),
    );
  }
}

class _ThemeSection extends StatelessWidget {
  const _ThemeSection({required this.themeService});

  final ThemeService themeService;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            'Тема',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: cs.onSurfaceVariant,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: cs.outlineVariant),
          ),
          child: RadioGroup<ThemeMode>(
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
        ),
      ],
    );
  }
}
