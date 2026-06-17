import 'package:flutter/material.dart';
import 'services/question_repository.dart';
import 'services/progress_service.dart';
import 'services/theme_service.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final progress = ProgressService();
  await progress.init();
  final themeService = ThemeService();
  await themeService.init();
  runApp(InterviewHelperApp(progress: progress, themeService: themeService));
}

class InterviewHelperApp extends StatelessWidget {
  final ProgressService progress;
  final ThemeService themeService;
  final navigatorKey = GlobalKey<NavigatorState>();

  InterviewHelperApp({
    super.key,
    required this.progress,
    required this.themeService,
  });

  @override
  Widget build(BuildContext context) {
    final QuestionRepository repository = JsonQuestionRepository();

    // MaterialApp слушает themeService и пересобирается при смене режима.
    return ListenableBuilder(
      listenable: themeService,
      builder: (context, _) => MaterialApp(
        title: 'Тренажёр собеседований',
        navigatorKey: navigatorKey,
        debugShowCheckedModeBanner: false,
        theme: buildLightTheme(),
        darkTheme: buildDarkTheme(),
        themeMode: themeService.mode,
        home: progress.onboardingDone
            ? HomeScreen(
                repository: repository,
                progress: progress,
                themeService: themeService)
            : OnboardingScreen(
                onFinish: () {
                  progress.markOnboardingDone();
                  navigatorKey.currentState?.pushReplacement(
                    MaterialPageRoute(
                        builder: (_) => HomeScreen(
                            repository: repository,
                            progress: progress,
                            themeService: themeService)),
                  );
                },
              ),
      ),
    );
  }
}
