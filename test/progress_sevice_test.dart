import 'package:flutter_test/flutter_test.dart';
import 'package:interview_helper_system/controllers/session_controller.dart';
import 'package:interview_helper_system/services/progress_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  // Результат сессии с нужным числом верных.
  // correctIds: 'q1'..'qN' — уникальны по позиции, имитируют реальные ID.
  SessionResult res(int correct, {int total = 4}) => SessionResult(
    correct: correct,
    partial: 0,
    wrong: total - correct,
    points: correct,
    maxPoints: total,
    answers: const [],
    correctIds: {for (int i = 0; i < correct; i++) 'q${i + 1}'},
  );

  // Свежий проинициализированный сервис на чистом хранилище.
  Future<ProgressService> freshService() async {
    SharedPreferences.setMockInitialValues({});
    final p = ProgressService();
    await p.init();
    return p;
  }

  group('ProgressService — экономика XP (защита от фарма и регресса)', () {
    test('первое прохождение начисляет XP за все верные', () async {
      final p = await freshService();
      await p.recordSession('t1', res(4));
      expect(p.xp, 40); // 4 верных * 10
      expect(p.topicDone('t1'), 4);
    });

    test('повтор пройденной темы без улучшения НЕ начисляет XP (анти-фарм)',
            () async {
          final p = await freshService();
          await p.recordSession('t1', res(4)); // 40 XP
          await p.recordSession('t1', res(4)); // повтор того же результата
          await p.recordSession('t1', res(4)); // и ещё раз
          expect(p.xp, 40); // не выросло — фарм закрыт
          expect(p.topicDone('t1'), 4);
        });

    test('частичное улучшение начисляет XP только за прирост', () async {
      final p = await freshService();
      await p.recordSession('t1', res(2)); // 0→2: +20
      expect(p.xp, 20);
      await p.recordSession('t1', res(4)); // 2→4: доплата только за 2
      expect(p.xp, 40); // 20 + 20, не 20 + 40
      expect(p.topicDone('t1'), 4);
    });

    test('результат ХУЖЕ прежнего рекорда не отнимает XP и не уводит в минус',
            () async {
          final p = await freshService();
          await p.recordSession('t1', res(4)); // рекорд 4, XP 40
          await p.recordSession('t1', res(1)); // регресс: прошёл хуже
          expect(p.xp, 40); // XP не уменьшился
          expect(p.topicDone('t1'), 4); // рекорд темы не откатился вниз
        });

    test('две разные темы копят XP независимо', () async {
      final p = await freshService();
      await p.recordSession('t1', res(3));
      await p.recordSession('t2', res(2));
      expect(p.xp, 50); // 30 + 20
      expect(p.topicDone('t1'), 3);
      expect(p.topicDone('t2'), 2);
    });

    test('ноль верных не даёт XP и не создаёт ложный рекорд', () async {
      final p = await freshService();
      await p.recordSession('t1', res(0));
      expect(p.xp, 0);
      expect(p.topicDone('t1'), 0);
    });
  });

  group('ProgressService — streak и hasTrainedEver', () {
    test('до первой сессии: streak 0, hasTrainedEver false', () async {
      final p = await freshService();
      expect(p.streak, 0);
      expect(p.hasTrainedEver, isFalse);
    });

    test('первая сессия: streak становится 1, hasTrainedEver true', () async {
      final p = await freshService();
      await p.recordSession('t1', res(2));
      expect(p.streak, 1);
      expect(p.hasTrainedEver, isTrue);
    });

    test('две сессии в один день не увеличивают streak', () async {
      final p = await freshService();
      await p.recordSession('t1', res(2));
      await p.recordSession('t2', res(2)); // тот же день
      expect(p.streak, 1); // не 2 — занятие засчитано один раз за день
    });

    test('persistence: XP и рекорд переживают пересоздание сервиса', () async {
      // setMockInitialValues + init записали в общий мок-стор; новый сервис
      // на том же сторе должен прочитать сохранённое.
      SharedPreferences.setMockInitialValues({});
      final p1 = ProgressService();
      await p1.init();
      await p1.recordSession('t1', res(3)); // 30 XP, рекорд 3

      final p2 = ProgressService(); // не сбрасываем мок-стор
      await p2.init();
      expect(p2.xp, 30);
      expect(p2.topicDone('t1'), 3);
      expect(p2.hasTrainedEver, isTrue);
    });
  });
}