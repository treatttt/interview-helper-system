import 'package:flutter/widgets.dart';

/// Отслеживает имя текущего верхнего маршрута для отчётов обратной связи.
///
/// Подключается только в тестовой сборке (см. `main.dart`). Имя экрана берётся
/// из `RouteSettings(name:)`, а уточнение (направление/грейд/тема) — из
/// `RouteSettings(arguments:)`. Важно: имя маршрута парсится Flutter'ом как URI
/// (`Uri.parse`), поэтому в `name` нельзя класть двоеточие и прочую URI-вёрстку
/// — иначе push падает с FormatException и экран не открывается. Уточнение же
/// едет в `arguments` (Navigator его не парсит) и подклеивается к имени только
/// здесь, в отчёте.
///
/// Вкладки шелла (Главная/Практика/Прогресс/Профиль) не являются отдельными
/// маршрутами — это дети IndexedStack, поэтому их имя сообщает сам шелл через
/// [updateTab]. Пока пользователь стоит на корневом/безымянном маршруте,
/// показывается имя активной вкладки.
class FeedbackRouteObserver extends NavigatorObserver {
  String _current = '—';
  String? _detail;
  String _tabName = 'Главная';

  /// Вызывается из MainShell при смене вкладки, чтобы observer знал,
  /// на какой вкладке шелла находится пользователь.
  void updateTab(String name) => _tabName = name;

  /// Имя текущего экрана для отчёта. На корневом/безымянном маршруте (т.е.
  /// пользователь на одной из вкладок шелла) возвращает имя активной вкладки.
  /// Если у маршрута есть строковое уточнение в `arguments` — подклеивает его
  /// через двоеточие (например, «Вопросы: Backend → Junior»).
  String get currentRouteName {
    if (_current == '/' || _current == '—' || _current == 'Главная') {
      return _tabName;
    }
    final detail = _detail;
    return detail == null || detail.isEmpty ? _current : '$_current: $detail';
  }

  void _update(Route<dynamic>? route) {
    _current = route?.settings.name ?? '—';
    final args = route?.settings.arguments;
    _detail = args is String ? args : null;
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
