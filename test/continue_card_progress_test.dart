import 'package:flutter_test/flutter_test.dart';
import 'package:interview_helper_system/controllers/home_controller.dart';
import 'package:interview_helper_system/models/models.dart';
import 'package:interview_helper_system/services/progress_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

Question _q(String id) => Question(
      id: id,
      text: 't',
      options: const ['A', 'B'],
      correctIndexes: const [0],
      topic: 'SQL',
    );

Track _track() => Track(
      id: 't1',
      title: 'Аналитика',
      order: 0,
      grades: [
        Grade(id: 'g1', title: 'Junior', order: 0, questions: [_q('q1'), _q('q2')]),
      ],
    );

Future<ProgressService> _service() async {
  SharedPreferences.setMockInitialValues({});
  final p = ProgressService();
  await p.init();
  return p;
}

void main() {
  test('полоса «Продолжить» отражает отвеченные, не позицию: 1 из 2 → 0.5',
      () async {
    final p = await _service();
    // Вышли на последнем вопросе 2/2, ответив только на первый.
    await p.saveIncompleteSession({
      'gradeKey': 't1_g1',
      'questionIds': ['q1', 'q2'],
      'currentIndex': 1,
      'answeredData': [
        {
          'id': 'q1',
          'selected': [0],
          'outcome': 'correct',
        },
      ],
    });

    final card = HomeController(tracks: [_track()], progress: p)
        .buildContinueCard();

    expect(card, isNotNull);
    expect(card!.isResume, isTrue);
    // Метка «Вопрос 2 / 2» корректна — мы продолжаем со второго вопроса…
    expect(card.questionNumber, 2);
    expect(card.questionTotal, 2);
    // …но полоса не должна быть полной: отвечён лишь 1 из 2.
    expect(card.progress, 0.5);
  });

  test('свежий старт: полоса пуста (0.0), не «полная»', () async {
    final p = await _service();
    final card = HomeController(tracks: [_track()], progress: p)
        .buildContinueCard();

    expect(card, isNotNull);
    expect(card!.isResume, isFalse);
    expect(card.questionNumber, 0);
    expect(card.progress, 0.0);
  });
}
