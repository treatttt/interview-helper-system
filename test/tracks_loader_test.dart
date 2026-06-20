import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:interview_helper_system/models/models.dart';
import 'package:interview_helper_system/screens/tracks_loader.dart';
import 'package:interview_helper_system/services/question_repository.dart';
import 'package:interview_helper_system/theme.dart';
import 'package:mocktail/mocktail.dart';

// --- Test doubles ----------------------------------------------------------
class MockQuestionRepository extends Mock implements QuestionRepository {}

Track _track({required String id, int order = 0}) =>
    Track(id: id, title: id, order: order, grades: const []);

// Минимальный хост, поднимающий миксин вне экранов: проверяем его контракт
// напрямую через наблюдаемое поведение (loading/error/tracks + retry).
class _Host extends StatefulWidget {
  const _Host({required this.repository, required this.errorMessage});

  final QuestionRepository repository;
  final String errorMessage;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> with TracksLoader<_Host> {
  @override
  QuestionRepository get repository => widget.repository;

  @override
  String get loadErrorMessage => widget.errorMessage;

  @override
  Widget build(BuildContext context) {
    if (loading) return const Text('loading');
    final err = error;
    if (err != null) {
      return ErrorRetryView(title: err, onRetry: retryLoad);
    }
    return Text('ids:${tracks.map((t) => t.id).join(',')}');
  }
}

void main() {
  late MockQuestionRepository repo;

  setUp(() => repo = MockQuestionRepository());

  Future<void> pumpHost(WidgetTester tester) {
    return tester.pumpWidget(
      MaterialApp(
        theme: buildLightTheme(),
        home: Scaffold(
          body: _Host(repository: repo, errorMessage: 'Не удалось загрузить'),
        ),
      ),
    );
  }

  group('TracksLoader', () {
    testWidgets('сначала loading, затем треки, отсортированные по order',
        (tester) async {
      final completer = Completer<List<Track>>();
      when(() => repo.loadTracks()).thenAnswer((_) => completer.future);

      await pumpHost(tester);
      expect(find.text('loading'), findsOneWidget);

      completer.complete([
        _track(id: 'b', order: 1),
        _track(id: 'a'),
      ]);
      await tester.pumpAndSettle();

      expect(find.text('ids:a,b'), findsOneWidget);
    },);

    testWidgets('ошибка → loadErrorMessage; retryLoad перезагружает успешно',
        (tester) async {
      var calls = 0;
      when(() => repo.loadTracks()).thenAnswer((_) async {
        calls++;
        if (calls == 1) throw Exception('boom');
        return [_track(id: 'a')];
      });

      await pumpHost(tester);
      await tester.pumpAndSettle();
      expect(find.text('Не удалось загрузить'), findsOneWidget);

      await tester.tap(find.text('Попробовать снова'));
      await tester.pumpAndSettle();

      expect(find.text('ids:a'), findsOneWidget);
      expect(find.text('Не удалось загрузить'), findsNothing);
    },);
  });

  group('ErrorRetryView', () {
    testWidgets('рендерит заголовок, подпись и кнопку повтора', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildLightTheme(),
          home: Scaffold(
            body: ErrorRetryView(title: 'Заголовок ошибки', onRetry: () {}),
          ),
        ),
      );

      expect(find.text('Заголовок ошибки'), findsOneWidget);
      expect(
        find.text('Что-то пошло не так. Попробуй ещё раз.'),
        findsOneWidget,
      );
      expect(find.text('Попробовать снова'), findsOneWidget);
    });

    testWidgets('тап по кнопке вызывает onRetry', (tester) async {
      var tapped = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: buildLightTheme(),
          home: Scaffold(
            body: ErrorRetryView(title: 'X', onRetry: () => tapped++),
          ),
        ),
      );

      await tester.tap(find.text('Попробовать снова'));
      await tester.pump();

      expect(tapped, 1);
    });
  });
}
