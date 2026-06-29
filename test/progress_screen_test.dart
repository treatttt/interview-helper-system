import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:interview_helper_system/models/models.dart';
import 'package:interview_helper_system/screens/progress_screen.dart';
import 'package:interview_helper_system/services/progress_service.dart';
import 'package:interview_helper_system/services/question_repository.dart';
import 'package:interview_helper_system/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Заглушки ─────────────────────────────────────────────────────────────────

class _EmptyRepo implements QuestionRepository {
  @override
  Future<List<Track>> loadTracks() async => [];
}

class _FakeRepo implements QuestionRepository {
  _FakeRepo(this._tracks);
  final List<Track> _tracks;
  @override
  Future<List<Track>> loadTracks() async => _tracks;
}

// ── Вспомогательные фабрики ───────────────────────────────────────────────────

Question validQ(String id, {String? topic}) => Question(
      id: id,
      text: 'Q $id',
      options: const ['A', 'B'],
      correctIndexes: const [0],
      topic: topic,
    );

Grade gradeOf(String id, List<Question> qs, {int order = 0}) =>
    Grade(id: id, title: id, order: order, questions: qs);

Track trackOf(String id, List<Grade> grades) =>
    Track(id: id, title: id, order: 0, grades: grades);

Future<Widget> buildApp({
  QuestionRepository? repo,
  ProgressService? progress,
}) async {
  final ProgressService p;
  if (progress != null) {
    p = progress;
  } else {
    SharedPreferences.setMockInitialValues({});
    p = ProgressService();
    await p.init();
  }
  return MaterialApp(
    theme: buildLightTheme(),
    home: ProgressScreen(
      repository: repo ?? _EmptyRepo(),
      progress: p,
    ),
  );
}

void main() {
  group('ProgressScreen — структура экрана', () {
    testWidgets('отображает заголовок «Прогресс»', (tester) async {
      await tester.pumpWidget(await buildApp());
      await tester.pump();
      expect(find.text('Прогресс'), findsOneWidget);
    });

    testWidgets('отображает четыре карточки метрик', (tester) async {
      await tester.pumpWidget(await buildApp());
      await tester.pump();
      expect(find.text('Ответов'), findsOneWidget);
      expect(find.text('Точность'), findsOneWidget);
      expect(find.text('Серия, дней'), findsOneWidget);
      expect(find.text('Освоено тем'), findsOneWidget);
    });

    testWidgets('отображает секцию «ПО ГРЕЙДАМ»', (tester) async {
      await tester.pumpWidget(await buildApp());
      await tester.pump();
      expect(find.text('ПО ГРЕЙДАМ'), findsOneWidget);
    });

    testWidgets('отображает заголовок «Динамика точности»', (tester) async {
      await tester.pumpWidget(await buildApp());
      await tester.pump();
      expect(find.text('Динамика точности'), findsOneWidget);
    });
  });

  group('ProgressScreen — реальные данные из ProgressService', () {
    testWidgets('отображает totalAnswers из сервиса', (tester) async {
      SharedPreferences.setMockInitialValues({'total_answers': 42});
      final p = ProgressService();
      await p.init();

      await tester.pumpWidget(await buildApp(progress: p));
      await tester.pump();
      expect(find.text('42'), findsOneWidget);
    });

    testWidgets('отображает streak из сервиса', (tester) async {
      SharedPreferences.setMockInitialValues({
        'streak': 7,
        'last_active_day': '2026-06-29',
      });
      final p = ProgressService();
      await p.init();

      await tester.pumpWidget(await buildApp(progress: p));
      await tester.pump();
      expect(find.text('7'), findsOneWidget);
    });

    testWidgets('при нулевых данных totalAnswers отображается как «0»',
        (tester) async {
      await tester.pumpWidget(await buildApp());
      await tester.pump();
      // totalAnswers = 0, streak = 0
      expect(find.text('0'), findsWidgets);
    });
  });

  group('ProgressScreen — пустые состояния', () {
    testWidgets('пустой лог показывает «Пока нет данных»', (tester) async {
      await tester.pumpWidget(await buildApp());
      await tester.pump();
      expect(find.text('Пока нет данных'), findsOneWidget);
    });

    testWidgets('без треков грейды не отображаются', (tester) async {
      await tester.pumpWidget(await buildApp(repo: _EmptyRepo()));
      await tester.pump();
      // Не должно быть строк грейдов
      expect(find.text('Junior'), findsNothing);
    });
  });

  group('ProgressScreen — грейды', () {
    testWidgets('грейд без вопросов показывает бейдж «Скоро»', (tester) async {
      final repo = _FakeRepo([
        trackOf('t1', [gradeOf('senior', [], order: 2)]),
      ]);
      await tester.pumpWidget(await buildApp(repo: repo));
      await tester.pumpAndSettle();
      expect(find.text('Скоро'), findsOneWidget);
    });

    testWidgets('грейд с вопросами показывает LinearProgressIndicator',
        (tester) async {
      final repo = _FakeRepo([
        trackOf('t1', [
          gradeOf('junior', [validQ('q1'), validQ('q2')]),
        ]),
      ]);
      await tester.pumpWidget(await buildApp(repo: repo));
      await tester.pumpAndSettle();
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('грейды из треков перечислены по названию', (tester) async {
      final repo = _FakeRepo([
        trackOf('t1', [
          gradeOf('Junior', [validQ('q1')]),
          gradeOf('Middle', [validQ('q2')], order: 1),
        ]),
      ]);
      await tester.pumpWidget(await buildApp(repo: repo));
      await tester.pumpAndSettle();
      expect(find.text('Junior'), findsOneWidget);
      expect(find.text('Middle'), findsOneWidget);
    });
  });

  group('ProgressScreen — выбор роли в секции грейдов', () {
    Track roleOf(String id) => Track(
          id: id,
          title: id,
          order: 0,
          grades: [
            gradeOf('Junior', [validQ('${id}_q1')]),
            gradeOf('Middle', [validQ('${id}_q2')], order: 1),
            gradeOf('Senior', [validQ('${id}_q3')], order: 2),
          ],
        );

    testWidgets('по умолчанию показывает грейды первой роли', (tester) async {
      final repo = _FakeRepo([roleOf('Аналитик'), roleOf('Разработчик')]);
      await tester.pumpWidget(await buildApp(repo: repo));
      await tester.pumpAndSettle();

      // Селектор показывает первую роль, видны её три грейда.
      expect(find.text('Аналитик'), findsOneWidget);
      expect(find.text('Junior'), findsOneWidget);
      expect(find.text('Middle'), findsOneWidget);
      expect(find.text('Senior'), findsOneWidget);
      // Вторая роль ещё не выбрана — её заголовка на экране нет.
      expect(find.text('Разработчик'), findsNothing);
    });

    testWidgets('всплывающий список перечисляет все роли', (tester) async {
      final repo = _FakeRepo([roleOf('Аналитик'), roleOf('Разработчик')]);
      await tester.pumpWidget(await buildApp(repo: repo));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Аналитик'));
      await tester.pumpAndSettle();

      expect(find.text('Выберите роль'), findsOneWidget);
      // Обе роли присутствуют в списке.
      expect(find.text('Разработчик'), findsOneWidget);
    });

    testWidgets('выбор другой роли переключает отображаемые грейды',
        (tester) async {
      final repo = _FakeRepo([
        roleOf('Аналитик'),
        Track(
          id: 'Разработчик',
          title: 'Разработчик',
          order: 1,
          grades: [gradeOf('Lead', [validQ('dev_q1')])],
        ),
      ]);
      await tester.pumpWidget(await buildApp(repo: repo));
      await tester.pumpAndSettle();

      // Открываем список и выбираем вторую роль.
      await tester.tap(find.text('Аналитик'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Разработчик').last);
      await tester.pumpAndSettle();

      // Теперь показан грейд второй роли, а грейды первой исчезли.
      expect(find.text('Lead'), findsOneWidget);
      expect(find.text('Junior'), findsNothing);
    });
  });
}
