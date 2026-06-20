import 'package:flutter_test/flutter_test.dart';
import 'package:interview_helper_system/models/incomplete_session.dart';

void main() {
  // === IncompleteSession.fromJson + AnsweredItemData.fromJson (17-18, 45-49)
  test('fromJson разбирает сессию вместе с ответами', () {
    final session = IncompleteSession.fromJson({
      'gradeKey': 't1_g1',
      'questionIds': ['q1', 'q2'],
      'currentIndex': 1,
      'answeredData': [
        {
          'id': 'q1',
          'selected': [0, 2],
          'outcome': 'correct',
        },
      ],
    });

    expect(session.gradeKey, 't1_g1');
    expect(session.questionIds, ['q1', 'q2']);
    expect(session.currentIndex, 1);
    expect(session.answeredData, hasLength(1));

    final item = session.answeredData.single;
    expect(item.id, 'q1');
    expect(item.selected, [0, 2]);
    expect(item.outcome, 'correct');
  });

  // === Round-trip: toJson → fromJson сохраняет данные ======================
  test('round-trip toJson → fromJson сохраняет все поля', () {
    const original = IncompleteSession(
      gradeKey: 't1_g1',
      questionIds: ['q1', 'q2', 'q3'],
      currentIndex: 2,
      answeredData: [
        AnsweredItemData(id: 'q1', selected: [1], outcome: 'partial'),
        AnsweredItemData(id: 'q2', selected: [], outcome: 'wrong'),
      ],
    );

    final restored = IncompleteSession.fromJson(original.toJson());

    expect(restored.gradeKey, original.gradeKey);
    expect(restored.questionIds, original.questionIds);
    expect(restored.currentIndex, original.currentIndex);
    expect(restored.answeredData, hasLength(2));
    expect(restored.answeredData[0].id, 'q1');
    expect(restored.answeredData[0].selected, [1]);
    expect(restored.answeredData[0].outcome, 'partial');
    expect(restored.answeredData[1].selected, isEmpty);
  });
}
