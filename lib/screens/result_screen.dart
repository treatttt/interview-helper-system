import 'package:flutter/material.dart';
import '../controllers/session_controller.dart';
import '../models/models.dart';
import 'review_screen.dart';
import '../services/progress_service.dart';
import '../theme.dart';

class ResultScreen extends StatelessWidget {
  final SessionResult result;
  final Track track;
  final Grade grade;
  final ProgressService progress;

  const ResultScreen({
    super.key,
    required this.result,
    required this.track,
    required this.grade,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final pct = result.maxPoints == 0
        ? 0
        : (result.points / result.maxPoints * 100).round();
    final s = AppSemanticColors.of(context);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Результат')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 24),
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: s.successBg,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.check_circle_outline,
                  color: s.successFg, size: 52),
            ),
            const SizedBox(height: 20),
            Text('${result.points} из ${result.maxPoints} баллов',
                style:
                    const TextStyle(fontSize: 24, fontWeight: FontWeight.w500)),
            const SizedBox(height: 4),
            Text('$pct%',
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14)),
            const SizedBox(height: 24),
            _statRow('Верно', result.correct, s.successFg),
            _statRow('Частично', result.partial, s.warningFg),
            _statRow('Неверно', result.wrong, s.dangerFg),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ReviewScreen(
                      result: result,
                      track: track,
                      grade: grade,
                      progress: progress,
                    ),
                  ),
                ),
                style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14)),
                child: const Text('Разбор ответов'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () =>
                    Navigator.of(context).popUntil((r) => r.isFirst),
                style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14)),
                child: const Text('На главный экран'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statRow(String label, int value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Text(label, style: const TextStyle(fontSize: 15)),
          const Spacer(),
          Text('$value',
              style:
                  const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
