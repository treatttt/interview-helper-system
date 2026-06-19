import 'package:flutter_test/flutter_test.dart';
import 'package:interview_helper_system/controllers/session_controller.dart';
import 'package:interview_helper_system/models/models.dart';
import 'package:interview_helper_system/services/progress_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Минимальный вопрос для тестов — одиночный выбор.
Question fakeQ(String id) => Question(
      id: id,
      text: 'Вопрос $id',
      options: ['А', 'Б'],
      correctIndexes: const [0],
    );

SessionResult result({
  required Set<String> correctIds,
  int wrong = 0,
}) =>
    SessionResult(
      correct: correctIds.length,
      partial: 0,
      wrong: wrong,
      points: correctIds.length,
      maxPoints: correctIds.length + wrong,
      answers: const [],
      correctIds: correctIds,
    );

Future<ProgressService> freshService() async {
  SharedPreferences.setMockInitialValues({});
  final p = ProgressService();
  await p.init();
  return p;
}

void main() {
  group('Формирование сессии «Работа над ошибками»', () {
    test('в сессию попадают только неверные и частично верные', () {
      final answers = [
        AnsweredQuestion(question: fakeQ('q1'), selected: {0}, outcome: AnswerOutcome.correct),
        AnsweredQuestion(question: fakeQ('q2'), selected: {1}, outcome: AnswerOutcome.wrong),
        AnsweredQuestion(question: fakeQ('q3'), selected: {0, 1}, outcome: AnswerOutcome.partial),
        AnsweredQuestion(question: fakeQ('q4'), selected: {0}, outcome: AnswerOutcome.correct),
      ];

      final errorQuestions = answers
          .where((a) => a.outcome != AnswerOutcome.correct)
          .map((a) => a.question)
          .toList();

      expect(errorQuestions.map((q) => q.id), containsAllInOrder(['q2', 'q3']));
      expect(errorQuestions.length, 2);
    });

    test('если все верно — список ошибочных вопросов пустой', () {
      final answers = [
        AnsweredQuestion(question: fakeQ('q1'), selected: {0}, outcome: AnswerOutcome.correct),
        AnsweredQuestion(question: fakeQ('q2'), selected: {0}, outcome: AnswerOutcome.correct),
      ];

      final errorQuestions = answers
          .where((a) => a.outcome != AnswerOutcome.correct)
          .map((a) => a.question)
          .toList();

      expect(errorQuestions, isEmpty);
    });

    test('partial засчитывается как ошибка и попадает в пул', () {
      final answers = [
        AnsweredQuestion(question: fakeQ('q1'), selected: {0}, outcome: AnswerOutcome.partial),
      ];

      final errorQuestions = answers
          .where((a) => a.outcome != AnswerOutcome.correct)
          .map((a) => a.question)
          .toList();

      expect(errorQuestions.map((q) => q.id), contains('q1'));
    });
  });

  group('Прогресс в режиме «Работа над ошибками»', () {
    test('верный ответ в работе над ошибками засчитывается в общий прогресс', () async {
      final p = await freshService();

      // Основная сессия: q1 верно, q2 неверно.
      await p.recordSession('track_junior', result(correctIds: {'q1'}, wrong: 1));
      expect(p.gradeDone('track', 'junior'), 1);

      // Работа над ошибками: q2 теперь отвечен верно.
      await p.recordSession('track_junior', result(correctIds: {'q2'}));
      expect(p.gradeDone('track', 'junior'), 2); // q1 + q2
      expect(p.masteredIds('track', 'junior'), containsAll(['q1', 'q2']));
    });

    test('прогресс НЕ сбрасывается при работе над ошибками', () async {
      final p = await freshService();

      await p.recordSession('track_junior', result(correctIds: {'q1', 'q2', 'q3'}));
      expect(p.gradeDone('track', 'junior'), 3);

      // Сессия ошибок: q4 снова неверно — correctIds пустой.
      await p.recordSession('track_junior', result(correctIds: const {}, wrong: 1));
      expect(p.gradeDone('track', 'junior'), 3); // не сбросилось
    });

    test('повторный верный ответ на уже освоенный вопрос не меняет прогресс', () async {
      final p = await freshService();
      await p.recordSession('track_junior', result(correctIds: {'q1'}));
      final xpBefore = p.xp;

      // q1 уже освоен — повторный верный не даёт XP и не дублирует ID.
      await p.recordSession('track_junior', result(correctIds: {'q1'}));
      expect(p.xp, xpBefore);
      expect(p.masteredIds('track', 'junior').length, 1);
    });
  });

  group('Сброс прогресса грейда (grades_screen — п.4, поведение не должно ломаться)', () {
    test('resetGrade очищает освоенные вопросы', () async {
      final p = await freshService();
      await p.recordSession('t1_junior', result(correctIds: {'q1', 'q2', 'q3'}));
      expect(p.gradeDone('t1', 'junior'), 3);

      await p.resetGrade('t1', 'junior');
      expect(p.gradeDone('t1', 'junior'), 0);
      expect(p.masteredIds('t1', 'junior'), isEmpty);
    });

    test('resetGrade очищает незавершённую сессию этого грейда', () async {
      final p = await freshService();
      await p.saveIncompleteSession({
        'gradeKey': 't1_junior',
        'questionIds': ['q1', 'q2'],
        'currentIndex': 1,
        'answeredData': [],
      });
      expect(p.loadIncompleteSession('t1_junior'), isNotNull);

      await p.resetGrade('t1', 'junior');
      expect(p.loadIncompleteSession('t1_junior'), isNull);
    });

    test('resetGrade не трогает прогресс других грейдов', () async {
      final p = await freshService();
      await p.recordSession('t1_junior', result(correctIds: {'q1', 'q2'}));
      await p.recordSession('t1_middle', result(correctIds: {'q3'}));

      await p.resetGrade('t1', 'junior');
      expect(p.gradeDone('t1', 'junior'), 0);
      expect(p.gradeDone('t1', 'middle'), 1); // middle не затронут
    });
  });
}
