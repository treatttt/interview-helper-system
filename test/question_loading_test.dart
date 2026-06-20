import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:interview_helper_system/models/models.dart';
import 'package:interview_helper_system/screens/home_screen.dart';
import 'package:interview_helper_system/services/progress_service.dart';
import 'package:interview_helper_system/services/question_repository.dart';
import 'package:interview_helper_system/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── helpers ──────────────────────────────────────────────────────────────────

Map<String, dynamic> _questionJson({
  String id = 'q1',
  String text = 'Вопрос?',
  List<String> options = const ['A', 'B', 'C'],
  List<int> correctIndexes = const [0],
}) =>
    {'id': id, 'text': text, 'options': options, 'correctIndexes': correctIndexes};

Map<String, dynamic> _gradeJson({
  required List<Map<String, dynamic>> questions, String id = 'junior',
  String title = 'Junior',
  int order = 1,
}) =>
    {'id': id, 'title': title, 'order': order, 'questions': questions};

Map<String, dynamic> _trackJson({
  required List<Map<String, dynamic>> grades, String id = 'analytics',
  String title = 'Аналитика',
  int order = 1,
}) =>
    {'id': id, 'title': title, 'order': order, 'grades': grades};

String _bank(List<Map<String, dynamic>> tracks) =>
    json.encode({'tracks': tracks});

// Подменный репозиторий для виджет-тестов: либо отдаёт треки, либо падает.
class _FakeRepo implements QuestionRepository {
  _FakeRepo.data(this._tracks) : _fail = false;
  _FakeRepo.failure()
      : _tracks = const [],
        _fail = true;

  final List<Track> _tracks;
  final bool _fail;

  @override
  Future<List<Track>> loadTracks() async {
    if (_fail) throw const FormatException('boom');
    return _tracks;
  }
}

void main() {
  // ── 1. Правила валидности модели ───────────────────────────────────────────

  group('Question.isValid', () {
    Question q({
      String id = 'q1',
      String text = 'Вопрос?',
      List<String> options = const ['A', 'B', 'C'],
      List<int> correctIndexes = const [0],
    }) =>
        Question(
            id: id, text: text, options: options, correctIndexes: correctIndexes,);

    test('одиночный валидный вопрос → валиден', () {
      expect(q().isValid, isTrue);
    });

    test('множественный валидный вопрос → валиден', () {
      expect(q(correctIndexes: const [0, 2]).isValid, isTrue);
    });

    test('пустой текст → невалиден', () {
      expect(q(text: '   ').isValid, isFalse);
    });

    test('меньше двух вариантов → невалиден', () {
      expect(q(options: const ['A']).isValid, isFalse);
    });

    test('нет правильных ответов → невалиден', () {
      expect(q(correctIndexes: const []).isValid, isFalse);
    });

    test('индекс правильного ответа за границами (99) → невалиден', () {
      expect(
          q(options: const ['A', 'B'], correctIndexes: const [99]).isValid,
          isFalse,);
    });

    test('отрицательный индекс → невалиден', () {
      expect(q(correctIndexes: const [-1]).isValid, isFalse);
    });
  });

  // ── 2. Разбор и отсев в репозитории ────────────────────────────────────────

  group('JsonQuestionRepository.parseTracks', () {
    final repo = JsonQuestionRepository();

    test('нормальный банк: треки, грейды и вопросы читаются как есть', () {
      final raw = _bank([
        _trackJson(grades: [
          _gradeJson(questions: [
            _questionJson(),
            _questionJson(id: 'q2', correctIndexes: const [0, 1]),
          ],),
        ],),
      ]);
      final tracks = repo.parseTracks(raw);
      expect(tracks, hasLength(1));
      expect(tracks.single.grades.single.questions, hasLength(2));
    });

    test('битый JSON (пропущена запятая) → FormatException', () {
      const broken =
          '{ "tracks": [ { "id": "t1" "title": "Тема", "grades": [] } ] }';
      expect(() => repo.parseTracks(broken), throwsFormatException);
    });

    test('нет ключа tracks → FormatException', () {
      expect(() => repo.parseTracks('{"foo": 1}'), throwsFormatException);
    });

    test('вопрос с correctIndexes:[99] отсеивается, остальные остаются', () {
      final raw = _bank([
        _trackJson(grades: [
          _gradeJson(questions: [
            _questionJson(id: 'ok'),
            _questionJson(
                id: 'bad',
                options: const ['A', 'B'],
                correctIndexes: const [99],),
          ],),
        ],),
      ]);
      final tracks = repo.parseTracks(raw);
      expect(tracks.single.grades.single.questions, hasLength(1));
      expect(tracks.single.grades.single.questions.single.id, 'ok');
    });

    test('грейд, где все вопросы невалидны, остаётся в треке (пустой)', () {
      // Грейд с невалидными вопросами не выбрасывается — он просто пустой.
      // Выбрасывание пустых — ответственность UI, а не репозитория.
      final raw = _bank([
        _trackJson(grades: [
          _gradeJson(id: 'empty', questions: [
            _questionJson(correctIndexes: const []),
            _questionJson(options: const ['A']),
          ],),
          _gradeJson(id: 'good', questions: [_questionJson()]),
        ],),
      ]);
      final tracks = repo.parseTracks(raw);
      expect(tracks.single.grades, hasLength(2));
      expect(tracks.single.grades.first.questions, isEmpty);
      expect(tracks.single.grades.last.questions, hasLength(1));
    });

    test('все треки без вопросов → пустые грейды, но треки остаются', () {
      final raw = _bank([
        _trackJson(grades: [
          _gradeJson(questions: [_questionJson(correctIndexes: const [])]),
        ],),
      ]);
      final tracks = repo.parseTracks(raw);
      expect(tracks, hasLength(1));
      expect(tracks.single.grades.single.questions, isEmpty);
    });
  });

  // ── 3. Состояния экрана ────────────────────────────────────────────────────

  group('HomeScreen — состояния загрузки', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
    });

    Future<Widget> homeUnder(QuestionRepository repo) async {
      final progress = ProgressService();
      await progress.init();
      return MaterialApp(
        theme: buildLightTheme(),
        home: HomeScreen(
          repository: repo,
          progress: progress,
        ),
      );
    }

    testWidgets('первый кадр — индикатор загрузки', (tester) async {
      await tester.pumpWidget(await homeUnder(_FakeRepo.data(const [])));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.pumpAndSettle();
    });

    testWidgets('загрузка падает → экран ошибки, приложение не падает',
        (tester) async {
      await tester.pumpWidget(await homeUnder(_FakeRepo.failure()));
      await tester.pumpAndSettle();
      expect(find.text('Не удалось загрузить вопросы'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('пустой список треков → дашборд рендерится, список треков пуст',
        (tester) async {
      await tester.pumpWidget(await homeUnder(_FakeRepo.data(const [])));
      await tester.pumpAndSettle();
      // Дашборд отображает секцию направлений и CTA даже при пустом списке.
      expect(find.text('Все направления'), findsOneWidget);
      expect(find.text('Начать тренировку'), findsOneWidget);
    },);

    testWidgets('есть треки → список отображается', (tester) async {
      final tracks = [
        const Track(
          id: 'analytics',
          title: 'Аналитика',
          order: 1,
          grades: [
            Grade(
              id: 'junior',
              title: 'Junior',
              order: 1,
              questions: [
                Question(
                  id: 'q1',
                  text: 'Вопрос?',
                  options: ['A', 'B'],
                  correctIndexes: [0],
                ),
              ],
            ),
          ],
        ),
      ];

      await tester.pumpWidget(await homeUnder(_FakeRepo.data(tracks)));
      await tester.pumpAndSettle();
      expect(find.text('Аналитика'), findsOneWidget);
    });
  });
}
