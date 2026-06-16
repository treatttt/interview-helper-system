import 'package:flutter/material.dart';
import 'services/question_repository.dart';
import 'services/progress_service.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart'; // путь под то, куда положил файл

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final progress = ProgressService();
  await progress.init();
  runApp(InterviewHelperApp(progress: progress));
}

class InterviewHelperApp extends StatelessWidget {
  final ProgressService progress;
  final navigatorKey = GlobalKey<NavigatorState>();

  InterviewHelperApp({super.key, required this.progress});

  @override
  Widget build(BuildContext context) {
    final QuestionRepository repository = JsonQuestionRepository();

    return MaterialApp(
      title: 'Тренажёр собеседований',
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true),
      home: progress.onboardingDone
          ? HomeScreen(repository: repository, progress: progress)
          : OnboardingScreen(
              onFinish: () {
                progress.markOnboardingDone();
                navigatorKey.currentState?.pushReplacement(
                  MaterialPageRoute(
                    builder: (_) =>
                        HomeScreen(repository: repository, progress: progress),
                  ),
                );
              },
            ),
    );
  }
}
