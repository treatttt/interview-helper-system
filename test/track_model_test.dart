import 'package:flutter_test/flutter_test.dart';
import 'package:interview_helper_system/models/models.dart';

void main() {
  // === Track.fromJson (models.dart, строки 85-92) ==========================
  group('Track.fromJson', () {
    test('строит трек с грейдами и вопросами из JSON', () {
      final track = Track.fromJson({
        'id': 't1',
        'title': 'Аналитика',
        'description': 'Сбор требований',
        'order': 2,
        'grades': [
          {
            'id': 'g1',
            'title': 'Junior',
            'order': 0,
            'questions': [
              {
                'id': 'q1',
                'text': 'Вопрос',
                'options': ['A', 'B'],
                'correctIndexes': [0],
              },
            ],
          },
        ],
      });

      expect(track.id, 't1');
      expect(track.title, 'Аналитика');
      expect(track.description, 'Сбор требований');
      expect(track.order, 2);
      expect(track.grades, hasLength(1));
      expect(track.grades.single.questions.single.id, 'q1');
    });

    test('description может отсутствовать (nullable)', () {
      final track = Track.fromJson({
        'id': 't1',
        'title': 'Аналитика',
        'order': 0,
        'grades': <Map<String, dynamic>>[],
      });

      expect(track.description, isNull);
      expect(track.grades, isEmpty);
    });

    test('category читается из JSON', () {
      final track = Track.fromJson({
        'id': 'go',
        'title': 'Go',
        'order': 4,
        'category': 'language',
        'grades': <Map<String, dynamic>>[],
      });

      expect(track.category, 'language');
    });

    test('трек без category парсится без ошибки (обратная совместимость)', () {
      final track = Track.fromJson({
        'id': 'analytics',
        'title': 'Аналитика',
        'order': 1,
        'grades': <Map<String, dynamic>>[],
      });

      expect(track.category, isNull);
    });

    test('трек с category != language не фильтруется', () {
      final track = Track.fromJson({
        'id': 'custom',
        'title': 'Кастом',
        'order': 99,
        'category': 'other',
        'grades': <Map<String, dynamic>>[],
      });

      expect(track.category, 'other');
    });
  });
}
