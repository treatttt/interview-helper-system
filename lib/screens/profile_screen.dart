import 'dart:async';

import 'package:flutter/material.dart';
import 'package:interview_helper_system/screens/settings_screen.dart';
import 'package:interview_helper_system/screens/topic_session.dart';
import 'package:interview_helper_system/screens/tracks_loader.dart';
import 'package:interview_helper_system/services/progress_service.dart';
import 'package:interview_helper_system/services/question_repository.dart';
import 'package:interview_helper_system/services/theme_service.dart';
import 'package:interview_helper_system/theme.dart';
import 'package:interview_helper_system/utils/tap_lock.dart';
import 'package:interview_helper_system/widgets/weak_topics_card.dart';

/// Экран «Профиль»: статистика пользователя + слабые темы.
/// Настройки (тема, сброс прогресса) — за иконкой шестерёнки.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    required this.progress,
    required this.themeService,
    required this.repository,
    super.key,
  });

  final ProgressService progress;
  final ThemeService themeService;
  final QuestionRepository repository;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with TracksLoader<ProfileScreen>, TapLock<ProfileScreen> {
  @override
  QuestionRepository get repository => widget.repository;

  @override
  String get loadErrorMessage => 'Не удалось загрузить темы';

  void _openWeakTopic(String topicTitle) => guardTap(
        () => startTopicSession(
          context,
          tracks: tracks,
          progress: widget.progress,
          topicTitle: topicTitle,
        ),
      );

  void _openSettings() {
    unawaited(
      Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => SettingsScreen(
            themeService: widget.themeService,
            progress: widget.progress,
          ),
        ),
      ),
    );
  }

  /// Названия тем, у которых освоены все вопросы каталога.
  Set<String> _fullyMasteredTopicTitles() {
    if (tracks.isEmpty) return const {};
    return {
      for (final t in buildTopicCatalog(tracks, widget.progress))
        if (t.allMastered) t.title,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Профиль', style: TextStyle(fontWeight: FontWeight.w500)),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Настройки',
            onPressed: _openSettings,
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: widget.progress,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _StatsSection(progress: widget.progress),
            const SizedBox(height: 24),
            _WeakTopicsSection(
              progress: widget.progress,
              masteredTitles: _fullyMasteredTopicTitles(),
              onTopicTap: _openWeakTopic,
            ),
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
    final accuracyLabel = progress.hasTrainedEver
        ? '${(progress.overallAccuracy * 100).round()} %'
        : '—';

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
        _StatRow(
          icon: Icons.percent,
          iconColor: s.infoFg,
          label: 'Общая точность',
          value: accuracyLabel,
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

class _WeakTopicsSection extends StatelessWidget {
  const _WeakTopicsSection({
    required this.progress,
    required this.masteredTitles,
    required this.onTopicTap,
  });

  final ProgressService progress;
  final Set<String> masteredTitles;
  final void Function(String) onTopicTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final topics = progress
        .weakestTopics(limit: 5)
        .where((t) => !masteredTitles.contains(t.title))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            'Слабые темы',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: cs.onSurfaceVariant,
            ),
          ),
        ),
        if (topics.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: cs.outlineVariant),
            ),
            child: Row(
              children: <Widget>[
                Icon(Icons.info_outline, size: 18, color: cs.onSurfaceVariant),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    progress.hasTrainedEver
                        ? 'Пройди ещё несколько вопросов — слабые темы появятся здесь.'
                        : 'Начни первую тренировку, чтобы увидеть свои слабые места.',
                    style:
                        TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          )
        else
          WeakTopicsCard(topics: topics, onTopicTap: onTopicTap),
      ],
    );
  }
}
