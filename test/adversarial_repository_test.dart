import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:interview_helper_system/services/question_repository.dart';

String enc(Object data) => json.encode(data);

void main() {
  late JsonQuestionRepository repo;

  setUp(() => repo = JsonQuestionRepository());

  // ─── пустой массив треков ──────────────────────────────────────────────────
  group('пустой список треков — нет FormatException', () {
    test('пустой массив tracks → пустой список треков, нет краша', () {
      final raw = enc({'tracks': <Object?>[]});
      final tracks = repo.parseTracks(raw);
      expect(tracks, isEmpty);
      expect(repo.lastDiscardedCount, 0);
    });
  });

  // ─── трек без ключа grades ─────────────────────────────────────────────────
  group('трек без ключа grades — парсится с пустым списком грейдов', () {
    test('трек без grades → трек добавлен, grades пустые, ничего не отброшено', () {
      final raw = enc({
        'tracks': [
          {'id': 'dev', 'title': 'Dev'}, // нет 'grades'
        ],
      });
      final tracks = repo.parseTracks(raw);
      expect(tracks.length, 1);
      expect(tracks.first.id, 'dev');
      expect(tracks.first.grades, isEmpty);
    });

    test('трек с grades не являющимся списком → grades игнорируются, трек добавлен', () {
      final raw = enc({
        'tracks': [
          {'id': 'dev', 'title': 'Dev', 'grades': 'broken'},
        ],
      });
      final tracks = repo.parseTracks(raw);
      expect(tracks.length, 1);
      expect(tracks.first.grades, isEmpty);
    });
  });

  // ─── грейд без ключа questions ─────────────────────────────────────────────
  group('грейд без ключа questions — парсится с пустым списком вопросов', () {
    test('грейд без questions → грейд добавлен, questions пустые', () {
      final raw = enc({
        'tracks': [
          {
            'id': 'dev',
            'title': 'Dev',
            'grades': [
              {'id': 'junior', 'title': 'Junior'}, // нет 'questions'
            ],
          },
        ],
      });
      final tracks = repo.parseTracks(raw);
      expect(tracks.first.grades.first.questions, isEmpty);
    });

    test('грейд с questions не являющимся списком → questions игнорируются', () {
      final raw = enc({
        'tracks': [
          {
            'id': 'dev',
            'title': 'Dev',
            'grades': [
              {'id': 'junior', 'title': 'Junior', 'questions': 'broken'},
            ],
          },
        ],
      });
      final tracks = repo.parseTracks(raw);
      expect(tracks.first.grades.first.questions, isEmpty);
    });
  });

  // ─── correctIndexes выходят за bounds ─────────────────────────────────────
  group('correctIndexes — индекс вне диапазона options → вопрос отброшен', () {
    test('correctIndexes = [5] при 2 вариантах → isValid=false, вопрос отброшен', () {
      final raw = enc({
        'tracks': [
          {
            'id': 'dev',
            'title': 'Dev',
            'grades': [
              {
                'id': 'junior',
                'title': 'Junior',
                'questions': [
                  {
                    'id': 'q1',
                    'text': 'Q?',
                    'options': ['A', 'B'],
                    'correctIndexes': [5], // 5 >= options.length(2)
                  },
                ],
              },
            ],
          },
        ],
      });
      final tracks = repo.parseTracks(raw);
      expect(tracks.first.grades.first.questions, isEmpty);
      expect(repo.lastDiscardedCount, 1);
    });

    test('correctIndexes содержит -1 → isValid=false, вопрос отброшен', () {
      final raw = enc({
        'tracks': [
          {
            'id': 'dev',
            'title': 'Dev',
            'grades': [
              {
                'id': 'junior',
                'title': 'Junior',
                'questions': [
                  {
                    'id': 'q1',
                    'text': 'Q?',
                    'options': ['A', 'B'],
                    'correctIndexes': [-1],
                  },
                ],
              },
            ],
          },
        ],
      });
      final tracks = repo.parseTracks(raw);
      expect(tracks.first.grades.first.questions, isEmpty);
      expect(repo.lastDiscardedCount, 1);
    });
  });

  // ─── дублирующиеся id вопросов ─────────────────────────────────────────────
  group('дублирующиеся id вопросов — оба попадают в список без дедупликации', () {
    test('два вопроса с id="q1" → оба остаются, дедупликации нет', () {
      // Документирует текущее поведение: репозиторий не дедуплицирует по id.
      final raw = enc({
        'tracks': [
          {
            'id': 'dev',
            'title': 'Dev',
            'grades': [
              {
                'id': 'junior',
                'title': 'Junior',
                'questions': [
                  {
                    'id': 'q1',
                    'text': 'First',
                    'options': ['A', 'B'],
                    'correctIndexes': [0],
                  },
                  {
                    'id': 'q1', // дубль
                    'text': 'Second',
                    'options': ['A', 'B'],
                    'correctIndexes': [1],
                  },
                ],
              },
            ],
          },
        ],
      });
      final tracks = repo.parseTracks(raw);
      final questions = tracks.first.grades.first.questions;
      expect(questions.length, 2);
      expect(
        questions.map((q) => q.text).toList(),
        containsAll(['First', 'Second']),
      );
      expect(repo.lastDiscardedCount, 0);
    });
  });

  // ─── вопрос без id ────────────────────────────────────────────────────────
  group('вопрос без поля id → отбрасывается, остальные сохраняются', () {
    test('вопрос без id — отброшен; вопрос с id — добавлен', () {
      final raw = enc({
        'tracks': [
          {
            'id': 'dev',
            'title': 'Dev',
            'grades': [
              {
                'id': 'junior',
                'title': 'Junior',
                'questions': [
                  {
                    // нет 'id'
                    'text': 'No ID question',
                    'options': ['A', 'B'],
                    'correctIndexes': [0],
                  },
                  {
                    'id': 'q_ok',
                    'text': 'Valid',
                    'options': ['A', 'B'],
                    'correctIndexes': [0],
                  },
                ],
              },
            ],
          },
        ],
      });
      final tracks = repo.parseTracks(raw);
      final questions = tracks.first.grades.first.questions;
      expect(questions.length, 1);
      expect(questions.first.id, 'q_ok');
      expect(repo.lastDiscardedCount, 1);
    });
  });

  // ─── пустые correctIndexes → isValid=false ─────────────────────────────────
  group('пустые correctIndexes — вопрос невалиден', () {
    test('correctIndexes = [] → isValid=false, вопрос отброшен', () {
      final raw = enc({
        'tracks': [
          {
            'id': 'dev',
            'title': 'Dev',
            'grades': [
              {
                'id': 'junior',
                'title': 'Junior',
                'questions': [
                  {
                    'id': 'q1',
                    'text': 'Q?',
                    'options': ['A', 'B'],
                    'correctIndexes': <int>[],
                  },
                ],
              },
            ],
          },
        ],
      });
      final tracks = repo.parseTracks(raw);
      expect(tracks.first.grades.first.questions, isEmpty);
      expect(repo.lastDiscardedCount, 1);
    });
  });
}
