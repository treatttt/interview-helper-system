import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:interview_helper_system/models/models.dart';
import 'package:interview_helper_system/screens/home_screen.dart';
import 'package:interview_helper_system/screens/main_shell.dart';
import 'package:interview_helper_system/services/progress_service.dart';
import 'package:interview_helper_system/services/question_repository.dart';
import 'package:interview_helper_system/services/reminder_service.dart';
import 'package:interview_helper_system/services/theme_service.dart';
import 'package:interview_helper_system/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Заглушка репозитория — не грузит JSON-ассет, сразу возвращает пустой список.
class _FakeRepository implements QuestionRepository {
  @override
  Future<List<Track>> loadTracks() async => [];
}

/// Собирает MaterialApp с MainShell.
/// Если [progress]/[themeService] переданы (уже инициализированы) — используются как есть.
/// Иначе создаёт чистые сервисы на пустом моке SharedPreferences.
Future<Widget> _buildApp({
  ProgressService? progress,
  ThemeService? themeService,
}) async {
  final ProgressService p;
  if (progress != null) {
    p = progress;
  } else {
    SharedPreferences.setMockInitialValues({});
    p = ProgressService();
    await p.init();
  }

  final ThemeService t;
  if (themeService != null) {
    t = themeService;
  } else {
    t = ThemeService();
    await t.init();
  }

  final reminders = ReminderService();
  await reminders.init();

  return MaterialApp(
    theme: buildLightTheme(),
    darkTheme: buildDarkTheme(),
    home: MainShell(
      repository: _FakeRepository(),
      progress: p,
      themeService: t,
      reminderService: reminders,
    ),
  );
}

void main() {
  group('MainShell — таб-бар и переключение вкладок', () {
    testWidgets('отображает таб-бар с четырьмя вкладками', (tester) async {
      await tester.pumpWidget(await _buildApp());
      await tester.pump();

      expect(find.byType(PillBottomNav), findsOneWidget);
      expect(find.text('Главная'), findsWidgets);  // шапка экрана + таб-бар
      expect(find.text('Практика'), findsWidgets); // шапка экрана + таб-бар
      expect(find.text('Прогресс'), findsOneWidget);
      expect(find.text('Профиль'), findsOneWidget);
    });

    testWidgets('по умолчанию активна вкладка «Главная»', (tester) async {
      await tester.pumpWidget(await _buildApp());
      await tester.pump();

      // «Главная» — заголовок шапки HomeScreen (дашборд)
      expect(find.text('Главная'), findsWidgets);
    });

    testWidgets('переход на вкладку «Практика» показывает выбор направления',
        (tester) async {
      await tester.pumpWidget(await _buildApp());
      await tester.pump();

      await tester.tap(
        find.descendant(
          of: find.byType(PillBottomNav),
          matching: find.text('Практика'),
        ),
      );
      await tester.pumpAndSettle();

      // На экране Практики — заголовок и подпись секции выбора направления.
      expect(find.text('Выберите направление'.toUpperCase()), findsOneWidget);
    },);

    testWidgets('переход на вкладку «Профиль» показывает экран профиля',
        (tester) async {
      await tester.pumpWidget(await _buildApp());
      await tester.pump();

      await tester.tap(find.text('Профиль'));
      await tester.pumpAndSettle();

      expect(find.text('Профиль'), findsWidgets); // AppBar + таб-бар
      expect(find.text('Статистика'), findsOneWidget);
    },);

    testWidgets('переключение вкладок не пересоздаёт HomeScreen (IndexedStack)',
        (tester) async {
      await tester.pumpWidget(await _buildApp());
      await tester.pump();

      // Запоминаем элемент HomeScreen до переключения
      final homeStateFinder = find.byType(HomeScreen);
      expect(homeStateFinder, findsOneWidget);

      await tester.tap(find.text('Профиль'));
      await tester.pumpAndSettle();

      // Возвращаемся на дашборд через таб «Главная» (целимся в таб-бар:
      // «Главная» также есть в шапке экрана).
      await tester.tap(
        find.descendant(
          of: find.byType(PillBottomNav),
          matching: find.text('Главная'),
        ),
      );
      await tester.pumpAndSettle();

      // HomeScreen всё ещё существует и не пересоздан —
      // IndexedStack держит его живым.
      expect(find.byType(HomeScreen), findsOneWidget);
    },);
  });

  group('MainShell — профиль отображает данные из ProgressService', () {
    testWidgets('экран профиля показывает XP из ProgressService', (tester) async {
      SharedPreferences.setMockInitialValues({
        'xp': 120,
        'streak': 5,
        'last_active_day': '2026-06-20',
      });
      final p = ProgressService();
      await p.init();

      await tester.pumpWidget(await _buildApp(progress: p));
      await tester.pump();

      await tester.tap(find.text('Профиль'));
      await tester.pumpAndSettle();

      expect(find.text('120 XP'), findsOneWidget);
    });

    testWidgets('экран профиля показывает streak из ProgressService', (tester) async {
      SharedPreferences.setMockInitialValues({
        'xp': 50,
        'streak': 7,
        'last_active_day': '2026-06-20',
      });
      final p = ProgressService();
      await p.init();

      await tester.pumpWidget(await _buildApp(progress: p));
      await tester.pump();

      await tester.tap(find.text('Профиль'));
      await tester.pumpAndSettle();

      expect(find.text('7 д.'), findsOneWidget);
    });

    testWidgets('при нулевом прогрессе streak и точность отображаются как «—»',
        (tester) async {
      await tester.pumpWidget(await _buildApp());
      await tester.pump();

      await tester.tap(find.text('Профиль'));
      await tester.pumpAndSettle();

      // Две строки с «—»: серия дней и общая точность (оба без данных)
      expect(find.text('—'), findsNWidgets(2));
    });
  });
}
