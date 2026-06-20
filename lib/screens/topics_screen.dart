import 'dart:async';

import 'package:flutter/material.dart';
import 'package:interview_helper_system/models/models.dart';
import 'package:interview_helper_system/screens/grades_screen.dart';
import 'package:interview_helper_system/services/progress_service.dart';
import 'package:interview_helper_system/services/question_repository.dart';

/// Каталог всех направлений — полный список треков с прогрессом по грейдам.
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
        _error = 'Не удалось загрузить направления';
        _loading = false;
      });
    }
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
              : _tracks.isEmpty
                  ? _emptyView()
                  : ListenableBuilder(
                      listenable: widget.progress,
                      builder: (context, _) => ListView.separated(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        itemCount: _tracks.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, i) => _TrackCard(
                          track: _tracks[i],
                          progress: widget.progress,
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
              'Направления появятся, когда будут добавлены вопросы.',
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
            Icon(Icons.cloud_off_outlined, size: 48, color: cs.onSurfaceVariant),
            const SizedBox(height: 16),
            const Text(
              'Не удалось загрузить направления',
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

class _TrackCard extends StatelessWidget {
  const _TrackCard({required this.track, required this.progress});
  final Track track;
  final ProgressService progress;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final totalQuestions =
        track.grades.fold<int>(0, (s, g) => s + g.questions.length);
    final mastered = track.grades.fold<int>(
      0,
      (s, g) => s + progress.masteredIds(track.id, g.id).length,
    );
    final progressPct =
        totalQuestions == 0 ? 0.0 : mastered / totalQuestions;

    return InkWell(
      onTap: () => unawaited(
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => GradesScreen(track: track, progress: progress),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
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
                    ],
                  ),
                ),
                Text(
                  '$mastered/$totalQuestions',
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                ),
                const SizedBox(width: 4),
                Icon(Icons.chevron_right, size: 20, color: cs.onSurfaceVariant),
              ],
            ),
            if (totalQuestions > 0) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: progressPct,
                  minHeight: 5,
                  backgroundColor: cs.surfaceContainerHighest,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
