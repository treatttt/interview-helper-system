import 'package:flutter/material.dart';
import '../controllers/session_controller.dart';
import '../models/models.dart'; // ради типа Topic
import 'session_screen.dart'; // ради рестарта «Пройти заново»
import '../services/progress_service.dart';
import '../theme.dart';

/// Разбор сессии: все вопросы с пометкой верно / частично / неверно,
/// что выбрал пользователь, правильный ответ и пояснение (если есть).
class ReviewScreen extends StatelessWidget {
  final SessionResult result;
  final Topic topic;
  final ProgressService progress; // НОВОЕ
  const ReviewScreen({
    super.key,
    required this.result,
    required this.topic,
    required this.progress, // НОВОЕ
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Разбор ответов'),
        automaticallyImplyLeading:
            false, // убираем стрелку, ведущую в старую сессию
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
                  onPressed: () => Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(
                      builder: (_) =>
                          SessionScreen(topic: topic, progress: progress),
                    ),
                    (r) => r.isFirst,
                  ),
                  style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14)),
                  child: const Text('Пройти заново'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () =>
                      Navigator.of(context).popUntil((r) => r.isFirst),
                  style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14)),
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
  final AnsweredQuestion answer;

  const _AnswerCard({required this.answer});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final s = AppSemanticColors.of(context);
    final q = answer.question;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface, // ← здесь cs
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant), // ← и здесь cs
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _outcomeBadge(context, answer.outcome),
          const SizedBox(height: 8),
          Text(q.text,
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          // Поэлементный разбор: каждый вариант со своим состоянием.
          ...List.generate(
            q.options.length,
            (i) => _optionRow(
              context: context,
              text: q.options[i],
              correct: q.correctIndexes.contains(i),
              picked: answer.selected.contains(i),
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
                  style: TextStyle(fontSize: 13, color: s.infoFg)),
            ),
          ],
        ],
      ),
    );
  }

  /// Один вариант ответа с пометкой состояния по четырём категориям.
  /// Каждое состояние несёт ИКОНКУ + ТЕКСТ, не только цвет (доступность).
  Widget _optionRow({
    required BuildContext context,
    required String text,
    required bool correct,
    required bool picked,
  }) {
    final cs = Theme.of(context).colorScheme;
    final s = AppSemanticColors.of(context);

    late final Color bg, border, fg;
    late final IconData icon;
    late final String? tag;

    if (correct && picked) {
      bg = s.successBg;
      border = s.successBorder;
      fg = s.successFg;
      icon = Icons.check_circle;
      tag = 'верно';
    } else if (correct && !picked) {
      bg = s.warningBg;
      border = s.warningBorder;
      fg = s.warningFg;
      icon = Icons.error_outline;
      tag = 'пропущено';
    } else if (!correct && picked) {
      bg = s.dangerBg;
      border = s.dangerBorder;
      fg = s.dangerFg;
      icon = Icons.cancel;
      tag = 'лишнее';
    } else {
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
                child: Text(text, style: TextStyle(color: fg, fontSize: 14))),
            if (tag != null) ...[
              const SizedBox(width: 8),
              Text(tag,
                  style: TextStyle(
                      color: fg, fontSize: 12, fontWeight: FontWeight.w600)),
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
        break;
      case AnswerOutcome.partial:
        color = s.warningFg;
        label = 'Частично';
        icon = Icons.remove_circle;
        break;
      case AnswerOutcome.wrong:
        color = s.dangerFg;
        label = 'Неверно';
        icon = Icons.cancel;
        break;
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 6),
        Text(label,
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600, color: color)),
      ],
    );
  }
}
