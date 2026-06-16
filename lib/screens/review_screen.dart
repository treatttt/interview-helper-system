import 'package:flutter/material.dart';
import '../controllers/session_controller.dart';
import '../models/models.dart'; // ради типа Topic
import 'session_screen.dart'; // ради рестарта «Пройти заново»
import '../services/progress_service.dart';

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
    final q = answer.question;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _outcomeBadge(answer.outcome),
          const SizedBox(height: 8),
          Text(q.text,
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          // Поэлементный разбор: каждый вариант со своим состоянием.
          ...List.generate(
            q.options.length,
            (i) => _optionRow(
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
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(q.explanation!,
                  style: TextStyle(fontSize: 13, color: Colors.blue.shade900)),
            ),
          ],
        ],
      ),
    );
  }

  /// Один вариант ответа с пометкой состояния по четырём категориям.
  /// Каждое состояние несёт ИКОНКУ + ТЕКСТ, не только цвет (доступность).
  Widget _optionRow({
    required String text,
    required bool correct,
    required bool picked,
  }) {
    late final Color bg;
    late final Color border;
    late final Color fg;
    late final IconData icon;
    late final String? tag; // короткая подпись состояния

    if (correct && picked) {
      bg = Colors.green.shade50;
      border = Colors.green;
      fg = Colors.green.shade800;
      icon = Icons.check_circle;
      tag = 'верно';
    } else if (correct && !picked) {
      // Пропущенный правильный — главный обучающий момент.
      bg = Colors.amber.shade50;
      border = Colors.amber.shade700;
      fg = Colors.amber.shade900;
      icon = Icons.error_outline;
      tag = 'пропущено';
    } else if (!correct && picked) {
      bg = Colors.red.shade50;
      border = Colors.red;
      fg = Colors.red.shade800;
      icon = Icons.cancel;
      tag = 'лишнее';
    } else {
      // Неверный и не выбран — нейтрально, без пометки.
      bg = Colors.transparent;
      border = Colors.grey.shade300;
      fg = Colors.black87;
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
                      color: fg, fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _outcomeBadge(AnswerOutcome outcome) {
    late final Color color;
    late final String label;
    late final IconData icon;
    switch (outcome) {
      case AnswerOutcome.correct:
        color = Colors.green;
        label = 'Верно';
        icon = Icons.check_circle;
        break;
      case AnswerOutcome.partial:
        color = Colors.orange;
        label = 'Частично';
        icon = Icons.remove_circle;
        break;
      case AnswerOutcome.wrong:
        color = Colors.red;
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
