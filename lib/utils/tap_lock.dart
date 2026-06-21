import 'dart:async';

import 'package:flutter/widgets.dart';

/// Защита точек входа в навигацию от двойного/быстрого тапа.
///
/// Подмешивается в [State]. Пока запущенное через [guardTap] действие не
/// завершилось, повторные вызовы игнорируются. Лок ставится **синхронно** -
/// поэтому второй тап в том же кадре отсекается ещё до первого `await`.
///
/// Важно: чтобы лок перекрывал окно «push инициирован → новый экран построен»,
/// переданное действие должно держаться открытым до конца перехода. На практике
/// это `await Navigator.push(...)`, который завершается только при возврате с
/// экрана (так же сделано в `GradesScreen._openSession`). Короткое
/// fire-and-forget-действие снимет лок слишком рано - и второй тап проскочит.
mixin TapLock<T extends StatefulWidget> on State<T> {
  bool _tapLocked = false;

  /// Запускает [action] под локом. Если лок уже взят - тихо выходит.
  void guardTap(Future<void> Function() action) {
    if (_tapLocked) return;
    _tapLocked = true;
    unawaited(_runLocked(action));
  }

  Future<void> _runLocked(Future<void> Function() action) async {
    try {
      await action();
    } finally {
      // Экран под открытым роутом остаётся mounted - снимаем лок к возврату.
      // Если размонтированы, поле уедет вместе со State, сбрасывать нечего.
      if (mounted) _tapLocked = false;
    }
  }
}
