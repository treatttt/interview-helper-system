import 'package:flutter_test/flutter_test.dart';
import 'package:interview_helper_system/models/models.dart';
import 'package:interview_helper_system/services/question_repository.dart';

// ── helpers ──────────────────────────────────────────────────────────────────

Question _q(String id, {String? topic}) => Question(
      id: id,
      text: 'Вопрос $id?',
      options: const ['A', 'B'],
      correctIndexes: const [0],
      topic: topic,
    );

Grade _grade(String id, List<Question> questions) => Grade(
      id: id,
      title: id,
      order: 0,
      questions: questions,
    );

Track _track(String id, List<Grade> grades) =>
    Track(id: id, title: id, order: 0, grades: grades);

// ─────────────────────────────────────────────────────────────────────────────

void main() {
  group('aggregateTopics', () {
    test('пустой список треков → пустой список тем', () {
      expect(aggregateTopics([]), isEmpty);
    });

    test('грейд без вопросов не создаёт тему', () {
      final tracks = [_track('t', [_grade('g', [])])];
      expect(aggregateTopics(tracks), isEmpty);
    });

    test('вопросы без topic (null) не включаются в группы', () {
      final tracks = [
        _track('t', [
          _grade('g', [_q('q1'), _q('q2')]), // topic == null
        ]),
      ];
      expect(aggregateTopics(tracks), isEmpty);
    });

    test('одна тема из одного грейда собирается корректно', () {
      final tracks = [
        _track('t1', [
          _grade('g1', [_q('q1', topic: 'SQL'), _q('q2', topic: 'SQL')]),
        ]),
      ];
      final groups = aggregateTopics(tracks);
      expect(groups, hasLength(1));
      expect(groups.single.title, 'SQL');
      expect(groups.single.questions, hasLength(2));
    });

    test('одинаковая topic из разных грейдов одного трека схлопывается в одну группу', () {
      final tracks = [
        _track('t1', [
          _grade('junior', [_q('q1', topic: 'SQL')]),
          _grade('middle', [_q('q2', topic: 'SQL')]),
        ]),
      ];
      final groups = aggregateTopics(tracks);
      expect(groups, hasLength(1));
      expect(groups.single.questions, hasLength(2));
    });

    test('одинаковая topic из разных треков схлопывается в одну группу', () {
      final tracks = [
        _track('analytics', [
          _grade('junior', [_q('q1', topic: 'SQL')]),
        ]),
        _track('development', [
          _grade('junior', [_q('q2', topic: 'SQL')]),
        ]),
      ];
      final groups = aggregateTopics(tracks);
      expect(groups, hasLength(1));
      expect(groups.single.title, 'SQL');
      expect(groups.single.questions, hasLength(2));
    });

    test('разные темы из одного грейда создают отдельные группы', () {
      final tracks = [
        _track('t', [
          _grade('g', [
            _q('q1', topic: 'SQL'),
            _q('q2', topic: 'API'),
          ]),
        ]),
      ];
      final groups = aggregateTopics(tracks);
      expect(groups, hasLength(2));
    });

    test('каждый QuestionOrigin несёт правильный gradeKey', () {
      final tracks = [
        _track('analytics', [
          _grade('junior', [_q('q1', topic: 'SQL')]),
        ]),
      ];
      final groups = aggregateTopics(tracks);
      expect(groups.single.questions.single.gradeKey, 'analytics_junior');
    });

    test('результат отсортирован по алфавиту', () {
      final tracks = [
        _track('t', [
          _grade('g', [
            _q('q1', topic: 'SQL'),
            _q('q2', topic: 'API'),
            _q('q3', topic: 'Нотации'),
          ]),
        ]),
      ];
      final titles = aggregateTopics(tracks).map((g) => g.title).toList();
      // String.compareTo использует Unicode code points: Latin < Cyrillic.
      expect(titles, ['API', 'SQL', 'Нотации']);
    });

    test('пустая тема (пустая строка) не включается', () {
      final tracks = [
        _track('t', [
          _grade('g', [_q('q1', topic: '')]),
        ]),
      ];
      expect(aggregateTopics(tracks), isEmpty);
    });

    test('смешанные: часть с topic, часть null — включаются только с topic', () {
      final tracks = [
        _track('t', [
          _grade('g', [
            _q('q1', topic: 'SQL'),
            _q('q2'), // topic == null
          ]),
        ]),
      ];
      final groups = aggregateTopics(tracks);
      expect(groups, hasLength(1));
      expect(groups.single.questions, hasLength(1));
      expect(groups.single.questions.single.question.id, 'q1');
    });
  });
}
