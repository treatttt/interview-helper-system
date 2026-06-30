import 'dart:async';

import 'package:flutter/material.dart';
import 'package:interview_helper_system/models/models.dart';
import 'package:interview_helper_system/screens/settings_screen.dart';
import 'package:interview_helper_system/screens/tracks_loader.dart';
import 'package:interview_helper_system/services/progress_service.dart';
import 'package:interview_helper_system/services/question_repository.dart';
import 'package:interview_helper_system/services/reminder_service.dart';
import 'package:interview_helper_system/services/theme_service.dart';
import 'package:interview_helper_system/services/user_profile_service.dart';
import 'package:interview_helper_system/theme.dart';
import 'package:interview_helper_system/utils/leveling.dart';
import 'package:interview_helper_system/utils/reminder_prompt.dart';
import 'package:interview_helper_system/widgets/app_dialog.dart';

/// Экран «Профиль»: карточка пользователя, уровень/XP, достижения и блок
/// «Цель и настройки» (целевой грейд, направление, тема, напоминания).
/// Расширенные настройки (сброс прогресса) — за иконкой шестерёнки.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    required this.progress,
    required this.themeService,
    required this.reminderService,
    required this.userProfile,
    required this.repository,
    super.key,
  });

  final ProgressService progress;
  final ThemeService themeService;
  final ReminderService reminderService;
  final UserProfileService userProfile;
  final QuestionRepository repository;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with TracksLoader<ProfileScreen> {
  @override
  QuestionRepository get repository => widget.repository;

  @override
  String get loadErrorMessage => 'Не удалось загрузить темы';

  // ── Разрешение направления/грейда из каталога ────────────────────────────

  Track? get _direction {
    final id = widget.userProfile.directionTrackId;
    if (id == null) return null;
    for (final t in tracks) {
      if (t.id == id) return t;
    }
    return null;
  }

  Grade? get _targetGrade {
    final id = widget.userProfile.targetGradeId;
    final track = _direction;
    if (id == null || track == null) return null;
    for (final g in track.grades) {
      if (g.id == id) return g;
    }
    return null;
  }

  String get _directionTitle => _direction?.title ?? 'Не выбрано';
  String get _targetGradeTitle => _targetGrade?.title ?? 'Не выбрано';

  void _openSettings() {
    unawaited(
      Navigator.push(
        context,
        MaterialPageRoute<void>(
          settings: const RouteSettings(name: 'Настройки'),
          builder: (_) => SettingsScreen(
            themeService: widget.themeService,
            reminderService: widget.reminderService,
            progress: widget.progress,
          ),
        ),
      ),
    );
  }

  // ── Действия ──────────────────────────────────────────────────────────────

  Future<void> _editName() async {
    final result = await _showNameDialog(
      context,
      first: widget.userProfile.firstName,
      last: widget.userProfile.lastName,
    );
    if (result == null) return;
    await widget.userProfile.setName(result.first, result.last);
  }

  Future<void> _pickDirection() async {
    if (tracks.isEmpty) return;
    final picked = await showAppSelectionDialog<String>(
      context: context,
      title: 'Направление',
      options: [
        for (final t in tracks)
          AppSelectionOption(value: t.id, label: t.title),
      ],
      selected: widget.userProfile.directionTrackId,
    );
    if (picked != null) await widget.userProfile.setDirection(picked);
  }

  Future<void> _pickTargetGrade() async {
    final track = _direction;
    if (track == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Сначала выберите направление')),
      );
      return;
    }
    final grades = [...track.grades]..sort((a, b) => a.order.compareTo(b.order));
    final picked = await showAppSelectionDialog<String>(
      context: context,
      title: 'Целевой грейд',
      options: [
        for (final g in grades) AppSelectionOption(value: g.id, label: g.title),
      ],
      selected: widget.userProfile.targetGradeId,
    );
    if (picked != null) await widget.userProfile.setTargetGrade(picked);
  }

  Future<void> _pickTheme() async {
    final picked = await showAppSelectionDialog<ThemeMode>(
      context: context,
      title: 'Тема оформления',
      options: const [
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
      ],
      selected: widget.themeService.mode,
    );
    if (picked != null) await widget.themeService.setMode(picked);
  }

  Future<void> _toggleReminder(bool value) async {
    if (value) {
      await enableRemindersWithPrompt(context, widget.reminderService);
    } else {
      await widget.reminderService.setEnabled(false);
    }
  }

  static String _themeLabel(ThemeMode mode) => switch (mode) {
        ThemeMode.system => 'Как в системе',
        ThemeMode.light => 'Светлая',
        ThemeMode.dark => 'Тёмная',
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Профиль',
            style: TextStyle(fontWeight: FontWeight.w500),),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Настройки',
            onPressed: _openSettings,
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: Listenable.merge([
          widget.progress,
          widget.userProfile,
          widget.themeService,
          widget.reminderService,
        ]),
        builder: (context, _) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            _ProfileCard(
              name: widget.userProfile.displayName,
              subtitle: _subtitle(),
              onEdit: _editName,
            ),
            const SizedBox(height: 16),
            _LevelCard(xp: widget.progress.xp),
            const SizedBox(height: 24),
            const _SectionLabel('Достижения'),
            const SizedBox(height: 12),
            _AchievementsRow(
              progress: widget.progress,
              gradeLabel: _targetGrade?.title,
            ),
            const SizedBox(height: 24),
            const _SectionLabel('Цель и настройки'),
            const SizedBox(height: 12),
            _SettingsCard(
              children: [
                _SettingsRow(
                  icon: Icons.flag_outlined,
                  title: 'Целевой грейд',
                  value: _targetGradeTitle,
                  onTap: _pickTargetGrade,
                ),
                const _RowDivider(),
                _SettingsRow(
                  icon: Icons.insights_outlined,
                  title: 'Направление',
                  value: _directionTitle,
                  onTap: _pickDirection,
                ),
                const _RowDivider(),
                _SettingsRow(
                  icon: Icons.dark_mode_outlined,
                  title: 'Тема',
                  value: _themeLabel(widget.themeService.mode),
                  onTap: _pickTheme,
                ),
                const _RowDivider(),
                _ReminderRow(
                  enabled: widget.reminderService.enabled,
                  onChanged: (v) => unawaited(_toggleReminder(v)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _subtitle() {
    final dir = _direction?.title;
    final grade = _targetGrade?.title;
    if (dir == null && grade == null) {
      return 'Заполни цель и направление';
    }
    if (grade == null) return dir!;
    if (dir == null) return 'Цель — $grade';
    return '$dir · цель $grade';
  }
}

/// Диалог редактирования имени: имя обязательно, фамилия — нет.
/// Возвращает `(first, last)` или null при отмене.
Future<({String first, String? last})?> _showNameDialog(
  BuildContext context, {
  required String first,
  required String? last,
}) {
  final firstCtrl = TextEditingController(text: first);
  final lastCtrl = TextEditingController(text: last ?? '');
  return showDialog<({String first, String? last})>(
    context: context,
    builder: (ctx) {
      return AnimatedBuilder(
        animation: firstCtrl,
        builder: (ctx, _) {
          final canSave = firstCtrl.text.trim().isNotEmpty;
          return AlertDialog(
            title: const Text('Имя'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: firstCtrl,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Имя',
                    hintText: 'Как тебя зовут',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: lastCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Фамилия (необязательно)',
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Отмена'),
              ),
              TextButton(
                onPressed: canSave
                    ? () => Navigator.pop(
                          ctx,
                          (first: firstCtrl.text, last: lastCtrl.text),
                        )
                    : null,
                child: const Text('Сохранить'),
              ),
            ],
          );
        },
      );
    },
  );
}

/// Карточка пользователя: аватар-заглушка, имя, подпись (направление · цель)
/// и карандаш редактирования. Нажатие на карточку также открывает редактор.
class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.name,
    required this.subtitle,
    required this.onEdit,
  });

  final String name;
  final String subtitle;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onEdit,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: cs.outlineVariant),
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: cs.surfaceContainerHighest,
                ),
                child: Icon(Icons.person, size: 30, color: cs.onSurfaceVariant),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.2,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 20),
                tooltip: 'Редактировать имя',
                color: cs.onSurfaceVariant,
                onPressed: onEdit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Карточка уровня: «УРОВЕНЬ N · ТИР», прогресс-бар XP и подпись до следующего.
class _LevelCard extends StatelessWidget {
  const _LevelCard({required this.xp});

  final int xp;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final info = levelForXp(xp);
    final fraction = info.xpIntoLevel / info.xpPerLevel;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'УРОВЕНЬ ${info.level} · ${info.tier.toUpperCase()}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.1,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ),
              Text(
                '${info.xpIntoLevel} / ${info.xpPerLevel} XP',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 6,
              backgroundColor: cs.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'До уровня «${info.nextTier}» — ${info.xpToNext} XP',
            style: TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// Ряд достижений из реального прогресса: серия, число освоенных вопросов,
/// точность и целевой грейд.
class _AchievementsRow extends StatelessWidget {
  const _AchievementsRow({required this.progress, required this.gradeLabel});

  final ProgressService progress;
  final String? gradeLabel;

  @override
  Widget build(BuildContext context) {
    final s = AppSemanticColors.of(context);
    final trained = progress.hasTrainedEver;
    final accuracy = trained
        ? 'Точность ${(progress.overallAccuracy * 100).round()}%'
        : 'Точность —';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _AchievementTile(
          icon: Icons.local_fire_department,
          color: Theme.of(context).colorScheme.primary,
          caption: trained ? 'Серия ${progress.streak} дн.' : 'Серия —',
        ),
        _AchievementTile(
          icon: Icons.check_circle_outline,
          color: s.progressGreen,
          caption: '${progress.totalMastered} вопросов',
        ),
        _AchievementTile(
          icon: Icons.percent,
          color: const Color(0xFFC2871C),
          caption: accuracy,
        ),
        _AchievementTile(
          icon: Icons.flag_outlined,
          color: const Color(0xFFB0B0BA),
          caption: 'Грейд ${gradeLabel ?? '—'}',
        ),
      ],
    );
  }
}

class _AchievementTile extends StatelessWidget {
  const _AchievementTile({
    required this.icon,
    required this.color,
    required this.caption,
  });

  final IconData icon;
  final Color color;
  final String caption;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, size: 24, color: Colors.white),
          ),
          const SizedBox(height: 7),
          Text(
            caption,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.1,
        color: cs.onSurfaceVariant,
      ),
    );
  }
}

/// Белая карточка-список с разделителями (блок «Цель и настройки»).
class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}

class _RowDivider extends StatelessWidget {
  const _RowDivider();

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 1,
      indent: 52,
      color: Theme.of(context).colorScheme.outlineVariant,
    );
  }
}

/// Строка-навигация внутри карточки настроек: иконка, заголовок, значение, шеврон.
class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.title,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 20, color: cs.onSurface),
            const SizedBox(width: 13),
            Expanded(
              child: Text(title, style: const TextStyle(fontSize: 15)),
            ),
            Text(
              value,
              style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, size: 20, color: cs.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

/// Строка напоминаний с инлайновым переключателем (без показа времени).
class _ReminderRow extends StatelessWidget {
  const _ReminderRow({required this.enabled, required this.onChanged});

  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(15, 6, 12, 6),
      child: Row(
        children: [
          Icon(Icons.notifications_outlined, size: 20, color: cs.onSurface),
          const SizedBox(width: 13),
          const Expanded(
            child: Text('Напоминания', style: TextStyle(fontSize: 15)),
          ),
          Switch(value: enabled, onChanged: onChanged),
        ],
      ),
    );
  }
}
