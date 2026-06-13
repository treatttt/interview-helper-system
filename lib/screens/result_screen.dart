import 'package:flutter/material.dart';
import '../theme.dart';

class ResultScreen extends StatelessWidget {
  final int score;
  final int total;
  const ResultScreen({super.key, required this.score, required this.total});

  @override
  Widget build(BuildContext context) {
    final pct = total == 0 ? 0 : (score / total * 100).round();
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
              decoration: const BoxDecoration(
                color: AppColors.successBg,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_outline,
                  color: AppColors.success, size: 52),
            ),
            const SizedBox(height: 20),
            Text('$score из $total',
                style: const TextStyle(
                    fontSize: 24, fontWeight: FontWeight.w500)),
            const SizedBox(height: 4),
            Text('правильных ответов · $pct%',
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 14)),
            const SizedBox(height: 16),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.infoBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.bolt, color: AppColors.info, size: 18),
                  const SizedBox(width: 6),
                  Text('+${score * 10} XP',
                      style: const TextStyle(
                          color: AppColors.info, fontSize: 14)),
                ],
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () =>
                    Navigator.of(context).popUntil((r) => r.isFirst),
                style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14)),
                child: const Text('На главный экран'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
