import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/progress_service.dart';
import 'session_screen.dart';

/// Экран грейдов — показывает список Junior/Middle/Senior для выбранного направления.
/// Грейды без вопросов отображаются как неактивные с меткой «Скоро».
class GradesScreen extends StatefulWidget {
  final Track track;
  final ProgressService progress;

  const GradesScreen({
    super.key,
    required this.track,
    required this.progress,
  });

  @override
  State<GradesScreen> createState() => _GradesScreenState();
}

class _GradesScreenState extends State<GradesScreen> {
  bool _opening = false;

  void _openSession(Grade grade) async {
    if (_opening) return;
    _opening = true;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SessionScreen(
          track: widget.track,
          grade: grade,
          progress: widget.progress,
        ),
      ),
    );
    _opening = false;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final grades = [...widget.track.grades]
      ..sort((a, b) => a.order.compareTo(b.order));

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.track.title),
      ),
      body: ListenableBuilder(
        listenable: widget.progress,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (widget.track.description != null) ...[
              Text(
                widget.track.description!,
                style: TextStyle(
                    fontSize: 14, color: cs.onSurfaceVariant, height: 1.4),
              ),
              const SizedBox(height: 20),
            ],
            ...grades.map((g) => _gradeCard(g)),
          ],
        ),
      ),
    );
  }

  Widget _gradeCard(Grade grade) {
    final cs = Theme.of(context).colorScheme;
    final hasQuestions = grade.questions.isNotEmpty;
    final total = grade.questions.length;
    final done = widget.progress.gradeDone(widget.track.id, grade.id);
    final pct = total == 0 ? 0.0 : done / total;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: hasQuestions ? () => _openSession(grade) : null,
        borderRadius: BorderRadius.circular(12),
        child: Opacity(
          opacity: hasQuestions ? 1.0 : 0.5,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: hasQuestions
                    ? cs.outlineVariant
                    : cs.outlineVariant.withValues(alpha: 0.5),
              ),
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
                            grade.title,
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                          if (grade.description != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              grade.description!,
                              style: TextStyle(
                                  fontSize: 12,
                                  color: cs.onSurfaceVariant),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (!hasQuestions)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Скоро',
                          style: TextStyle(
                              fontSize: 11, color: cs.onSurfaceVariant),
                        ),
                      )
                    else ...[
                      Text(
                        '$done/$total',
                        style: TextStyle(
                            color: cs.onSurfaceVariant, fontSize: 12),
                      ),
                      const SizedBox(width: 6),
                      Icon(Icons.chevron_right,
                          size: 20, color: cs.onSurfaceVariant),
                    ],
                  ],
                ),
                if (hasQuestions) ...[
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: pct,
                      minHeight: 6,
                      backgroundColor: cs.surfaceContainerHighest,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
