import 'dart:async';

import 'package:flutter/material.dart';
import 'package:interview_helper_system/dev/feedback_flag.dart';
import 'package:interview_helper_system/dev/feedback_overlay.dart';
import 'package:interview_helper_system/dev/feedback_route_observer.dart';
import 'package:interview_helper_system/screens/main_shell.dart';
import 'package:interview_helper_system/screens/onboarding_screen.dart';
import 'package:interview_helper_system/services/progress_service.dart';
import 'package:interview_helper_system/services/question_repository.dart';
import 'package:interview_helper_system/services/theme_service.dart';
import 'package:interview_helper_system/theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final progress = ProgressService();
  await progress.init();
  final themeService = ThemeService();
  await themeService.init();
  runApp(InterviewHelperApp(progress: progress, themeService: themeService));
}

/// Оборачивает дерево оверлеем обратной связи только в тестовой сборке.
///
/// В прод-сборке флаг — `const false`, поэтому возвращается `child` без
/// изменений, а ссылка на `FeedbackOverlay` вырезается tree-shaking'ом.
Widget _appBuilder(BuildContext _, Widget? child) {
  final content = child ?? const SizedBox.shrink();
  return kFeedbackEnabled ? FeedbackOverlay(child: content) : content;
}

class InterviewHelperApp extends StatelessWidget {
  InterviewHelperApp({
    required this.progress,
    required this.themeService,
    super.key,
  });
  final ProgressService progress;
  final ThemeService themeService;
  final navigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    final QuestionRepository repository = JsonQuestionRepository();

    return ListenableBuilder(
      listenable: themeService,
      builder: (context, _) => MaterialApp(
        title: 'Тренажёр собеседований',
        navigatorKey: navigatorKey,
        debugShowCheckedModeBanner: false,
        theme: buildLightTheme(),
        darkTheme: buildDarkTheme(),
        themeMode: themeService.mode,
        navigatorObservers: [
          if (kFeedbackEnabled) feedbackRouteObserver,
        ],
        builder: _appBuilder,
        home: progress.onboardingDone
            ? MainShell(
          repository: repository,
          progress: progress,
          themeService: themeService,
        )
            : OnboardingScreen(
          onFinish: () {
            unawaited(progress.markOnboardingDone());
            final navigator = navigatorKey.currentState;
            if (navigator == null) return;
            unawaited(
              navigator.pushReplacement(
                MaterialPageRoute<void>(
                  settings: const RouteSettings(name: 'Главная'),
                  builder: (_) => MainShell(
                    repository: repository,
                    progress: progress,
                    themeService: themeService,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
