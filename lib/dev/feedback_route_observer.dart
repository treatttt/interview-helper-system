import 'package:flutter/widgets.dart';

/// Отслеживает имя текущего верхнего маршрута для отчётов обратной связи.
///
/// Подключается только в тестовой сборке (см. `main.dart`). Имя берётся из
/// `RouteSettings(name:)`, которое экраны проставляют при push.
/// Вкладки внутри IndexedStack-шелла не являются маршрутами — они обновляются
/// через [setTab].
class FeedbackRouteObserver extends NavigatorObserver {
  String _current = '—';
  String _tabName = 'Главная';

  /// Вызывается из MainShell при смене вкладки, чтобы observer знал,
  /// на какой вкладке шелла находится пользователь.
  void updateTab(String name) {
    _tabName = name;
  }

  /// Имя текущего экрана. Если навигатор стоит на корневом/безымянном маршруте
  /// (т.е. пользователь на вкладке шелла), возвращает имя текущей вкладки.
  String get currentRouteName {
    if (_current == '/' || _current == '—' || _current == 'Главная') {
      return _tabName;
    }
    return _current;
  }

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
