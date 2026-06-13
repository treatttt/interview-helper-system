import 'package:flutter/material.dart';
import 'theme.dart';
import 'services/progress_service.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final progress = ProgressService();
  await progress.init();
  runApp(InterviewHelperApp(progress: progress));
}

class InterviewHelperApp extends StatelessWidget {
  final ProgressService progress;
  const InterviewHelperApp({super.key, required this.progress});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Тренажёр собеседований',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: HomeScreen(progress: progress),
    );
  }
}
