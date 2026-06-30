import 'package:flutter/widgets.dart';

/// Отслеживает имя текущего верхнего маршрута для отчётов обратной связи.
///
/// Подключается только в тестовой сборке (см. `main.dart`). Имя берётся из
/// `RouteSettings(name:)`, которое экраны проставляют при push. Корневой
/// маршрут шелла («/») показывается как «Главная»; вкладки внутри шелла
/// маршрутами не различаются — это ограничение IndexedStack, не баг.
class FeedbackRouteObserver extends NavigatorObserver {
  String _current = '—';

  /// Имя текущего экрана (или «—», если маршрут анонимный).
  String get currentRouteName => _current == '/' ? 'Главная' : _current;

  void _update(Route<dynamic>? route) {
    _current = route?.settings.name ?? '—';
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _update(route);
    super.didPush(route, previousRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _update(previousRoute);
    super.didPop(route, previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    _update(newRoute);
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
  }
}

/// Единственный экземпляр-наблюдатель, общий для приложения.
final feedbackRouteObserver = FeedbackRouteObserver();
