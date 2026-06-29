import 'package:flutter_test/flutter_test.dart';
import 'package:interview_helper_system/models/models.dart';
import 'package:interview_helper_system/screens/progress_metrics.dart';

void main() {
  // ── Вспомогательные фабрики ───────────────────────────────────────────────

  Question validQ(String id, {String? topic}) => Question(
        id: id,
        text: 'Question $id',
        options: const ['A', 'B'],
        correctIndexes: const [0],
        topic: topic,
      );

  Grade grade(String id, List<Question> questions, {int order = 0}) => Grade(
        id: id,
        title: id,
        order: order,
        questions: questions,
      );

  Track track(String id, List<Grade> grades) =>
      Track(id: id, title: id, order: 0, grades: grades);

  Set<String> noMastered(String trackId, String gradeId) => const {};

  // ── countMasteredTopics ───────────────────────────────────────────────────

  group('countMasteredTopics', () {
    test('пустой каталог → 0', () {
      expect(countMasteredTopics([], noMastered), 0);
    });

    test('нет освоенных вопросов → 0', () {
      final tracks = [
        track('t1', [
          grade('junior', [
            validQ('q1', topic: 'SQL'),
            validQ('q2', topic: 'SQL'),
          ]),
        ]),
      ];
      expect(countMasteredTopics(tracks, noMastered), 0);
    });

    test('все вопросы темы освоены → тема засчитана', () {
      final tracks = [
        track('t1', [
          grade('junior', [
            validQ('q1', topic: 'SQL'),
            validQ('q2', topic: 'SQL'),
          ]),
        ]),
      ];
      Set<String> mastered(String tid, String gid) => {'q1', 'q2'};
      expect(countMasteredTopics(tracks, mastered), 1);
    });

    test('часть вопросов темы не освоена → тема не засчитана', () {
      final tracks = [
        track('t1', [
          grade('junior', [
            validQ('q1', topic: 'SQL'),
            validQ('q2', topic: 'SQL'),
          ]),
        ]),
      ];
      Set<String> mastered(String tid, String gid) => {'q1'};
      expect(countMasteredTopics(tracks, mastered), 0);
    });

    test('вопросы без темы не учитываются', () {
      final tracks = [
        track('t1', [
          grade('junior', [
            validQ('q1'), // topic == null
          ]),
        ]),
      ];
      Set<String> mastered(String tid, String gid) => {'q1'};
      expect(countMasteredTopics(tracks, mastered), 0);
    });

    test('тема освоена независимо от того, через какой грейд', () {
      // Вопросы одной темы в разных грейдах
      final tracks = [
        track('t1', [
          grade('junior', [validQ('q1', topic: 'SQL')]),
          grade('middle', [validQ('q2', topic: 'SQL')]),
        ]),
      ];
      Set<String> mastered(String tid, String gid) {
        if (gid == 'junior') return {'q1'};
        if (gid == 'middle') return {'q2'};
        return {};
      }
      expect(countMasteredTopics(tracks, mastered), 1);
    });

    test('две темы: обе освоены → 2', () {
      final tracks = [
        track('t1', [
          grade('junior', [
            validQ('q1', topic: 'SQL'),
            validQ('q2', topic: 'OOP'),
          ]),
        ]),
      ];
      Set<String> mastered(String tid, String gid) => {'q1', 'q2'};
      expect(countMasteredTopics(tracks, mastered), 2);
    });

    test('две темы: одна не освоена → 1', () {
      final tracks = [
        track('t1', [
          grade('junior', [
            validQ('q1', topic: 'SQL'),
            validQ('q2', topic: 'OOP'),
          ]),
        ]),
      ];
      Set<String> mastered(String tid, String gid) => {'q1'};
      expect(countMasteredTopics(tracks, mastered), 1);
    });
  });

  // ── gradeProgress ─────────────────────────────────────────────────────────

  group('gradeProgress', () {
    test('грейд без валидных вопросов → isSoon: true, fraction: 0', () {
      final g = grade('senior', []);
      final result = gradeProgress('t1', g, noMastered);
      expect(result.isSoon, isTrue);
      expect(result.fraction, 0.0);
    });

    test('ноль освоенных → fraction: 0.0', () {
      final g = grade('junior', [validQ('q1'), validQ('q2')]);
      final result = gradeProgress('t1', g, noMastered);
      expect(result.isSoon, isFalse);
      expect(result.fraction, closeTo(0.0, 0.001));
    });

    test('все освоены → fraction: 1.0', () {
      final g = grade('junior', [validQ('q1'), validQ('q2')]);
      Set<String> mastered(String tid, String gid) => {'q1', 'q2'};
      final result = gradeProgress('t1', g, mastered);
      expect(result.isSoon, isFalse);
      expect(result.fraction, closeTo(1.0, 0.001));
    });

    test('половина освоена → fraction: 0.5', () {
      final g = grade('junior', [validQ('q1'), validQ('q2')]);
      Set<String> mastered(String tid, String gid) => {'q1'};
      final result = gradeProgress('t1', g, mastered);
      expect(result.fraction, closeTo(0.5, 0.001));
    });

    test('невалидные вопросы не учитываются в знаменателе', () {
      // Невалидный: пустой текст
      const invalid = Question(
        id: 'qInvalid',
        text: '',
        options: ['A', 'B'],
        correctIndexes: [0],
      );
      final g = grade('junior', [validQ('q1'), invalid]);
      // Только 1 валидный вопрос. Освоен q1.
      Set<String> mastered(String tid, String gid) => {'q1'};
      final result = gradeProgress('t1', g, mastered);
      expect(result.fraction, closeTo(1.0, 0.001));
    });

    test('fraction зажата в [0, 1] (не выходит за границы)', () {
      final g = grade('junior', [validQ('q1')]);
      // Освоено больше, чем валидных (нереальный edge-case)
      Set<String> mastered(String tid, String gid) => {'q1', 'q2', 'q3'};
      final result = gradeProgress('t1', g, mastered);
      expect(result.fraction, lessThanOrEqualTo(1.0));
      expect(result.fraction, greaterThanOrEqualTo(0.0));
    });
  });
}
