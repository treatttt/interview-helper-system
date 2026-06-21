import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:interview_helper_system/models/models.dart';
import 'package:interview_helper_system/screens/grades_screen.dart';
import 'package:interview_helper_system/screens/session_screen.dart';
import 'package:interview_helper_system/services/progress_service.dart';
import 'package:mocktail/mocktail.dart';

// --- Test double -----------------------------------------------------------
class MockProgressService extends Mock implements ProgressService {}

// --- Test data builders ----------------------------------------------------
// ADJUST to match models.dart if more required fields appear.
Question _question(String id) => Question(id: id, text: '', options: [], correctIndexes: []);

Grade _grade({
  required String id,
  required String title,
  int order = 0,
  String? description,
  List<Question> questions = const [],
}) =>
    Grade(
      id: id,
      title: title,
      order: order,
      description: description,
      questions: questions,
    );

Track _track({
  required String id,
  required String title,
  int order = 0,
  String? description,
  List<Grade> grades = const [],
}) =>
    Track(
      id: id,
      title: title,
      order: order,
      description: description,
      grades: grades,
    );

void main() {
  late MockProgressService progress;

  setUp(() {
    progress = MockProgressService();
    when(() => progress.masteredIds(any(), any())).thenReturn(<String>{});
    when(() => progress.loadIncompleteSession(any())).thenReturn(null);
    when(
          () => progress.clearIncompleteSession(gradeKey: any(named: 'gradeKey')),
    ).thenAnswer((_) async {});
    when(() => progress.resetGrade(any(), any())).thenAnswer((_) async {});
  });

  Future<void> pumpScreen(WidgetTester tester, Track track) {
    return tester.pumpWidget(
      MaterialApp(home: GradesScreen(track: track, progress: progress)),
    );
  }

  // === onTap switch: (false, _) => null =====================================
  group('grade without questions', () {
    testWidgets('shows "Скоро" and tapping it does nothing', (tester) async {
      final track = _track(
        id: 't1',
        title: 'Backend',
        grades: [_grade(id: 'g1', title: 'Junior')],
      );
      await pumpScreen(tester, track);

      expect(find.text('Скоро'), findsOneWidget);
      await tester.tap(find.text('Junior'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders no progress bar and never divides by zero',
            (tester) async {
          final track = _track(
            id: 't1',
            title: 'Backend',
            grades: [_grade(id: 'g1', title: 'Junior')],
          );
          await pumpScreen(tester, track);

          expect(find.byType(LinearProgressIndicator), findsNothing);
          expect(tester.takeException(), isNull);
        });
  });

  // === Descriptions: build (lines 162-166) + card (lines 229-233) ===========
  testWidgets('renders track and grade descriptions when present',
          (tester) async {
        final track = _track(
          id: 't1',
          title: 'Backend',
          description: 'Серверная разработка',
          grades: [
            _grade(
              id: 'g1',
              title: 'Junior',
              description: 'Базовый уровень',
              questions: [_question('q1')],
            ),
          ],
        );
        await pumpScreen(tester, track);

        expect(find.text('Серверная разработка'), findsOneWidget);
        expect(find.text('Базовый уровень'), findsOneWidget);
      });

  // === In-progress grade: switch arm (true,false) + trailing (276-300) ======
  group('in-progress grade', () {
    Track inProgress() => _track(
      id: 't1',
      title: 'Backend',
      grades: [
        _grade(
          id: 'g1',
          title: 'Junior',
          questions: [_question('q1'), _question('q2')],
        ),
      ],
    );

    testWidgets('shows count, reset control and chevron', (tester) async {
      // 1 of 2 mastered -> hasQuestions && !allDone -> the (true,false) arm.
      when(() => progress.masteredIds('t1', 'g1')).thenReturn({'q1'});
      await pumpScreen(tester, inProgress());

      expect(find.text('1/2'), findsOneWidget);
      expect(find.byTooltip('Сбросить прогресс'), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('tapping the in-card reset control opens confirmation',
            (tester) async {
          // Covers the GestureDetector.onTap on the reset icon (not the card itself).
          when(() => progress.masteredIds('t1', 'g1')).thenReturn({'q1'});
          await pumpScreen(tester, inProgress());

          await tester.tap(find.byTooltip('Сбросить прогресс'));
          await tester.pumpAndSettle();

          expect(find.text('Сбросить прогресс?'), findsOneWidget);
          // The reset path must not open a session.
          expect(find.byType(SessionScreen), findsNothing);
        });
  });

  // === Reset dialog buttons: lines 133, 137, 143-144 ========================
  group('reset confirmation dialog', () {
    Track allDone() => _track(
      id: 't1',
      title: 'Backend',
      grades: [
        _grade(
          id: 'g1',
          title: 'Junior',
          questions: [_question('q1'), _question('q2')],
        ),
      ],
    );

    testWidgets('"Отмена" dismisses without resetting', (tester) async {
      when(() => progress.masteredIds('t1', 'g1')).thenReturn({'q1', 'q2'});
      await pumpScreen(tester, allDone());

      await tester.tap(find.text('Junior'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Отмена'));
      await tester.pumpAndSettle();

      expect(find.text('Сбросить прогресс?'), findsNothing);
      verifyNever(() => progress.resetGrade(any(), any()));
    });

    testWidgets('"Сбросить" calls resetGrade with track and grade ids',
            (tester) async {
          when(() => progress.masteredIds('t1', 'g1')).thenReturn({'q1', 'q2'});
          await pumpScreen(tester, allDone());

          await tester.tap(find.text('Junior'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Сбросить'));
          await tester.pumpAndSettle();

          verify(() => progress.resetGrade('t1', 'g1')).called(1);
        });
  });

  // === Adversarial boundary: mastered count exceeds total ===================
  testWidgets('stale mastered ids beyond total are treated as done, no crash',
          (tester) async {
        final track = _track(
          id: 't1',
          title: 'Backend',
          grades: [_grade(id: 'g1', title: 'Junior', questions: [_question('q1')])],
        );
        when(() => progress.masteredIds('t1', 'g1'))
            .thenReturn({'q1', 'stale1', 'stale2'});

        await pumpScreen(tester, track);

        expect(tester.takeException(), isNull);
        expect(find.text('Все пройдены'), findsOneWidget);

        await tester.tap(find.text('Junior'));
        await tester.pumpAndSettle();
        expect(find.text('Сбросить прогресс?'), findsOneWidget);
      });

  // === _openSession: lines 25-121 (navigates into a real SessionScreen) =====
  group('opening a session', () {
    Track inProgress() => _track(
      id: 't1',
      title: 'Backend',
      grades: [
        _grade(
          id: 'g1',
          title: 'Junior',
          questions: [_question('q1'), _question('q2')],
        ),
      ],
    );

    testWidgets('in-progress grade with no saved session opens SessionScreen',
            (tester) async {
          when(() => progress.masteredIds('t1', 'g1')).thenReturn({'q1'});
          // loadIncompleteSession -> null (default) takes the else-branch.
          await pumpScreen(tester, inProgress());

          await tester.tap(find.text('Junior'));
          await tester.pumpAndSettle();
          expect(find.byType(SessionScreen), findsOneWidget);

          // Pop back so _openSession resumes and its `finally` resets _opening.
          await tester.pageBack();
          await tester.pumpAndSettle();
          expect(find.byType(SessionScreen), findsNothing);
          expect(tester.takeException(), isNull);
        });

    testWidgets('saved session + "Начать заново" clears it and opens a session',
            (tester) async {
          when(() => progress.masteredIds('t1', 'g1')).thenReturn({'q1'});
          when(() => progress.loadIncompleteSession('t1_g1')).thenReturn({
            'gradeKey': 't1_g1',
            'questionIds': ['q1', 'q2'],
            'currentIndex': 0,
            'answeredData': <Map<String, dynamic>>[],
          });
          await pumpScreen(tester, inProgress());

          await tester.tap(find.text('Junior'));
          await tester.pumpAndSettle();
          // _showResumeDialog rendered.
          expect(find.text('Незавершённая сессия'), findsOneWidget);

          await tester.tap(find.text('Начать заново'));
          await tester.pumpAndSettle();

          verify(() => progress.clearIncompleteSession(gradeKey: 't1_g1')).called(1);
          expect(find.byType(SessionScreen), findsOneWidget);
        });

    testWidgets(
        'saved session + barrier dismiss (null) → no SessionScreen, no clear',
        (tester) async {
      when(() => progress.masteredIds('t1', 'g1')).thenReturn({'q1'});
      when(() => progress.loadIncompleteSession('t1_g1')).thenReturn({
        'gradeKey': 't1_g1',
        'questionIds': ['q1', 'q2'],
        'currentIndex': 0,
        'answeredData': <Map<String, dynamic>>[],
      });
      await pumpScreen(tester, inProgress());

      await tester.tap(find.text('Junior'));
      await tester.pumpAndSettle();
      // Dialog is showing; simulate system back / programmatic null pop.
      tester.state<NavigatorState>(find.byType(Navigator).last).pop();
      await tester.pumpAndSettle();

      expect(find.byType(SessionScreen), findsNothing);
      verifyNever(
        () => progress.clearIncompleteSession(gradeKey: any(named: 'gradeKey')),
      );
    },);

    testWidgets('saved session + "Продолжить" resumes into a session',
            (tester) async {
          when(() => progress.masteredIds('t1', 'g1')).thenReturn({'q1'});
          // Empty answeredData keeps us off the AnswerOutcome.byName parse (see note).
          when(() => progress.loadIncompleteSession('t1_g1')).thenReturn({
            'gradeKey': 't1_g1',
            'questionIds': ['q1', 'q2'],
            'currentIndex': 0,
            'answeredData': <Map<String, dynamic>>[],
          });
          await pumpScreen(tester, inProgress());

          await tester.tap(find.text('Junior'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Продолжить'));
          await tester.pumpAndSettle();

          expect(find.byType(SessionScreen), findsOneWidget);
          verifyNever(
                () => progress.clearIncompleteSession(gradeKey: any(named: 'gradeKey')),
          );
        });
  });
}