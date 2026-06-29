import 'package:flutter/material.dart';
import 'package:interview_helper_system/models/models.dart';
import 'package:interview_helper_system/screens/topic_session.dart';
import 'package:interview_helper_system/services/progress_service.dart';
import 'package:interview_helper_system/utils/ru_format.dart';
import 'package:interview_helper_system/utils/tap_lock.dart';
import 'package:interview_helper_system/utils/topic_icons.dart';
import 'package:interview_helper_system/utils/track_visuals.dart';

/// Второй экран Практики: темы (тесты) внутри выбранного направления.
/// Сверху — заголовок с направлением и фильтр по грейду; ниже — список тем с
/// прогрессом. Тап по теме запускает дрилл по непройденным вопросам этой темы
/// в рамках выбранного направления (и грейда, если выбран).
class PracticeTopicsScreen extends StatefulWidget {
  const PracticeTopicsScreen({
    required this.track,
    required this.progress,
    super.key,
  });

  final Track track;
  final ProgressService progress;

  @override
  State<PracticeTopicsScreen> createState() => _PracticeTopicsScreenState();
}

class _PracticeTopicsScreenState extends State<PracticeTopicsScreen>
    with TapLock<PracticeTopicsScreen> {
  /// id выбранного грейда; null — «Все».
  String? _gradeId;

  /// Грейды направления, в которых есть валидные вопросы (для чипов фильтра).
  List<Grade> get _gradesWithQuestions => [
        ...widget.track.grades
            .where((g) => g.questions.any((q) => q.isValid)),
      ]..sort((a, b) => a.order.compareTo(b.order));

  /// Копия трека, суженная до выбранного грейда (или сам трек при «Все»).
  Track get _effectiveTrack {
    if (_gradeId == null) return widget.track;
    return Track(
      id: widget.track.id,
      title: widget.track.title,
      order: widget.track.order,
      description: widget.track.description,
      category: widget.track.category,
      grades: widget.track.grades.where((g) => g.id == _gradeId).toList(),
    );
  }

  void _openTopic(String title) => guardTap(
        () => startTopicSession(
          context,
          tracks: [_effectiveTrack],
          progress: widget.progress,
          topicTitle: title,
        ),
      );

  Future<void> _confirmResetTopic(String title) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Сбросить тему?'),
        content: Text(
          'Все вопросы темы «$title» снова станут доступны в полном объёме.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Сбросить'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await resetTopic([_effectiveTrack], widget.progress, title);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListenableBuilder(
          listenable: widget.progress,
          builder: (context, _) {
            final track = _effectiveTrack;
            final topics = buildTopicCatalog([track], widget.progress);
            final questionCount = track.grades
                .fold<int>(0, (s, g) => s + g.questions.length);

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                _header(),
                const SizedBox(height: 16),
                _gradeFilter(),
                const SizedBox(height: 20),
                _sectionLabel(
                  'Темы · $questionCount ${pluralQuestions(questionCount)}',
                ),
                const SizedBox(height: 8),
                if (topics.isEmpty)
                  _emptyHint()
                else
                  _topicsCard(topics),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _header() {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          tooltip: 'Назад',
          onPressed: () => Navigator.of(context).maybePop(),
          padding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
        ),
        const SizedBox(width: 4),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'НАПРАВЛЕНИЕ',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.1,
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              widget.track.title,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ],
    );
  }

  Widget _gradeFilter() {
    final grades = _gradesWithQuestions;
    // Один грейд — фильтровать нечего, чипы не нужны.
    if (grades.length < 2) return const SizedBox.shrink();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _gradeChip(label: 'Все', id: null),
          for (final g in grades) ...[
            const SizedBox(width: 8),
            _gradeChip(label: g.title, id: g.id),
          ],
        ],
      ),
    );
  }

  Widget _gradeChip({required String label, required String? id}) {
    final selected = _gradeId == id;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _gradeId = id),
      showCheckmark: false,
    );
  }

  Widget _sectionLabel(String text) {
    final cs = Theme.of(context).colorScheme;
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: cs.onSurfaceVariant,
        letterSpacing: 0.6,
      ),
    );
  }

  Widget _topicsCard(List<TopicProgress> topics) {
    final cs = Theme.of(context).colorScheme;
    final color = trackVisual(widget.track.id, cs).color;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        children: [
          for (var i = 0; i < topics.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                thickness: 1,
                indent: 64,
                color: cs.outlineVariant,
              ),
            _TopicRow(
              topic: topics[i],
              accent: color,
              onTap: () => topics[i].allMastered
                  ? _confirmResetTopic(topics[i].title)
                  : _openTopic(topics[i].title),
            ),
          ],
        ],
      ),
    );
  }

  Widget _emptyHint() {
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
              'В этом грейде пока нет тем с вопросами.',
              style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopicRow extends StatelessWidget {
  const _TopicRow({
    required this.topic,
    required this.accent,
    required this.onTap,
  });

  final TopicProgress topic;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final done = topic.allMastered;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 14, 16, 14),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(topicIcon(topic.title), size: 20, color: accent),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    topic.title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 7),
                  if (done)
                    Text(
                      'Все пройдены',
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurfaceVariant,
                      ),
                    )
                  else
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: topic.fraction,
                        minHeight: 4,
                        backgroundColor: cs.surfaceContainerHighest,
                        color: accent,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            if (done)
              Icon(Icons.refresh, size: 18, color: cs.onSurfaceVariant)
            else
              Text(
                '${topic.mastered}/${topic.total}',
                style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
              ),
          ],
        ),
      ),
    );
  }
}
