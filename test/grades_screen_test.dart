import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:interview_helper_system/models/models.dart';
import 'package:interview_helper_system/screens/grades_screen.dart';
import 'package:interview_helper_system/screens/session_screen.dart';
import 'package:interview_helper_system/services/progress_service.dart';
import 'package:mocktail/mocktail.dart';

// --- Test double -----------------------------------------------------------
// ProgressService is a Listenable (used inside ListenableBuilder). mocktail
// fills any method we don't stub via noSuchMethod, so addListener/removeListener
// are inert and the widget won't rebuild on its own — which is what we want.
class MockProgressService extends Mock implements ProgressService {}

// --- Test data builders ----------------------------------------------------
// ADJUST these three to match your real constructors in models.dart.
// Nothing below this section depends on the exact field layout.
Question _question(String id) =>
    Question(id: id, text: '', options: [], correctIndexes: []);

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
    // Safe defaults; individual tests override what they need.
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
        grades: [_grade(id: 'g1', title: 'Junior', questions: const [])],
      );
      await pumpScreen(tester, track);

      expect(find.text('Скоро'), findsOneWidget);

      // Attack: a disabled card must be inert — no dialog, no crash.
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
        grades: [_grade(id: 'g1', title: 'Junior', questions: const [])],
      );
      await pumpScreen(tester, track);

      // total == 0 path: pct must be 0.0, bar hidden, no exception thrown.
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  // === onTap switch: (true, true) => _resetGrade ============================
  testWidgets('fully mastered grade opens RESET confirmation, not a session',
      (tester) async {
    final track = _track(
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
    when(() => progress.masteredIds('t1', 'g1')).thenReturn({'q1', 'q2'});

    await pumpScreen(tester, track);
    expect(find.text('Все пройдены'), findsOneWidget);

    await tester.tap(find.text('Junior'));
    await tester.pumpAndSettle();

    // Must be the reset confirm — and explicitly NOT a session.
    expect(find.text('Сбросить прогресс?'), findsOneWidget);
    expect(find.byType(SessionScreen), findsNothing);
  });

  // === Adversarial boundary: mastered count exceeds total ===================
  testWidgets('stale mastered ids beyond total are treated as done, no crash',
      (tester) async {
    final track = _track(
      id: 't1',
      title: 'Backend',
      grades: [
        _grade(id: 'g1', title: 'Junior', questions: [_question('q1')])
      ],
    );
    // 3 mastered ids, only 1 real question (e.g. deleted questions left in storage).
    when(() => progress.masteredIds('t1', 'g1'))
        .thenReturn({'q1', 'stale1', 'stale2'});

    await pumpScreen(tester, track);

    // done(3) >= total(1) -> allDone branch, pct = 3.0 must not blow up.
    expect(tester.takeException(), isNull);
    expect(find.text('Все пройдены'), findsOneWidget);

    await tester.tap(find.text('Junior'));
    await tester.pumpAndSettle();
    expect(find.text('Сбросить прогресс?'), findsOneWidget);
  });
}
