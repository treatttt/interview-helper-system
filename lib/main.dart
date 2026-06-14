import 'package:flutter/material.dart';
import 'services/question_repository.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const InterviewHelperApp());
}

class InterviewHelperApp extends StatelessWidget {
  const InterviewHelperApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Единственная точка выбора источника вопросов.
    // Для перехода на сервер здесь меняется JsonQuestionRepository
    // на ApiQuestionRepository — экраны это не затронет.
    final QuestionRepository repository = JsonQuestionRepository();

    return MaterialApp(
      title: 'Тренажёр собеседований',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true),
      home: HomeScreen(repository: repository),
    );
  }
}