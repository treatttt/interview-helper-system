import 'dart:async';

import 'package:flutter/material.dart';
import 'package:interview_helper_system/models/models.dart';
import 'package:interview_helper_system/screens/grades_screen.dart';
import 'package:interview_helper_system/services/progress_service.dart';
import 'package:interview_helper_system/services/question_repository.dart';
import 'package:interview_helper_system/theme.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    required this.repository,
    required this.progress,
    super.key,
  });
  final QuestionRepository repository;
  final ProgressService progress;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Track> _tracks = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final tracks = await widget.repository.loadTracks();
      if (!mounted) return;
      setState(() {
        _tracks = tracks.toList()..sort((a, b) => a.order.compareTo(b.order));
        _loading = false;
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _error = 'Не удалось загрузить вопросы';
        _loading = false;
      });
    }
  }

  // ── Navigation helpers ──────────────────────────────────────────────────

  void _openRecommendedSession() {
    if (_tracks.isEmpty) return;
    // Weakest topic → find the track that contains it; fallback to first track
    // with remaining questions.
    final weak = widget.progress.weakestTopics(limit: 1);
    if (weak.isNotEmpty) {
      final topicTitle = weak.first.title;
      for (final track in _tracks) {
        final grades = [...track.grades]
          ..sort((a, b) => a.order.compareTo(b.order));
        for (final grade in grades) {
          final mastered = widget.progress.masteredIds(track.id, grade.id);
          final has = grade.questions
              .any((q) => q.topic == topicTitle && !mastered.contains(q.id));
          if (has) {
            _pushGrades(track);
            return;
          }
        }
      }
    }
    // Fallback: first track with unmastered questions.
    for (final track in _tracks) {
      final grades = [...track.grades]
        ..sort((a, b) => a.order.compareTo(b.order));
      for (final grade in grades) {
        final mastered = widget.progress.masteredIds(track.id, grade.id);
        if (grade.questions.any((q) => !mastered.contains(q.id))) {
          _pushGrades(track);
          return;
        }
      }
    }
    // All mastered — open first track anyway.
    _pushGrades(_tracks.first);
  }

  void _openWeakTopic(String topicTitle) {
    for (final track in _tracks) {
      final grades = [...track.grades]
        ..sort((a, b) => a.order.compareTo(b.order));
      for (final grade in grades) {
        final mastered = widget.progress.masteredIds(track.id, grade.id);
        final has = grade.questions
            .any((q) => q.topic == topicTitle && !mastered.contains(q.id));
        if (has) {
          _pushGrades(track);
          return;
        }
      }
    }
    if (_tracks.isNotEmpty) _pushGrades(_tracks.first);
  }

  void _pushGrades(Track track) {
    unawaited(
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => GradesScreen(track: track, progress: widget.progress),
        ),
      ),
    );
  }

  // ── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Обзор', style: TextStyle(fontWeight: FontWeight.w500)),
      ),
      body: _error != null
          ? _errorView()
          : ListenableBuilder(
              listenable: widget.progress,
              builder: (context, _) => ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [
                  _metricsRow(),
                  const SizedBox(height: 20),
                  _weakTopicsSection(),
                  const SizedBox(height: 16),
                  _ctaButton(),
                  const SizedBox(height: 28),
                  _tracksSectionHeader(),
                  const SizedBox(height: 8),
                  if (_loading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else
                    ..._tracks.map(_trackRow),
                ],
              ),
            ),
    );
  }

  // ── Metrics row ─────────────────────────────────────────────────────────

  Widget _metricsRow() {
    final p = widget.progress;
    final accuracyPct = (p.overallAccuracy * 100).round();
    final accuracyLabel =
        p.hasTrainedEver ? '$accuracyPct%' : '—';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _MetricCard(
            value: accuracyLabel,
            label: 'Точность',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MetricCard(
            value: '${p.streak}',
            label: p.streak == 1 ? 'день' : 'дней',
            sublabel: 'серия',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MetricCard(
            value: '${p.totalMastered}',
            label: 'освоено',
          ),
        ),
      ],
    );
  }

  // ── Weak topics ─────────────────────────────────────────────────────────

  Widget _weakTopicsSection() {
    final topics = widget.progress.weakestTopics();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('Слабые темы'),
        const SizedBox(height: 8),
        if (topics.isEmpty)
          _emptyTopicsHint()
        else
          _WeakTopicsCard(topics: topics, onTopicTap: _openWeakTopic),
      ],
    );
  }

  Widget _emptyTopicsHint() {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 18, color: cs.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              widget.progress.hasTrainedEver
                  ? 'Пройди ещё несколько вопросов — слабые темы появятся здесь.'
                  : 'Начни первую тренировку, чтобы увидеть свои слабые места.',
              style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }

  // ── CTA ─────────────────────────────────────────────────────────────────

  Widget _ctaButton() {
    final label = widget.progress.hasTrainedEver
        ? 'Продолжить тренировку'
        : 'Начать тренировку';
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: _loading ? null : _openRecommendedSession,
        child: Text(label),
      ),
    );
  }

  // ── Track list (secondary) ───────────────────────────────────────────────

  Widget _tracksSectionHeader() {
    final cs = Theme.of(context).colorScheme;
    return Text(
      'Все направления',
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: cs.onSurfaceVariant,
        letterSpacing: 0.3,
      ),
    );
  }

  Widget _trackRow(Track track) {
    final cs = Theme.of(context).colorScheme;
    final totalQ =
        track.grades.fold<int>(0, (s, g) => s + g.questions.length);
    final mastered = track.grades.fold<int>(
      0,
      (s, g) => s + widget.progress.masteredIds(track.id, g.id).length,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        onTap: () => _pushGrades(track),
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  track.title,
                  style: TextStyle(
                    fontSize: 14,
                    color: cs.onSurface,
                  ),
                ),
              ),
              Text(
                '$mastered / $totalQ',
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
              ),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right, size: 16, color: cs.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }

  // ── Error ────────────────────────────────────────────────────────────────

  Widget _errorView() {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_outlined, size: 48, color: cs.onSurfaceVariant),
            const SizedBox(height: 16),
            const Text(
              'Не удалось загрузить вопросы',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 6),
            Text(
              'Что-то пошло не так. Попробуй ещё раз.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () {
                setState(() {
                  _error = null;
                  _loading = true;
                });
                unawaited(_load());
              },
              child: const Text('Попробовать снова'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    final cs = Theme.of(context).colorScheme;
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: cs.onSurfaceVariant,
        letterSpacing: 0.3,
      ),
    );
  }
}

// ── Reusable sub-widgets ────────────────────────────────────────────────────

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.value,
    required this.label,
    this.sublabel,
  });
  final String value;
  final String label;
  final String? sublabel;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: cs.onSurface,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 3),
          if (sublabel != null)
            Text(
              sublabel!,
              style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
            ),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _WeakTopicsCard extends StatelessWidget {
  const _WeakTopicsCard({
    required this.topics,
    required this.onTopicTap,
  });
  final List<TopicStat> topics;
  final void Function(String) onTopicTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final s = AppSemanticColors.of(context);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        children: [
          for (int i = 0; i < topics.length; i++) ...[
            if (i > 0)
              Divider(height: 1, thickness: 1, color: cs.outlineVariant),
            _TopicRow(
              topic: topics[i],
              warningColor: s.warningFg,
              onTap: () => onTopicTap(topics[i].title),
            ),
          ],
        ],
      ),
    );
  }
}

class _TopicRow extends StatelessWidget {
  const _TopicRow({
    required this.topic,
    required this.warningColor,
    required this.onTap,
  });
  final TopicStat topic;
  final Color warningColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final pct = (topic.accuracy * 100).round();

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    topic.title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '$pct%',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: warningColor,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.chevron_right,
                  size: 16,
                  color: cs.onSurfaceVariant,
                ),
              ],
            ),
            const SizedBox(height: 7),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: topic.accuracy,
                minHeight: 4,
                backgroundColor: cs.surfaceContainerHighest,
                color: warningColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
