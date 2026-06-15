import 'package:flutter/material.dart';
import '../controllers/session_controller.dart';

class ResultScreen extends StatelessWidget {
  final SessionResult result;

  const ResultScreen({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    final pct = result.maxPoints == 0
        ? 0
        : (result.points / result.maxPoints * 100).round();

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
                color: Colors.green.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.check_circle_outline,
                  color: Colors.green.shade600, size: 52),
            ),
            const SizedBox(height: 20),
            Text('${result.points} из ${result.maxPoints} баллов',
                style:
                    const TextStyle(fontSize: 24, fontWeight: FontWeight.w500)),
            const SizedBox(height: 4),
            Text('$pct%',
                style: const TextStyle(color: Colors.grey, fontSize: 14)),
            const SizedBox(height: 24),
            // Разбивка по категориям — как договорились в команде.
            _statRow('Верно', result.correct, Colors.green.shade600),
            _statRow('Частично', result.partial, Colors.amber.shade700),
            _statRow('Неверно', result.wrong, Colors.red.shade600),
            const Spacer(),
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
