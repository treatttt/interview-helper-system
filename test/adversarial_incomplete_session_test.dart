import 'package:flutter_test/flutter_test.dart';
import 'package:interview_helper_system/models/incomplete_session.dart';

void main() {
  // ─── fromJson — обязательные поля отсутствуют → бросаем ───────────────────
  group('IncompleteSession.fromJson — пропущенный обязательный ключ → исключение', () {
    test('gradeKey отсутствует → null-check исключение', () {
      expect(
        () => IncompleteSession.fromJson({
          // 'gradeKey': 'k',   ← намеренно пропущен
          'questionIds': ['q1'],
          'currentIndex': 0,
          'answeredData': <Object?>[],
        }),
        throwsA(isA<TypeError>()),
      );
    });

    test('questionIds отсутствует → null-check исключение', () {
      expect(
        () => IncompleteSession.fromJson({
          'gradeKey': 'k',
          // 'questionIds': [],  ← намеренно пропущен
          'currentIndex': 0,
          'answeredData': <Object?>[],
        }),
        throwsA(isA<TypeError>()),
      );
    });

    test('currentIndex отсутствует → null-check исключение', () {
      expect(
        () => IncompleteSession.fromJson({
          'gradeKey': 'k',
          'questionIds': ['q1'],
          // 'currentIndex': 0,  ← намеренно пропущен
          'answeredData': <Object?>[],
        }),
        throwsA(isA<TypeError>()),
      );
    });

    test('answeredData отсутствует → null-check исключение', () {
      expect(
        () => IncompleteSession.fromJson({
          'gradeKey': 'k',
          'questionIds': ['q1'],
          'currentIndex': 0,
          // 'answeredData': [],  ← намеренно пропущен
        }),
        throwsA(isA<TypeError>()),
      );
    });
  });

  // ─── fromJson — AnsweredItemData — пропущенные ключи ──────────────────────
  group('AnsweredItemData.fromJson — пропущенный ключ внутри answeredData', () {
    test('id отсутствует в элементе answeredData → null-check исключение', () {
      expect(
        () => IncompleteSession.fromJson({
          'gradeKey': 'k',
          'questionIds': ['q1'],
          'currentIndex': 0,
          'answeredData': [
            {
              // 'id': 'q1',  ← намеренно пропущен
              'selected': [0],
              'outcome': 'correct',
            },
          ],
        }),
        throwsA(isA<TypeError>()),
      );
    });

    test('outcome отсутствует в элементе answeredData → null-check исключение', () {
      expect(
        () => IncompleteSession.fromJson({
          'gradeKey': 'k',
          'questionIds': ['q1'],
          'currentIndex': 0,
          'answeredData': [
            {
              'id': 'q1',
              'selected': [0],
              // 'outcome': 'correct',  ← намеренно пропущен
            },
          ],
        }),
        throwsA(isA<TypeError>()),
      );
    });
  });

  // ─── fromJson — лишние ключи не роняют парсинг ────────────────────────────
  group('fromJson — неизвестные ключи игнорируются', () {
    test('лишние ключи на верхнем уровне → нет исключений, данные корректны', () {
      final s = IncompleteSession.fromJson({
        'gradeKey': 'analytics_junior',
        'questionIds': ['q1', 'q2'],
        'currentIndex': 1,
        'answeredData': <Object?>[],
        'unknownField': 'shouldBeIgnored',
        'anotherExtra': 42,
      });
      expect(s.gradeKey, 'analytics_junior');
      expect(s.questionIds, ['q1', 'q2']);
      expect(s.currentIndex, 1);
    });

    test('лишние ключи внутри answeredData → нет исключений', () {
      final s = IncompleteSession.fromJson({
        'gradeKey': 'k',
        'questionIds': ['q1'],
        'currentIndex': 0,
        'answeredData': [
          {
            'id': 'q1',
            'selected': [0],
            'outcome': 'correct',
            'extra': 'ignored',
          },
        ],
      });
      expect(s.answeredData.first.outcome, 'correct');
    });
  });

  // ─── fromJson — граничные значения currentIndex ────────────────────────────
  group('fromJson — currentIndex не валидируется', () {
    test('currentIndex отрицательный → сохраняется как есть', () {
      // FIXME: выявляет баг — fromJson не проверяет, что currentIndex >= 0.
      // SessionController.resume с таким индексом даст RangeError при обращении к current.
      final s = IncompleteSession.fromJson({
        'gradeKey': 'k',
        'questionIds': ['q1'],
        'currentIndex': -5,
        'answeredData': <Object?>[],
      });
      expect(s.currentIndex, -5);
    });

    test('currentIndex больше длины questionIds → сохраняется как есть', () {
      // FIXME: выявляет баг — fromJson не проверяет currentIndex < questionIds.length.
      // grades_screen вызывает fromJson без try/catch; если данные в prefs повреждены,
      // это приведёт к RangeError при запуске сессии.
      final s = IncompleteSession.fromJson({
        'gradeKey': 'k',
        'questionIds': ['q1', 'q2'],
        'currentIndex': 999,
        'answeredData': <Object?>[],
      });
      expect(s.currentIndex, 999);
    });

    test('answeredData длиннее questionIds → сохраняется как есть, нет краша', () {
      final s = IncompleteSession.fromJson({
        'gradeKey': 'k',
        'questionIds': ['q1'],
        'currentIndex': 0,
        'answeredData': [
          {'id': 'q1', 'selected': [0], 'outcome': 'correct'},
          {'id': 'q2', 'selected': [1], 'outcome': 'wrong'},
          {'id': 'q3', 'selected': [0], 'outcome': 'partial'},
        ],
      });
      expect(s.answeredData.length, 3);
      expect(s.questionIds.length, 1);
    });
  });

  // ─── fromJson — неизвестная строка outcome хранится как есть ──────────────
  group('AnsweredItemData — outcome строка не валидируется в fromJson', () {
    test('неизвестный outcome ("legendary") — хранится как есть, нет краша', () {
      // outcome — просто String в AnsweredItemData; перевод в enum происходит
      // в SessionController.resume. Этот тест фиксирует текущее поведение:
      // fromJson не бросает на неизвестной строке.
      final s = IncompleteSession.fromJson({
        'gradeKey': 'k',
        'questionIds': ['q1'],
        'currentIndex': 0,
        'answeredData': [
          {'id': 'q1', 'selected': [0], 'outcome': 'legendary'},
        ],
      });
      expect(s.answeredData.first.outcome, 'legendary');
    });
  });

  // ─── round-trip — topicTitle опциональна ──────────────────────────────────
  group('toJson / fromJson — topicTitle', () {
    test('topicTitle задана — переживает round-trip', () {
      const orig = IncompleteSession(
        gradeKey: 'analytics_junior',
        questionIds: ['q1'],
        currentIndex: 0,
        answeredData: [],
        topicTitle: 'SQL',
      );
      final restored = IncompleteSession.fromJson(orig.toJson());
      expect(restored.topicTitle, 'SQL');
    });

    test('topicTitle null — ключ не попадает в JSON, fromJson возвращает null', () {
      const orig = IncompleteSession(
        gradeKey: 'k',
        questionIds: [],
        currentIndex: 0,
        answeredData: [],
      );
      final json = orig.toJson();
      expect(json.containsKey('topicTitle'), isFalse);
      final restored = IncompleteSession.fromJson(json);
      expect(restored.topicTitle, isNull);
    });
  });
}
