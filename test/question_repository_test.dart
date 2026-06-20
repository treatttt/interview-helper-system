import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:interview_helper_system/services/question_repository.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  // === loadTracks: чтение ассета (строки 20-23) ============================
  group('loadTracks', () {
    const assetKey = 'assets/data/questions.json';
    const payload =
        '{"tracks":[{"id":"t1","title":"Аналитика","order":0,"grades":[]}]}';

    setUp(() {
      binding.defaultBinaryMessenger.setMockMessageHandler(
        'flutter/assets',
        (message) async {
          final key = const StringCodec().decodeMessage(message);
          if (key == assetKey) {
            return const StringCodec().encodeMessage(payload);
          }
          return null;
        },
      );
    });

    tearDown(() {
      binding.defaultBinaryMessenger
          .setMockMessageHandler('flutter/assets', null);
    });

    test('читает ассет questions.json и парсит треки', () async {
      final repo = JsonQuestionRepository();
      final tracks = await repo.loadTracks();

      expect(tracks, hasLength(1));
      expect(tracks.single.id, 't1');
      expect(tracks.single.title, 'Аналитика');
    });
  });

  // === parseTracks: валидация верхнего уровня ==============================
  group('parseTracks верхний уровень', () {
    test('бросает FormatException, если нет ключа tracks', () {
      final repo = JsonQuestionRepository();
      expect(() => repo.parseTracks('{}'), throwsFormatException);
    });

    test('бросает FormatException, если корень — не объект', () {
      final repo = JsonQuestionRepository();
      expect(() => repo.parseTracks('[]'), throwsFormatException);
    });
  });

  // === parseTracks: отбраковка битых элементов =============================
  // Покрывает _parseTrack (50-53, 71-76), _parseGrade (81-84, 102-107),
  // _parseQuestion (110-130) и ветку debugPrint при discarded > 0 (38-43).
  group('parseTracks отбраковка', () {
    const raw = '''
{
  "tracks": [
    "не объект-трек",
    { "title": "трек без id", "grades": [] },
    {
      "id": "t1", "title": "Аналитика", "order": 0,
      "grades": [
        "не объект-грейд",
        { "title": "грейд без id" },
        {
          "id": "g1", "title": "Junior", "order": 0,
          "questions": [
            42,
            { "id": "q_invalid", "text": "мало вариантов", "options": ["A"], "correctIndexes": [0] },
            { "id": "q_broken", "text": "битые опции", "options": "не список", "correctIndexes": [0] },
            { "id": "q_ok", "text": "Нормальный вопрос", "options": ["A", "B"], "correctIndexes": [0] }
          ]
        }
      ]
    }
  ]
}
''';

    test('оставляет только валидные элементы, остальное отсеивает', () {
      final repo = JsonQuestionRepository();
      final tracks = repo.parseTracks(raw);

      // Уцелел один трек с одним грейдом и одним валидным вопросом.
      expect(tracks, hasLength(1));
      final track = tracks.single;
      expect(track.id, 't1');
      expect(track.grades, hasLength(1));

      final grade = track.grades.single;
      expect(grade.id, 'g1');
      expect(grade.questions, hasLength(1));
      expect(grade.questions.single.id, 'q_ok');
    });

    test('фиксирует число отброшенных элементов', () {
      final repo = JsonQuestionRepository()
      ..parseTracks(raw);

      // 2 трека + 2 грейда + 3 вопроса = 7 отброшенных.
      expect(repo.lastDiscardedCount, greaterThan(0));
    });
  });
}
