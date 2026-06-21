import 'package:flutter/material.dart';
import 'package:interview_helper_system/screens/topic_session.dart';
import 'package:interview_helper_system/screens/tracks_loader.dart';
import 'package:interview_helper_system/services/progress_service.dart';
import 'package:interview_helper_system/services/question_repository.dart';
import 'package:interview_helper_system/utils/tap_lock.dart';

/// Каталог тем — список тем (БД, SQL, Интеграции…) с прогрессом по каждой.
/// Тап по теме запускает сессию из непройденных вопросов этой темы; иконка
/// обновления сбрасывает прогресс темы. Полностью пройденная тема тапом ведёт
/// в сброс — отдельный сброс по теме, не привязанный к грейду.
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

class _TopicsScreenState extends State<TopicsScreen>
    with TracksLoader<TopicsScreen>, TapLock<TopicsScreen> {
  @override
  QuestionRepository get repository => widget.repository;

  @override
  String get loadErrorMessage => 'Не удалось загрузить темы';

  // guardTap: двойной/быстрый тап по карточке темы не открывает второй экран.
  void _openTopic(String title) => guardTap(
        () => startTopicSession(
          context,
          tracks: tracks,
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
      await resetTopic(tracks, widget.progress, title);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Темы', style: TextStyle(fontWeight: FontWeight.w500)),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
          ? ErrorRetryView(title: loadErrorMessage, onRetry: retryLoad)
          : ListenableBuilder(
        listenable: widget.progress,
        builder: (context, _) {
          final topics = buildTopicCatalog(tracks, widget.progress);
          if (topics.isEmpty) return _emptyView();
          return ListView.separated(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            itemCount: topics.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final topic = topics[i];
              return _TopicCard(
                topic: topic,
                onTap: topic.allMastered
                    ? () => _confirmResetTopic(topic.title)
                    : () => _openTopic(topic.title),
                onReset: () => _confirmResetTopic(topic.title),
              );
            },
          );
        },
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
              'Тем пока нет',
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
}

class _TopicCard extends StatelessWidget {
  const _TopicCard({
    required this.topic,
    required this.onTap,
    required this.onReset,
  });

  final TopicProgress topic;
  final VoidCallback onTap;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final done = topic.allMastered;

    return InkWell(
      onTap: onTap,
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
                    topic.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (done) ...[
                  Text(
                    'Все пройдены',
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(width: 4),
                  Tooltip(
                    message: 'Пройти заново',
                    child: Icon(
                      Icons.refresh,
                      size: 18,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ] else ...[
                  Text(
                    '${topic.mastered}/${topic.total}',
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(width: 4),
                  Tooltip(
                    message: 'Сбросить тему',
                    child: GestureDetector(
                      onTap: onReset,
                      child: Icon(
                        Icons.refresh,
                        size: 18,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.chevron_right,
                    size: 20,
                    color: cs.onSurfaceVariant,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: topic.fraction,
                minHeight: 5,
                backgroundColor: cs.surfaceContainerHighest,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
