import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:interview_helper_system/theme.dart';
import 'package:interview_helper_system/models/models.dart';
import 'package:interview_helper_system/services/question_repository.dart';
import 'package:interview_helper_system/services/progress_service.dart';
import 'package:interview_helper_system/services/theme_service.dart';
import 'package:interview_helper_system/screens/home_screen.dart';

// ── helpers ──────────────────────────────────────────────────────────────────

Question _q({
  String id = 'q1',
  String text = 'Вопрос?',
  List<String> options = const ['A', 'B', 'C'],
  List<int> correctIndexes = const [0],
}) =>
    Question(
        id: id, text: text, options: options, correctIndexes: correctIndexes);

Map<String, dynamic> _questionJson({
  String id = 'q1',
  String text = 'Вопрос?',
  List<String> options = const ['A', 'B', 'C'],
  List<int> correctIndexes = const [0],
}) =>
    {'id': id, 'text': text, 'options': options, 'correctIndexes': correctIndexes};

Map<String, dynamic> _topicJson({
  String id = 't1',
  String title = 'Тема',
  required List<Map<String, dynamic>> questions,
}) =>
    {'id': id, 'title': title, 'questions': questions};

String _bank(List<Map<String, dynamic>> topics) =>
    json.encode({'topics': topics});

// Подменный репозиторий для виджет-тестов: либо отдаёт темы, либо падает.
class _FakeRepo implements QuestionRepository {
  _FakeRepo.data(this._topics) : _fail = false;
  _FakeRepo.failure()
      : _topics = const [],
        _fail = true;

  final List<Topic> _topics;
  final bool _fail;

  @override
  Future<List<Topic>> loadTopics() async {
    if (_fail) throw const FormatException('boom');
    return _topics;
  }
}

void main() {
  // ── 1. Правила валидности модели ───────────────────────────────────────────

  group('Question.isValid', () {
    test('одиночный валидный вопрос → валиден', () {
      expect(_q(correctIndexes: const [0]).isValid, isTrue);
    });

    test('множественный валидный вопрос → валиден', () {
      expect(_q(correctIndexes: const [0, 2]).isValid, isTrue);
    });

    test('пустой текст → невалиден', () {
      expect(_q(text: '   ').isValid, isFalse);
    });

    test('меньше двух вариантов → невалиден', () {
      expect(_q(options: const ['A']).isValid, isFalse);
    });

    test('нет правильных ответов → невалиден', () {
      expect(_q(correctIndexes: const []).isValid, isFalse);
    });

    test('индекс правильного ответа за границами (99) → невалиден', () {
      expect(
          _q(options: const ['A', 'B'], correctIndexes: const [99]).isValid,
          isFalse);
    });

    test('отрицательный индекс → невалиден', () {
      expect(_q(correctIndexes: const [-1]).isValid, isFalse);
    });
  });

  // ── 2. Разбор и отсев в репозитории ────────────────────────────────────────

  group('JsonQuestionRepository.parseTopics', () {
    final repo = JsonQuestionRepository();

    test('нормальный банк: темы и вопросы читаются как есть', () {
      final raw = _bank([
        _topicJson(questions: [
          _questionJson(id: 'q1'),
          _questionJson(id: 'q2', correctIndexes: const [0, 1]),
        ]),
      ]);
      final topics = repo.parseTopics(raw);
      expect(topics, hasLength(1));
      expect(topics.single.questions, hasLength(2));
    });

    test('битый JSON (пропущена запятая) → FormatException', () {
      const broken =
          '{ "topics": [ { "id": "t1" "title": "Тема", "questions": [] } ] }';
      expect(() => repo.parseTopics(broken), throwsFormatException);
    });

    test('нет ключа topics → FormatException', () {
      expect(() => repo.parseTopics('{"foo": 1}'), throwsFormatException);
    });

    test('вопрос с correctIndexes:[99] отсеивается, остальные остаются', () {
      final raw = _bank([
        _topicJson(questions: [
          _questionJson(id: 'ok', correctIndexes: const [0]),
          _questionJson(
              id: 'bad', options: const ['A', 'B'], correctIndexes: const [99]),
        ]),
      ]);
      final topics = repo.parseTopics(raw);
      expect(topics.single.questions, hasLength(1));
      expect(topics.single.questions.single.id, 'ok');
    });

    test('тема, где все вопросы невалидны, не попадает в результат', () {
      final raw = _bank([
        _topicJson(id: 'empty', questions: [
          _questionJson(correctIndexes: const []), // нет правильного ответа
          _questionJson(options: const ['A']), // мало вариантов
        ]),
        _topicJson(id: 'good', questions: [_questionJson()]),
      ]);
      final topics = repo.parseTopics(raw);
      expect(topics, hasLength(1));
      expect(topics.single.id, 'good');
    });

    test('все темы выпали → пустой список', () {
      final raw = _bank([
        _topicJson(questions: [_questionJson(correctIndexes: const [])]),
      ]);
      expect(repo.parseTopics(raw), isEmpty);
    });
  });

  // ── 3. Состояния экрана ────────────────────────────────────────────────────

  group('HomeScreen — состояния загрузки', () {
    setUp(() async {
      // Пустое хранилище: онбординг не пройден, прогресс нулевой, тема system.
      SharedPreferences.setMockInitialValues({});
    });

    // Готовит инициализированные сервисы и возвращает MaterialApp с темой
    // (без неё extension<AppSemanticColors>() вернёт null и экран упадёт на `!`).
    Future<Widget> homeUnder(QuestionRepository repo) async {
      final progress = ProgressService();
      await progress.init();
      final themeService = ThemeService();
      await themeService.init();
      return MaterialApp(
        theme: buildLightTheme(),
        home: HomeScreen(
          repository: repo,
          progress: progress,
          themeService: themeService,
        ),
      );
    }

    testWidgets('первый кадр — индикатор загрузки', (tester) async {
      await tester.pumpWidget(await homeUnder(_FakeRepo.data(const [])));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.pumpAndSettle(); // дать загрузке завершиться, чтобы тест не висел
    });

    testWidgets('загрузка падает → экран ошибки, приложение не падает',
            (tester) async {
          await tester.pumpWidget(await homeUnder(_FakeRepo.failure()));
          await tester.pumpAndSettle();
          expect(find.text('Не удалось загрузить вопросы'), findsOneWidget);
          expect(tester.takeException(), isNull); // исключение поймано, не всплыло
        });

    testWidgets('пустой список тем → «Вопросов пока нет»', (tester) async {
      await tester.pumpWidget(await homeUnder(_FakeRepo.data(const [])));
      await tester.pumpAndSettle();
      expect(find.text('Вопросов пока нет'), findsOneWidget);
    });

    testWidgets('есть темы → список отображается', (tester) async {
      final topics = [
        const Topic(
          id: 't1',
          title: 'Алгоритмы',
          questions: [
            Question(
              id: 'q1',
              text: 'Вопрос?',
              options: ['A', 'B'],
              correctIndexes: [0],
            ),
          ],
        ),
      ];

      await tester.pumpWidget(await homeUnder(_FakeRepo.data(topics)));
      await tester.pumpAndSettle();
      expect(find.text('Алгоритмы'), findsOneWidget);
    });
  });
}