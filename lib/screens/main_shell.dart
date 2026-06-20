import 'package:flutter/material.dart';
import 'package:interview_helper_system/screens/home_screen.dart';
import 'package:interview_helper_system/screens/profile_screen.dart';
import 'package:interview_helper_system/screens/topics_screen.dart';
import 'package:interview_helper_system/services/progress_service.dart';
import 'package:interview_helper_system/services/question_repository.dart';
import 'package:interview_helper_system/services/theme_service.dart';

/// Корневой экран после онбординга: NavigationBar (Material 3) + IndexedStack.
///
/// Вкладки: Обзор (дашборд готовности) / Темы (каталог направлений) / Профиль.
/// IndexedStack сохраняет состояние всех вкладок между переключениями.
/// Переходы в сессию/результат/разбор открываются через Navigator.push
/// поверх этого экрана — таб-бар при этом скрывается, что соответствует
/// стандартному поведению Flutter Navigator.
class MainShell extends StatefulWidget {
  const MainShell({
    required this.repository,
    required this.progress,
    required this.themeService,
    super.key,
  });

  final QuestionRepository repository;
  final ProgressService progress;
  final ThemeService themeService;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          HomeScreen(
            repository: widget.repository,
            progress: widget.progress,
          ),
          TopicsScreen(
            repository: widget.repository,
            progress: widget.progress,
          ),
          ProfileScreen(
            progress: widget.progress,
            themeService: widget.themeService,
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (i) => setState(() => _selectedIndex = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Обзор',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book),
            label: 'Темы',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Профиль',
          ),
        ],
      ),
    );
  }
}
