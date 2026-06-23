import 'package:flutter/material.dart';
import 'package:interview_helper_system/models/models.dart';
import 'package:interview_helper_system/screens/grades_screen.dart';
import 'package:interview_helper_system/screens/topic_session.dart';
import 'package:interview_helper_system/screens/tracks_loader.dart';
import 'package:interview_helper_system/services/progress_service.dart';
import 'package:interview_helper_system/services/question_repository.dart';
import 'package:interview_helper_system/theme.dart';
import 'package:interview_helper_system/utils/tap_lock.dart';

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

class _HomeScreenState extends State<HomeScreen>
    with TracksLoader<HomeScreen>, TapLock<HomeScreen> {
  @override
  QuestionRepository get repository => widget.repository;

  @override
  String get loadErrorMessage => 'Не удалось загрузить вопросы';

  // ── Navigation helpers ──────────────────────────────────────────────────

  Future<void> _openRecommendedSession() async {
    if (tracks.isEmpty) return;

    final weak = widget.progress.weakestTopics(limit: 1);
    final topicTitle = weak.isNotEmpty ? weak.first.title : null;

    // 1) Слабая тема, если по ней есть непройденные вопросы.
    final byTopic = topicTitle == null
        ? null
        : _firstTrackWithUnmastered((q) => q.topic == topicTitle);
    // 2) Иначе — первый трек с любыми непройденными вопросами.
    final target = byTopic ?? _firstTrackWithUnmastered((_) => true);

    // 3) Всё освоено — открываем первый трек.
    await _pushGrades(target ?? tracks.first);
  }

  /// Первый трек (по порядку грейдов), где есть непройденный вопрос,
  /// удовлетворяющий [test]. Возвращает null, если такого трека нет.
  Track? _firstTrackWithUnmastered(bool Function(Question) test) {
    for (final track in tracks) {
      final grades = [...track.grades]
        ..sort((a, b) => a.order.compareTo(b.order));
      for (final grade in grades) {
        final mastered = widget.progress.masteredIds(track.id, grade.id);
        final hit =
            grade.questions.any((q) => test(q) && !mastered.contains(q.id));
        if (hit) return track;
      }
    }
    return null;
  }

  /// Тык по слабой теме → сессия по этой теме (общий хелпер с экраном «Темы»).
  /// guardTap: повторный тап по строке не открывает второй экран.
  void _openWeakTopic(String topicTitle) => guardTap(
        () => startTopicSession(
          context,
          tracks: tracks,
          progress: widget.progress,
          topicTitle: topicTitle,
        ),
      );

  /// Возвращает [Future] пуша — завершается при возврате с грейдов. Это даёт
  /// guardTap держать лок до закрытия экрана (защита от двойного пуша грейдов).
  Future<void> _pushGrades(Track track) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: 'Грейды'),
        builder: (_) => GradesScreen(track: track, progress: widget.progress),
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
      body: error != null
          ? ErrorRetryView(title: loadErrorMessage, onRetry: retryLoad)
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
                  if (loading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else
                    ...tracks
                        .where((t) => t.category != 'language')
                        .map(_trackRow),
                ],
              ),
            ),
    );
  }

  // ── Metrics row ─────────────────────────────────────────────────────────

  Widget _metricsRow() {
    final p = widget.progress;
    final accuracyPct = (p.overallAccuracy * 100).round();
    final accuracyLabel = p.hasTrainedEver ? '$accuracyPct%' : '—';

    // IntrinsicHeight + stretch гарантируют равную высоту всех трёх карточек
    // независимо от длины подписи или системного масштаба шрифта.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
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
              label: 'серия',
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
      ),
    );
  }

  // ── Weak topics ─────────────────────────────────────────────────────────

  /// Названия тем, у которых освоены все вопросы каталога.
  Set<String> _fullyMasteredTopicTitles() {
    if (tracks.isEmpty) return const {};
    return {
      for (final t in buildTopicCatalog(tracks, widget.progress))
        if (t.allMastered) t.title,
    };
  }

  Widget _weakTopicsSection() {
    // Прячем полностью проработанные темы: тыкать их в дрилле некуда
    // (непройденных вопросов нет), и это снимает противоречие «слабая по
    // точности, но уже пройдена по освоенности».
    final masteredTitles = _fullyMasteredTopicTitles();
    final topics = widget.progress
        .weakestTopics()
        .where((t) => !masteredTitles.contains(t.title))
        .toList();

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
        onPressed: loading ? null : () => guardTap(_openRecommendedSession),
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
    final totalQ = track.grades.fold<int>(0, (s, g) => s + g.questions.length);
    final mastered = track.grades.fold<int>(
      0,
      (s, g) => s + widget.progress.masteredIds(track.id, g.id).length,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        onTap: () => guardTap(() => _pushGrades(track)),
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
  });
  final String value;
  final String label;

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
