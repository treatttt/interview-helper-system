import 'package:flutter/material.dart';
import 'package:interview_helper_system/models/models.dart';
import 'package:interview_helper_system/screens/session_screen.dart';
import 'package:interview_helper_system/services/progress_service.dart';
import 'package:interview_helper_system/services/question_repository.dart';

/// Каталог тем — список тем, агрегированных из всех направлений и грейдов.
/// Тап по теме запускает сессию из вопросов этой темы (без уже освоенных).
class TopicsScreen extends StatefulWidget {
  const TopicsScreen({
    required this.repository,
    required this.progress,
    super.key,
  });

  final QuestionRepository repository;
  final ProgressService progress;

  @override
  State<TopicsScreen> createState() => _TopicsScreenState();
}

class _TopicsScreenState extends State<TopicsScreen> {
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
      setState(() {
        _topicGroups = aggregateTopics(tracks);
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

  Future<void> _openTopicSession(TopicGroup group) async {
    if (_opening) return;

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
          topicTitle: group.title,
          progress: widget.progress,
          questions: remaining.map((o) => o.question).toList(),
        ),
      ),
    );
    _opening = false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Темы', style: TextStyle(fontWeight: FontWeight.w500)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _errorView()
              : _topicGroups.isEmpty
                  ? _emptyView()
                  : ListenableBuilder(
                      listenable: widget.progress,
                      builder: (context, _) => ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _topicGroups.length,
                        itemBuilder: (context, index) =>
                            _topicCard(_topicGroups[index]),
                      ),
                    ),
    );
  }

  Widget _topicCard(TopicGroup group) {
    final cs = Theme.of(context).colorScheme;
    final total = group.questions.length;
    final done = group.questions.where((o) {
      return widget.progress
          .masteredIds(o.track.id, o.grade.id)
          .contains(o.question.id);
    }).length;
    final allDone = done >= total;
    final pct = total == 0 ? 0.0 : done / total;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () => _openTopicSession(group),
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
                  if (allDone) ...[
                    Text('Всё пройдено',
                        style: TextStyle(
                            fontSize: 12, color: cs.onSurfaceVariant),),
                    const SizedBox(width: 4),
                    Icon(Icons.check_circle_outline,
                        size: 16, color: cs.onSurfaceVariant),
                  ] else ...[
                    Text(
                      '$done/$total',
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.chevron_right,
                        size: 18, color: cs.onSurfaceVariant),
                  ],
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
            const Text(
              'Вопросов пока нет',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 6),
            Text(
              'Темы появятся, когда будут добавлены вопросы.',
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
                size: 48, color: cs.onSurfaceVariant,),
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
