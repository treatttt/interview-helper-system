import 'package:flutter/material.dart';
import 'package:interview_helper_system/services/progress_service.dart';
import 'package:interview_helper_system/theme.dart';

/// Карточка слабых тем: список тем с точностью и прогрессом, тап ведёт в дрилл.
/// Используется на экране «Профиль».
class WeakTopicsCard extends StatelessWidget {
  const WeakTopicsCard({
    required this.topics,
    required this.onTopicTap,
    super.key,
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
