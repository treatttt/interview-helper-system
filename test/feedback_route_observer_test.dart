import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:interview_helper_system/dev/feedback_route_observer.dart';

/// Маршрут-заглушка с именем и опциональным уточнением — для подачи в
/// NavigatorObserver без поднятия настоящего навигатора.
Route<void> _route(String? name, [Object? arguments]) => PageRouteBuilder<void>(
      settings: RouteSettings(name: name, arguments: arguments),
      pageBuilder: (_, __, ___) => const SizedBox.shrink(),
    );

void main() {
  group('FeedbackRouteObserver', () {
    test('по умолчанию показывает вкладку «Главная»', () {
      final observer = FeedbackRouteObserver();
      expect(observer.currentRouteName, 'Главная');
    });

    test('updateTab меняет имя, пока пользователь на вкладке шелла', () {
      final observer = FeedbackRouteObserver()..updateTab('Практика');
      expect(observer.currentRouteName, 'Практика');
      observer.updateTab('Профиль');
      expect(observer.currentRouteName, 'Профиль');
    });

    test('push именованного маршрута перекрывает имя вкладки', () {
      final observer = FeedbackRouteObserver()
        ..updateTab('Практика')
        ..didPush(_route('Вопросы'), _route('/'));
      expect(observer.currentRouteName, 'Вопросы');
    });

    test('уточнение из arguments подклеивается к имени экрана', () {
      final observer = FeedbackRouteObserver()
        ..didPush(_route('Вопросы', 'Backend → Junior'), _route('/'));
      expect(observer.currentRouteName, 'Вопросы: Backend → Junior');
    });

    test('после pop обратно к шеллу снова показывается вкладка', () {
      final observer = FeedbackRouteObserver()..updateTab('Прогресс');
      final shell = _route('/');
      final session = _route('Вопросы', 'SQL');
      observer
        ..didPush(session, shell)
        ..didPop(session, shell);
      expect(observer.currentRouteName, 'Прогресс');
    });

    test('имя маршрута URI-безопасно — Navigator парсит его как Uri', () {
      // Регрессия: уточнение в name (с двоеточием) ломало push с
      // FormatException. Уточнение должно ехать в arguments, а name —
      // оставаться разбираемым через Uri.parse.
      expect(() => Uri.parse('Вопросы'), returnsNormally);
      expect(() => Uri.parse('Темы направления'), returnsNormally);
      expect(() => Uri.parse('Вопросы: Backend → Junior'), throwsFormatException);
    });

    test('безымянный маршрут трактуется как вкладка шелла', () {
      final observer = FeedbackRouteObserver()
        ..updateTab('Профиль')
        ..didPush(_route(null), _route('/'));
      expect(observer.currentRouteName, 'Профиль');
    });
  });
}
