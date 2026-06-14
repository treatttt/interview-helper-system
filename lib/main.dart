import 'package:flutter/material.dart';
import 'services/question_repository.dart';
import 'services/progress_service.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final progress = ProgressService();
  await progress.init(); // загрузить сохранённый прогресс до запуска UI
  runApp(InterviewHelperApp(progress: progress));
}

class InterviewHelperApp extends StatelessWidget {
  final ProgressService progress;
  const InterviewHelperApp({super.key, required this.progress});

  @override
  Widget build(BuildContext context) {
    final QuestionRepository repository = JsonQuestionRepository();

    return MaterialApp(
      title: 'Тренажёр собеседований',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true),
      home: HomeScreen(repository: repository, progress: progress),
    );
  }
}