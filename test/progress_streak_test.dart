import 'package:flutter_test/flutter_test.dart';
import 'package:interview_helper_system/controllers/session_controller.dart';
import 'package:interview_helper_system/services/progress_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  // Для серии важен сам факт завершённой сессии — счётчики/XP на streak не влияют.
  const session = SessionResult(
    correct: 1,
    partial: 0,
    wrong: 0,
    points: 1,
    maxPoints: 1,
    answers: [],
  );

  late DateTime fakeNow;
  late ProgressService progress;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    fakeNow = DateTime(2024, 6, 10, 9); // дефолт, тесты переопределяют
    progress = ProgressService(clock: () => fakeNow);
    await progress.init(); // пустой мок → xp=0, streak=0, lastDay=null
  });

  group('Streak — границы дня', () {
    test('первая сессия открывает серию = 1', () async {
      await progress.recordSession('t1', session);
      expect(progress.streak, 1);
    });

    test('вторая сессия в тот же день не меняет серию', () async {
      await progress.recordSession('t1', session);
      fakeNow = DateTime(2024, 6, 10, 22, 30); // тот же календарный день
      await progress.recordSession('t1', session);
      expect(progress.streak, 1);
    });

    test('занятие на следующий день продлевает серию', () async {
      await progress.recordSession('t1', session);
      fakeNow = DateTime(2024, 6, 11, 9);
      await progress.recordSession('t1', session);
      expect(progress.streak, 2);
    });

    test('пропуск дня сбрасывает серию на 1', () async {
      await progress.recordSession('t1', session);
      fakeNow = DateTime(2024, 6, 12, 9); // через день
      await progress.recordSession('t1', session);
      expect(progress.streak, 1);
    });

    test('продление через границу месяца (30 июн → 1 июл, около полуночи)', () async {
      fakeNow = DateTime(2024, 6, 30, 23, 50);
      await progress.recordSession('t1', session);
      fakeNow = DateTime(2024, 7, 1, 0, 10);
      await progress.recordSession('t1', session);
      expect(progress.streak, 2);
    });

    test('продление через границу года (31 дек → 1 янв, около полуночи)', () async {
      fakeNow = DateTime(2024, 12, 31, 23, 50);
      await progress.recordSession('t1', session);
      fakeNow = DateTime(2025, 1, 1, 0, 10);
      await progress.recordSession('t1', session);
      expect(progress.streak, 2);
    });
  });
}