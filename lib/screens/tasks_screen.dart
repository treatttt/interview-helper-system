import 'package:flutter/material.dart';

/// Вкладка «Задания» — заглушка. Наполняется отдельной задачей.
class TasksScreen extends StatelessWidget {
  const TasksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Задания', style: TextStyle(fontWeight: FontWeight.w500)),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.assignment_outlined, size: 48, color: cs.onSurfaceVariant),
              const SizedBox(height: 16),
              const Text(
                'Скоро здесь появятся задания',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 6),
              Text(
                'Практические задачи и кейсы помогут\nзакрепить теорию на реальных примерах.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant, height: 1.4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
