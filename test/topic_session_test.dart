import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:interview_helper_system/models/incomplete_session.dart';
import 'package:interview_helper_system/models/models.dart';
import 'package:interview_helper_system/screens/session_screen.dart';
import 'package:interview_helper_system/screens/topic_session.dart';
import 'package:interview_helper_system/services/progress_service.dart';
import 'package:interview_helper_system/theme.dart';
import 'package:mocktail/mocktail.dart';

// --- Test double -----------------------------------------------------------
class MockProgressService extends Mock implements ProgressService {}

// --- Builders --------------------------------------------------------------
Question _q(String id, {String? topic, String text = 't'}) => Question(
      id: id,
      text: text,
      options: const ['A', 'B'],
      correctIndexes: const [0],
      topic: topic,
    );

Grade _grade({
  required String id,
  required String title,
  int order = 0,
  List<Question> questions = const [],
}) =>
    Grade(id: id, title: title, order: order, questions: questions);

Track _track({
  required String id,
  required String title,
  int order = 0,
  List<Grade> grades = const [],
}) =>
    Track(id: id, title: title, order: order, grades: grades);

void main() {
  setUpAll(() {
    registerFallbackValue(<String, Set<String>>{});
  });

  // ===========================================================================
  // TopicProgress — производные значения
  // ===========================================================================
  group('TopicProgress', () {
    test('fraction = 0, когда вопросов нет (деления на ноль нет)', () {
      const tp = TopicProgress(title: 'SQL', total: 0, mastered: 0);
      expect(tp.fraction, 0.0);
    });

    test('fraction = освоено / всего', () {
      const tp = TopicProgress(title: 'SQL', total: 4, mastered: 1);
      expect(tp.fraction, closeTo(0.25, 1e-9));
    });

    test('allMastered = false при пустой теме (total == 0)', () {
      const tp = TopicProgress(title: 'SQL', total: 0, mastered: 0);
      expect(tp.allMastered, isFalse);
    });

    test('allMastered = true, когда освоены все', () {
      const tp = TopicProgress(title: 'SQL', total: 3, mastered: 3);
      expect(tp.allMastered, isTrue);
    });

    test('allMastered = false, пока освоены не все', () {
      const tp = TopicProgress(title: 'SQL', total: 3, mastered: 2);
      expect(tp.allMastered, isFalse);
    });
  });

  // ===========================================================================
  // buildTopicCatalog — группировка, счётчики, порядок
  // ===========================================================================
  group('buildTopicCatalog', () {
    late MockProgressService progress;

    setUp(() {
      progress = MockProgressService();
      when(() => progress.masteredIds(any(), any())).thenReturn(<String>{});
      when(() => progress.loadIncompleteTopicSession(any())).thenReturn(null);
    });

    test('пустой каталог тем для пустого списка треков', () {
      expect(buildTopicCatalog(const [], progress), isEmpty);
    });

    test('вопросы без темы (null и пустая строка) пропускаются', () {
      final tracks = [
        _track(
          id: 't1',
          title: 'Аналитика',
          grades: [
            _grade(
              id: 'junior',
              title: 'Junior',
              questions: [_q('q1'), _q('q2', topic: '')],
            ),
          ],
        ),
      ];
      expect(buildTopicCatalog(tracks, progress), isEmpty);
    });

    test('группирует по теме и считает всего/освоено по masteredIds', () {
      final tracks = [
        _track(
          id: 't1',
          title: 'Аналитика',
          grades: [
            _grade(
              id: 'junior',
              title: 'Junior',
              questions: [
                _q('q1', topic: 'SQL'),
                _q('q2', topic: 'SQL'),
                _q('q3', topic: 'БД'),
              ],
            ),
          ],
        ),
      ];
      when(() => progress.masteredIds('t1', 'junior')).thenReturn({'q1'});

      final catalog = buildTopicCatalog(tracks, progress);

      expect(catalog.map((t) => t.title), ['SQL', 'БД']);
      final sql = catalog.firstWhere((t) => t.title == 'SQL');
      expect(sql.total, 2);
      expect(sql.mastered, 1);
      final db = catalog.firstWhere((t) => t.title == 'БД');
      expect(db.total, 1);
      expect(db.mastered, 0); // освоенных нет → 0, а не падение на null
    });

    test('одна тема в нескольких грейдах — счётчики суммируются', () {
      final tracks = [
        _track(
          id: 't1',
          title: 'Аналитика',
          grades: [
            _grade(
              id: 'junior',
              title: 'Junior',
              order: 1,
              questions: [_q('q1', topic: 'SQL')],
            ),
            _grade(
              id: 'middle',
              title: 'Middle',
              order: 2,
              questions: [_q('q2', topic: 'SQL')],
            ),
          ],
        ),
      ];
      when(() => progress.masteredIds('t1', 'junior')).thenReturn({'q1'});
      when(() => progress.masteredIds('t1', 'middle')).thenReturn(<String>{});

      final catalog = buildTopicCatalog(tracks, progress);

      expect(catalog, hasLength(1));
      expect(catalog.single.total, 2);
      expect(catalog.single.mastered, 1);
    });

    test('грейды обходятся по order — порядок тем по первому появлению', () {
      // Грейды поданы в обратном порядке; сортировка по order должна поставить
      // junior (order 1) раньше middle (order 2), значит тема A появится первой.
      final tracks = [
        _track(
          id: 't1',
          title: 'Аналитика',
          grades: [
            _grade(
              id: 'middle',
              title: 'Middle',
              order: 2,
              questions: [_q('qB', topic: 'B')],
            ),
            _grade(
              id: 'junior',
              title: 'Junior',
              order: 1,
              questions: [_q('qA', topic: 'A')],
            ),
          ],
        ),
      ];

      final catalog = buildTopicCatalog(tracks, progress);
      expect(catalog.map((t) => t.title), ['A', 'B']);
    });

    test('треки обходятся по order; одна тема в разных треках суммируется', () {
      // Треки поданы в обратном порядке. t1 (order 1) идёт первым → тема общая
      // суммируется, а порядок определяется первым появлением в t1.
      final tracks = [
        _track(
          id: 't2',
          title: 'Разработка',
          order: 2,
          grades: [
            _grade(
              id: 'junior',
              title: 'Junior',
              questions: [_q('d1', topic: 'SQL')],
            ),
          ],
        ),
        _track(
          id: 't1',
          title: 'Аналитика',
          order: 1,
          grades: [
            _grade(
              id: 'junior',
              title: 'Junior',
              questions: [_q('a1', topic: 'SQL'), _q('a2', topic: 'ООП')],
            ),
          ],
        ),
      ];

      final catalog = buildTopicCatalog(tracks, progress);

      expect(catalog.map((t) => t.title), ['SQL', 'ООП']);
      final sql = catalog.firstWhere((t) => t.title == 'SQL');
      expect(sql.total, 2); // a1 (t1) + d1 (t2)
    });
  });

  // ===========================================================================
  // startTopicSession — запуск сессии по теме / fallback
  // ===========================================================================
  group('startTopicSession', () {
    late MockProgressService progress;

    setUp(() {
      progress = MockProgressService();
      when(() => progress.masteredIds(any(), any())).thenReturn(<String>{});
    });

    Future<void> pumpStarter(WidgetTester tester, {
      required List<Track> tracks,
      required String topic,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildLightTheme(),
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () => startTopicSession(
                    context,
                    tracks: tracks,
                    progress: progress,
                    topicTitle: topic,
                  ),
                  child: const Text('go'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
    }

    testWidgets('есть непройденные вопросы темы → открывает SessionScreen',
      (tester) async {
        final tracks = [
          _track(
            id: 't1',
            title: 'Аналитика',
            grades: [
              _grade(
                id: 'junior',
                title: 'Junior',
                questions: [_q('q1', topic: 'SQL', text: 'JQ')],
              ),
            ],
          ),
        ];

        await pumpStarter(tester, tracks: tracks, topic: 'SQL');

        expect(find.byType(SessionScreen), findsOneWidget);
        expect(find.text('JQ'), findsOneWidget);
      },
    );

    testWidgets('в сессию попадают только вопросы темы, не весь грейд',
      (tester) async {
        final tracks = [
          _track(
            id: 't1',
            title: 'Аналитика',
            grades: [
              _grade(
                id: 'junior',
                title: 'Junior',
                questions: [
                  _q('q1', topic: 'SQL', text: 'SQLQ'),
                  _q('q2', topic: 'ООП', text: 'OOPQ'),
                ],
              ),
            ],
          ),
        ];

        await pumpStarter(tester, tracks: tracks, topic: 'SQL');

        // Всего вопросов в сессии — 1 (только SQL), это видно в заголовке "1 / 1".
        expect(find.text('1 / 1'), findsOneWidget);
        expect(find.text('SQLQ'), findsOneWidget);
        expect(find.text('OOPQ'), findsNothing);
      },
    );

    testWidgets('берётся первый грейд по order (junior раньше middle)',
      (tester) async {
        final tracks = [
          _track(
            id: 't1',
            title: 'Аналитика',
            grades: [
              _grade(
                id: 'middle',
                title: 'Middle',
                order: 2,
                questions: [_q('qm', topic: 'SQL', text: 'MQ')],
              ),
              _grade(
                id: 'junior',
                title: 'Junior',
                order: 1,
                questions: [_q('qj', topic: 'SQL', text: 'JQ')],
              ),
            ],
          ),
        ];

        await pumpStarter(tester, tracks: tracks, topic: 'SQL');

        // Чип сессии: "<трек> · <грейд>". Должен быть Junior, не Middle.
        expect(find.textContaining('Junior'), findsOneWidget);
        expect(find.textContaining('Middle'), findsNothing);
        expect(find.text('JQ'), findsOneWidget);
      },
    );

    testWidgets(
      'пауза по теме → диалог; barrier dismiss (null) → нет сессии, пауза не очищена',
      (tester) async {
        final tracks = [
          _track(
            id: 't1',
            title: 'Аналитика',
            grades: [
              _grade(
                id: 'junior',
                title: 'Junior',
                questions: [_q('q1', topic: 'SQL', text: 'Q1')],
              ),
            ],
          ),
        ];
        when(() => progress.loadIncompleteTopicSession('SQL')).thenReturn(
          const IncompleteSession(
            gradeKey: 't1_junior',
            questionIds: ['q1'],
            currentIndex: 0,
            answeredData: <AnsweredItemData>[],
            topicTitle: 'SQL',
          ).toJson(),
        );
        when(
          () => progress.clearIncompleteTopicSession(
            topicTitle: any(named: 'topicTitle'),
          ),
        ).thenAnswer((_) async {});

        await pumpStarter(tester, tracks: tracks, topic: 'SQL');

        expect(find.text('Незавершённая тема'), findsOneWidget);
        tester.state<NavigatorState>(find.byType(Navigator).last).pop();
        await tester.pumpAndSettle();

        expect(find.byType(SessionScreen), findsNothing);
        verifyNever(
          () => progress.clearIncompleteTopicSession(
            topicTitle: any(named: 'topicTitle'),
          ),
        );
      },
    );

    testWidgets('все вопросы темы пройдены → сессии нет, показан SnackBar',
      (tester) async {
        final tracks = [
          _track(
            id: 't1',
            title: 'Аналитика',
            grades: [
              _grade(
                id: 'junior',
                title: 'Junior',
                questions: [_q('q1', topic: 'SQL')],
              ),
            ],
          ),
        ];
        when(() => progress.masteredIds('t1', 'junior')).thenReturn({'q1'});

        await pumpStarter(tester, tracks: tracks, topic: 'SQL');

        expect(find.byType(SessionScreen), findsNothing);
        expect(find.byType(SnackBar), findsOneWidget);
        expect(
          find.textContaining('не осталось новых вопросов'),
          findsOneWidget,
        );

        // Дренируем таймер авто-скрытия SnackBar (иначе pending timer на teardown).
        await tester.pump(const Duration(seconds: 5));
        await tester.pumpAndSettle();
      },
    );

    testWidgets('темы нет в каталоге → сессии нет, показан SnackBar',
      (tester) async {
        final tracks = [
          _track(
            id: 't1',
            title: 'Аналитика',
            grades: [
              _grade(
                id: 'junior',
                title: 'Junior',
                questions: [_q('q1', topic: 'ООП')],
              ),
            ],
          ),
        ];

        await pumpStarter(tester, tracks: tracks, topic: 'SQL');

        expect(find.byType(SessionScreen), findsNothing);
        expect(find.byType(SnackBar), findsOneWidget);

        // Дренируем таймер авто-скрытия SnackBar (иначе pending timer на teardown).
        await tester.pump(const Duration(seconds: 5));
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'пауза по теме → диалог; «Продолжить» открывает сессию с места',
      (tester) async {
        final tracks = [
          _track(
            id: 't1',
            title: 'Аналитика',
            grades: [
              _grade(
                id: 'junior',
                title: 'Junior',
                questions: [
                  _q('q1', topic: 'SQL', text: 'Q1'),
                  _q('q2', topic: 'SQL', text: 'Q2'),
                ],
              ),
            ],
          ),
        ];
        when(() => progress.loadIncompleteTopicSession('SQL')).thenReturn(
          const IncompleteSession(
            gradeKey: 't1_junior',
            questionIds: ['q1', 'q2'],
            currentIndex: 1,
            answeredData: [
              AnsweredItemData(id: 'q1', selected: [0], outcome: 'correct'),
            ],
            topicTitle: 'SQL',
          ).toJson(),
        );

        await pumpStarter(tester, tracks: tracks, topic: 'SQL');

        expect(find.text('Незавершённая тема'), findsOneWidget);
        await tester.tap(find.text('Продолжить'));
        await tester.pumpAndSettle();

        // Восстановлен индекс 1 → «2 / 2», текущий вопрос второй.
        expect(find.byType(SessionScreen), findsOneWidget);
        expect(find.text('2 / 2'), findsOneWidget);
        expect(find.text('Q2'), findsOneWidget);
      },
    );
  });

  // ===========================================================================
  // resetTopic — сброс мастеринга темы по всему каталогу
  // ===========================================================================
  group('resetTopic', () {
    test('снимает мастеринг вопросов темы по всем грейдам и чистит паузу',
        () async {
      final progress = MockProgressService();
      when(() => progress.resetMastered(any())).thenAnswer((_) async {});
      when(
        () => progress.clearIncompleteTopicSession(
          topicTitle: any(named: 'topicTitle'),
        ),
      ).thenAnswer((_) async {});

      final tracks = [
        _track(
          id: 't1',
          title: 'Аналитика',
          grades: [
            _grade(
              id: 'junior',
              title: 'Junior',
              questions: [
                _q('q1', topic: 'SQL'),
                _q('q2', topic: 'ООП'),
              ],
            ),
            _grade(
              id: 'middle',
              title: 'Middle',
              questions: [_q('q3', topic: 'SQL')],
            ),
          ],
        ),
      ];

      await resetTopic(tracks, progress, 'SQL');

      final captured = verify(() => progress.resetMastered(captureAny()))
          .captured
          .single as Map<String, Set<String>>;
      expect(captured['t1_junior'], {'q1'}); // q2 (ООП) исключён
      expect(captured['t1_middle'], {'q3'});
      verify(
        () => progress.clearIncompleteTopicSession(topicTitle: 'SQL'),
      ).called(1);
    });
  });
}
