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
      appBar: AppBar(title: const Text('Разбор ответов')),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: result.answers.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, i) => _AnswerCard(answer: result.answers[i]),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(
                  builder: (_) => SessionScreen(topic: topic, progress: progress),
                ),
                (r) => r.isFirst,
              ),
              style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14)),
              child: const Text('Пройти заново'),
            ),
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
          _row('Твой ответ:', _optionsText(answer.selected, q.options)),
          const SizedBox(height: 6),
          _row('Правильно:', _optionsText(q.correctIndexes, q.options)),
          if (q.explanation != null) ...[
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

  Widget _row(String label, String value) {
    return RichText(
      text: TextSpan(
        style: const TextStyle(fontSize: 14, color: Colors.black87),
        children: [
          TextSpan(
              text: '$label ',
              style: const TextStyle(fontWeight: FontWeight.w600)),
          TextSpan(text: value),
        ],
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

  String _optionsText(Iterable<int> indices, List<String> options) {
    final list = indices.toList()..sort();
    if (list.isEmpty) return '—';
    return list.map((i) => options[i]).join('; ');
  }
}
