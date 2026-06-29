import 'package:flutter_test/flutter_test.dart';
import 'package:interview_helper_system/controllers/session_controller.dart';
import 'package:interview_helper_system/models/models.dart';
import 'package:interview_helper_system/services/progress_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Сессия с [n] отвеченными вопросами (для дневного счётчика важна длина answers).
SessionResult _session(int n) {
  final answers = [
    for (var i = 0; i < n; i++)
      AnsweredQuestion(
        question: Question(
          id: 'q$i',
          text: 't',
          options: const ['A', 'B'],
          correctIndexes: const [0],
        ),
        selected: const {0},
        outcome: AnswerOutcome.correct,
      ),
  ];
  return SessionResult(
    correct: n,
    partial: 0,
    wrong: 0,
    points: n,
    maxPoints: n,
    answers: answers,
  );
}

void main() {
  late DateTime fakeNow;
  late ProgressService progress;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    fakeNow = DateTime(2026, 6, 29, 9);
    progress = ProgressService(clock: () => fakeNow);
    await progress.init();
  });

  test('новый профиль — отвечено сегодня = 0', () {
    expect(progress.answeredToday, 0);
  });

  test('записанная сессия добавляет вопросы к дневному счётчику', () async {
    await progress.recordSession('t1', _session(3));
    expect(progress.answeredToday, 3);

    await progress.recordSession('t1', _session(2));
    expect(progress.answeredToday, 5);
  });

  test('счётчик обнуляется на новый день', () async {
    await progress.recordSession('t1', _session(4));
    expect(progress.answeredToday, 4);

    // Следующий день — даже без новой записи счётчик «протух».
    fakeNow = DateTime(2026, 6, 30, 9);
    expect(progress.answeredToday, 0);

    // Новая запись на новый день стартует с нуля.
    await progress.recordSession('t1', _session(1));
    expect(progress.answeredToday, 1);
  });

  test('resetAll сбрасывает дневной счётчик', () async {
    await progress.recordSession('t1', _session(5));
    expect(progress.answeredToday, 5);

    await progress.resetAll();
    expect(progress.answeredToday, 0);
  });
}
