import 'package:flutter/material.dart';
import 'package:interview_helper_system/models/models.dart';
import 'package:interview_helper_system/screens/grades_screen.dart';
import 'package:interview_helper_system/screens/session_screen.dart';
import 'package:interview_helper_system/services/progress_service.dart';
import 'package:interview_helper_system/services/question_repository.dart';

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
  List<TopicGroup> _topicGroups = [];
  bool _loading = true;
  String? _error;
  bool _opening = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final tracks = await widget.repository.loadTracks();
      if (!mounted) return;
      final sorted = tracks.toList()..sort((a, b) => a.order.compareTo(b.order));
      setState(() {
        _tracks = sorted;
        _topicGroups = aggregateTopics(sorted);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Не удалось загрузить вопросы';
        _loading = false;
      });
    }
  }

  // ── Навигация ────────────────────────────────────────────────────────────

  Future<void> _openTopicSession(String topicTitle) async {
    if (_opening) return;
    final group = _topicGroups.firstWhere(
      (g) => g.title == topicTitle,
      orElse: () => TopicGroup(title: topicTitle, questions: const []),
    );

    final remaining = group.questions.where((o) {
      final mastered = widget.progress.masteredIds(o.track.id, o.grade.id);
      return !mastered.contains(o.question.id);
    }).toList();

    if (remaining.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Тема полностью пройдена!')),
        );
      }
      return;
    }

    _opening = true;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SessionScreen(
          origins: remaining,
          topicTitle: topicTitle,
          progress: widget.progress,
          questions: remaining.map((o) => o.question).toList(),
        ),
      ),
    );
    _opening = false;
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Тренажёр',
          style: TextStyle(fontWeight: FontWeight.w500),
        ),
        actions: [
          ListenableBuilder(
            listenable: widget.progress,
            builder: (context, _) {
              if (!widget.progress.hasTrainedEver) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Row(
                  children: [
                    const Icon(Icons.local_fire_department,
                      color: Color(0xFFF5871F),
                      size: 20,
                    ),
                    const SizedBox(width: 4),
                    Text('${widget.progress.streak}',
                        style: const TextStyle(
                            color: Color(0xFFF5871F),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _errorView()
              : _tracks.isEmpty
                  ? _emptyView()
                  : ListenableBuilder(
                      listenable: widget.progress,
                      builder: (context, _) => ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          _metricsRow(),
                          const SizedBox(height: 20),
                          _bodySection(),
                          if (_tracks.isNotEmpty) ...[
                            const SizedBox(height: 24),
                            _sectionLabel('Направления'),
                            const SizedBox(height: 8),
                            ..._tracks.map(_trackCard),
                          ],
                        ],
                      ),
                    ),
    );
  }

  // ── Метрики ──────────────────────────────────────────────────────────────

  Widget _metricsRow() {
    final p = widget.progress;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _MetricCard(
              value: p.hasTrainedEver ? '${p.streak}' : '0',
              label: 'Серия',
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _MetricCard(
              value: '${p.xp}',
              label: 'XP',
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _MetricCard(
              value: '${p.totalMastered}',
              label: 'Освоено',
            ),
          ),
        ],
      ),
    );
  }

  // ── Основной контент (слабые темы или CTA) ───────────────────────────────

  Widget _bodySection() {
    if (_topicGroups.isEmpty) return const SizedBox.shrink();

    final weakTopics = _weakTopicsSorted();

    if (weakTopics.isEmpty) {
      return _ctaSection();
    }
    return _weakTopicsSection(weakTopics.take(3).toList());
  }

  List<TopicGroup> _weakTopicsSorted() {
    return _topicGroups.where((g) {
      final done = _masteredInTopic(g);
      return done > 0 && done < g.questions.length;
    }).toList()
      ..sort((a, b) {
        final ra = _masteredInTopic(a) / a.questions.length;
        final rb = _masteredInTopic(b) / b.questions.length;
        return ra.compareTo(rb);
      });
  }

  int _masteredInTopic(TopicGroup group) {
    return group.questions.where((o) {
      return widget.progress
          .masteredIds(o.track.id, o.grade.id)
          .contains(o.question.id);
    }).length;
  }

  Widget _ctaSection() {
    final cs = Theme.of(context).colorScheme;
    final first = _topicGroups.first;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Начни подготовку',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),),
          const SizedBox(height: 4),
          Text(
            '${_topicGroups.length} ${_topicCountLabel(_topicGroups.length)} доступно',
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => _openTopicSession(first.title),
              child: const Text('Начать'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _weakTopicsSection(List<TopicGroup> topics) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Слабые темы',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: cs.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        ...topics.map(_weakTopicCard),
      ],
    );
  }

  Widget _weakTopicCard(TopicGroup group) {
    final cs = Theme.of(context).colorScheme;
    final done = _masteredInTopic(group);
    final total = group.questions.length;
    final pct = total == 0 ? 0.0 : done / total;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () => _openTopicSession(group.title),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: cs.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      group.title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    '$done/$total',
                    style: TextStyle(
                      fontSize: 12,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.chevron_right, size: 18, color: cs.onSurfaceVariant),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: pct,
                  minHeight: 5,
                  backgroundColor: cs.surfaceContainerHighest,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Направления ──────────────────────────────────────────────────────────

  Widget _sectionLabel(String text) {
    final cs = Theme.of(context).colorScheme;
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: cs.onSurfaceVariant,
      ),
    );
  }

  Widget _trackCard(Track track) {
    final cs = Theme.of(context).colorScheme;
    final totalQuestions =
        track.grades.fold<int>(0, (sum, g) => sum + g.questions.length);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => GradesScreen(
              track: track,
              progress: widget.progress,
            ),
          ),
        ),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: cs.outlineVariant),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      track.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (track.description != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        track.description!,
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      totalQuestions == 0
                          ? 'Нет вопросов'
                          : '$totalQuestions вопр.',
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, size: 20, color: cs.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }

  // ── Empty / Error ─────────────────────────────────────────────────────────

  Widget _emptyView() {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_outlined, size: 48, color: cs.onSurfaceVariant),
            const SizedBox(height: 16),
            const Text('Вопросов пока нет',
                textAlign: TextAlign.center,
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 6),
            Text('Темы появятся, когда будут добавлены вопросы.',
                textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  Widget _errorView() {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_outlined,
              size: 48,
              color: cs.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            const Text('Не удалось загрузить вопросы',
                textAlign: TextAlign.center,
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 6),
            Text('Что-то пошло не так. Попробуй ещё раз.',
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
                _load();
              },
              child: const Text('Попробовать снова'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Вспомогательные функции ──────────────────────────────────────────────────

String _topicCountLabel(int n) {
  if (n % 10 == 1 && n % 100 != 11) return 'тема';
  if (n % 10 >= 2 && n % 10 <= 4 && (n % 100 < 10 || n % 100 >= 20)) {
    return 'темы';
  }
  return 'тем';
}

// ── Виджеты ──────────────────────────────────────────────────────────────────

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
