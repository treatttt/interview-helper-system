import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/progress_service.dart';
import '../controllers/session_controller.dart'
    show AnswerOutcome, AnsweredQuestion;
import 'session_screen.dart';

/// Экран грейдов — показывает список Junior/Middle/Senior для выбранного направления.
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

  Future<void> _openSession(Grade grade) async {
    if (_opening) return;
    _opening = true;

    final trackId = widget.track.id;
    final gradeId = grade.id;
    final gradeKey = '${trackId}_$gradeId';

    final mastered = widget.progress.masteredIds(trackId, gradeId);
    final remaining =
        grade.questions.where((q) => !mastered.contains(q.id)).toList();

    if (remaining.isEmpty) {
      _opening = false;
      return;
    }

    List<Question> sessionQuestions;
    int startIndex = 0;
    List<AnsweredQuestion> previousAnswers = const [];

    final incomplete = widget.progress.loadIncompleteSession(gradeKey);
    if (incomplete != null) {
      if (!mounted) {
        _opening = false;
        return;
      }
      final choice = await _showResumeDialog(incomplete);
      if (!mounted) {
        _opening = false;
        return;
      }

      if (choice == 'continue') {
        final questionIds =
            (incomplete['questionIds'] as List).cast<String>();
        final questionMap = {for (final q in grade.questions) q.id: q};
        sessionQuestions = questionIds
            .map((id) => questionMap[id])
            .whereType<Question>()
            .toList();
        startIndex = incomplete['currentIndex'] as int;
        final rawAnswers =
            (incomplete['answeredData'] as List).cast<Map<String, dynamic>>();
        previousAnswers = rawAnswers.map((data) {
          final q = questionMap[data['id'] as String]!;
          final selected =
              (data['selected'] as List).cast<int>().toSet();
          final outcome =
              AnswerOutcome.values.byName(data['outcome'] as String);
          return AnsweredQuestion(
              question: q, selected: selected, outcome: outcome);
        }).toList();
      } else {
        await widget.progress.clearIncompleteSession(gradeKey: gradeKey);
        sessionQuestions = remaining;
      }
    } else {
      sessionQuestions = remaining;
    }

    if (!mounted) {
      _opening = false;
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SessionScreen(
          track: widget.track,
          grade: grade,
          questions: sessionQuestions,
          progress: widget.progress,
          initialIndex: startIndex,
          previousAnswers: previousAnswers,
        ),
      ),
    );
    _opening = false;
  }

  Future<String?> _showResumeDialog(Map<String, dynamic> incomplete) {
    final answeredCount =
        (incomplete['answeredData'] as List).length;
    final sessionTotal =
        (incomplete['questionIds'] as List).length;

    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Незавершённая сессия'),
        content: Text(
            'Вы остановились на вопросе ${answeredCount + 1} из $sessionTotal.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop('restart'),
            child: const Text('Начать заново'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop('continue'),
            child: const Text('Продолжить'),
          ),
        ],
      ),
    );
  }

  Future<void> _resetGrade(Grade grade) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Сбросить прогресс?'),
        content: Text(
            'Все вопросы «${grade.title}» снова станут доступны в полном объёме.'),
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
      await widget.progress.resetGrade(widget.track.id, grade.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final grades = [...widget.track.grades]
      ..sort((a, b) => a.order.compareTo(b.order));

    return Scaffold(
      appBar: AppBar(title: Text(widget.track.title)),
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
    final mastered = widget.progress.masteredIds(widget.track.id, grade.id);
    final done = mastered.length;
    final allDone = hasQuestions && done >= total;
    final pct = total == 0 ? 0.0 : done / total;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: hasQuestions
            ? (allDone ? () => _resetGrade(grade) : () => _openSession(grade))
            : null,
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
                                  fontSize: 12, color: cs.onSurfaceVariant),
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
                    else if (allDone) ...[
                      Text(
                        'Все пройдены',
                        style: TextStyle(
                            color: cs.onSurfaceVariant, fontSize: 12),
                      ),
                      const SizedBox(width: 4),
                      Tooltip(
                        message: 'Пройти заново',
                        child: Icon(Icons.refresh,
                            size: 18, color: cs.onSurfaceVariant),
                      ),
                    ] else ...[
                      Text(
                        '$done/$total',
                        style: TextStyle(
                            color: cs.onSurfaceVariant, fontSize: 12),
                      ),
                      const SizedBox(width: 4),
                      Tooltip(
                        message: 'Сбросить прогресс',
                        child: GestureDetector(
                          onTap: () => _resetGrade(grade),
                          child: Icon(Icons.refresh,
                              size: 18, color: cs.onSurfaceVariant),
                        ),
                      ),
                      const SizedBox(width: 4),
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
