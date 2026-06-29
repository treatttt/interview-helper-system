import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:interview_helper_system/controllers/home_controller.dart';
import 'package:interview_helper_system/models/models.dart';
import 'package:interview_helper_system/services/progress_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

Question _q(String id, [String topic = 'SQL']) => Question(
      id: id,
      text: 't',
      options: const ['A', 'B'],
      correctIndexes: const [0],
      topic: topic,
    );

Grade _grade(String id, List<Question> qs) =>
    Grade(id: id, title: id, order: 0, questions: qs);

Track _track(
  String id,
  List<Grade> grades, {
  int order = 0,
  String? category,
}) =>
    Track(id: id, title: id, order: order, grades: grades, category: category);

Future<ProgressService> _prefs(Map<String, Object> seed) async {
  SharedPreferences.setMockInitialValues(seed);
  final p = ProgressService(clock: () => DateTime(2026, 6, 29));
  await p.init();
  return p;
}

void main() {
  group('HomeController.splitDirections — «ваши» и «другие»', () {
    final tracks = [
      _track('development', [_grade('junior', [_q('d1')])], order: 0),
      _track('analytics', [_grade('junior', [_q('a1')])], order: 1),
      _track('english', [_grade('junior', [_q('e1')])],
          order: 2, category: 'language'),
    ];

    test('начатые направления уходят в «ваши», остальные в «другие»', () async {
      // Освоен вопрос analytics → этот трек «начат».
      final p = await _prefs({
        'mastered_ids': json.encode({
          'analytics_junior': ['a1'],
        }),
      });
      final split = HomeController(tracks: tracks, progress: p).splitDirections();
      expect(split.yours.map((t) => t.id), ['analytics']);
      expect(split.others.map((t) => t.id), ['development']);
    });

    test('языковые треки (category == language) исключаются полностью', () async {
      final p = await _prefs({
        'mastered_ids': json.encode({
          'analytics_junior': ['a1'],
        }),
      });
      final split = HomeController(tracks: tracks, progress: p).splitDirections();
      final all = [...split.yours, ...split.others].map((t) => t.id);
      expect(all, isNot(contains('english')));
    });

    test('ничего не начато → рекомендованный трек поднимается в «ваши»', () async {
      final p = await _prefs({});
      final split = HomeController(tracks: tracks, progress: p).splitDirections();
      // Рекомендация — первый по порядку грейд с непройденным: development(order 0).
      expect(split.yours.map((t) => t.id), ['development']);
      // И он не дублируется в «других».
      expect(split.others.map((t) => t.id), isNot(contains('development')));
      expect(split.others.map((t) => t.id), ['analytics']);
    });
  });

  group('HomeController.buildContinueCard — паузы', () {
    final tracks = [
      _track('t1', [
        Grade(id: 'g1', title: 'Junior', order: 0, questions: [
          _q('q1'),
          _q('q2'),
        ]),
      ]),
    ];

    test('протухшая пауза (грейд не из каталога) не строит «Продолжить»',
        () async {
      final p = await _prefs({});
      // gradeKey, которого нет в каталоге → пауза невалидна.
      await p.saveIncompleteSession({
        'gradeKey': 'ghost_grade',
        'questionIds': ['q1', 'q2'],
        'currentIndex': 1,
        'answeredData': const <Object>[],
      });

      final card = HomeController(tracks: tracks, progress: p)
          .buildContinueCard();
      // Пауза отвергнута → карточка не «Продолжить», а свежая рекомендация.
      expect(card, isNotNull);
      expect(card!.isResume, isFalse);
      expect(card.questionNumber, 0);
    });

    test('пауза тема-дрилла восстанавливается в «Продолжить» c темой', () async {
      final p = await _prefs({});
      // Нет основной паузы — только тема-дрилл.
      p.saveIncompleteTopicSessionSync({
        'gradeKey': 't1_g1',
        'questionIds': ['q1', 'q2'],
        'currentIndex': 0,
        'answeredData': const <Object>[],
        'topicTitle': 'SQL',
      });

      final card = HomeController(tracks: tracks, progress: p)
          .buildContinueCard();
      expect(card, isNotNull);
      expect(card!.isResume, isTrue);
      expect(card.title, 'SQL');
      expect(card.launch.topicTitle, 'SQL');
      expect(card.questionNumber, 1);
      expect(card.questionTotal, 2);
    });
  });
}
