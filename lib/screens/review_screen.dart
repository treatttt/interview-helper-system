import 'package:flutter/material.dart';
import 'package:interview_helper_system/controllers/session_controller.dart';
import 'package:interview_helper_system/models/models.dart';
import 'package:interview_helper_system/screens/session_screen.dart';
import 'package:interview_helper_system/services/progress_service.dart';
import 'package:interview_helper_system/theme.dart';
import 'package:interview_helper_system/utils/option_highlight.dart';

class ReviewScreen extends StatelessWidget {
  const ReviewScreen({
    required this.result,
    required this.track,
    required this.grade,
    required this.progress,
    super.key,
  });
  final SessionResult result;
  final Track track;
  final Grade grade;
  final ProgressService progress;

  @override
  Widget build(BuildContext context) {
    final errorQuestions = result.answers
        .where((a) => a.outcome != AnswerOutcome.correct)
        .map((a) => a.question)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Разбор ответов'),
        automaticallyImplyLeading: false,
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: result.answers.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, i) => _AnswerCard(answer: result.answers[i]),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: errorQuestions.isEmpty
                      ? null
                      : () {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute<void>(
                        settings: const RouteSettings(name: 'Вопросы'),
                        builder: (_) => SessionScreen(
                          track: track,
                          grade: grade,
                          questions: errorQuestions,
                          progress: progress,
                        ),
                      ),
                          (r) => r.isFirst,
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text(
                    errorQuestions.isEmpty
                        ? 'Ошибок нет'
                        : 'Проработать ошибки',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () =>
                      Navigator.of(context).popUntil((r) => r.isFirst),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('В меню'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnswerCard extends StatelessWidget {

  const _AnswerCard({required this.answer});

  final AnsweredQuestion answer;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final s = AppSemanticColors.of(context);
    final q = answer.question;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _outcomeBadge(context, answer.outcome),
          const SizedBox(height: 8),
          Text(q.text,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          ...List.generate(
            q.options.length,
                (i) => _optionRow(
              context: context,
              text: q.options[i],
              highlight: resolveOptionHighlight(
                isCorrect: q.correctIndexes.contains(i),
                isPicked: answer.selected.contains(i),
                isMultiChoice: q.isMultipleChoice,
              ),
            ),
          ),
          if (q.explanation != null && q.explanation!.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: s.infoBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(q.explanation!,
                style: TextStyle(fontSize: 13, color: s.infoFg),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _optionRow({
    required BuildContext context,
    required String text,
    required OptionHighlight highlight,
  }) {
    final cs = Theme.of(context).colorScheme;
    final s = AppSemanticColors.of(context);

    late final Color bg;
    late final Color border;
    late final Color fg;
    late final IconData icon;
    late final String? tag;

    switch (highlight) {
      case OptionHighlight.correct:
        bg = s.successBg;
        border = s.successBorder;
        fg = s.successFg;
        icon = Icons.check_circle;
        tag = 'верно';
      case OptionHighlight.missed:
        bg = s.warningBg;
        border = s.warningBorder;
        fg = s.warningFg;
        icon = Icons.error_outline;
        tag = 'пропущено';
      case OptionHighlight.wrong:
        bg = s.dangerBg;
        border = s.dangerBorder;
        fg = s.dangerFg;
        icon = Icons.cancel;
        tag = 'лишнее';
      case OptionHighlight.neutral:
        bg = Colors.transparent;
        border = cs.outlineVariant;
        fg = cs.onSurface;
        icon = Icons.circle_outlined;
        tag = null;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: fg),
            const SizedBox(width: 10),
            Expanded(
              child: Text(text, style: TextStyle(color: fg, fontSize: 14)),
            ),
            if (tag != null) ...[
              const SizedBox(width: 8),
              Text(tag,
                style: TextStyle(
                  color: fg,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _outcomeBadge(BuildContext context, AnswerOutcome outcome) {
    final s = AppSemanticColors.of(context);
    late final Color color;
    late final String label;
    late final IconData icon;
    switch (outcome) {
      case AnswerOutcome.correct:
        color = s.successFg;
        label = 'Верно';
        icon = Icons.check_circle;
      case AnswerOutcome.partial:
        color = s.warningFg;
        label = 'Частично';
        icon = Icons.remove_circle;
      case AnswerOutcome.wrong:
        color = s.dangerFg;
        label = 'Неверно';
        icon = Icons.cancel;
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 6),
        Text(label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}
