import 'package:flutter/material.dart';

/// Длительность анимации, уважающая системное «уменьшить движение».
/// При включённом [MediaQueryData.disableAnimations] возвращает
/// [Duration.zero] - переход происходит мгновенно. Один источник правды для
/// всех анимаций приложения (смена вопроса, переход на результат, будущая
/// анимация серии на экране результата).
Duration motionDuration(BuildContext context, Duration base) {
  final reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
  return reduce ? Duration.zero : base;
}

/// Маршрут с переходом «проявление» (fade) - для смены экрана на результат,
/// где спокойное проявление читается лучше бокового слайда. Уважает
/// reduce-motion: при отключённых анимациях открывается мгновенно.
Route<T> fadeThroughRoute<T>(
    BuildContext context,
    Widget page, {
      Duration base = const Duration(milliseconds: 300),
      String? name,
    }) {
  final duration = motionDuration(context, base);
  return PageRouteBuilder<T>(
    settings: RouteSettings(name: name),
    transitionDuration: duration,
    reverseTransitionDuration: duration,
    pageBuilder: (_, __, ___) => page,
    transitionsBuilder: (_, animation, __, child) =>
        FadeTransition(opacity: animation, child: child),
  );
}
