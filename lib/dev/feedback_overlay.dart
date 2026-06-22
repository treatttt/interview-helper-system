import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:interview_helper_system/dev/feedback_flag.dart';
import 'package:interview_helper_system/dev/feedback_route_observer.dart';

/// Формирует текст отчёта обратной связи. Чистая функция - легко тестируется.
String buildFeedbackReport({
  required String text,
  required String route,
  required String themeLabel,
  required DateTime now,
}) {
  final ts = '${_pad(now.year, 4)}-${_pad(now.month, 2)}-${_pad(now.day, 2)} '
      '${_pad(now.hour, 2)}:${_pad(now.minute, 2)}';
  return '[Фидбек · Тренажёр собеседований]\n'
      'Время: $ts\n'
      'Версия: $kFeedbackAppVersion\n'
      'Тема: $themeLabel\n'
      'Экран: $route\n\n'
      'Текст:\n${text.trim()}';
}

String _pad(int value, int width) => value.toString().padLeft(width, '0');

/// Глобальный слой обратной связи поверх всего приложения.
///
/// Активен только в тестовой сборке, подключается через `MaterialApp.builder`.
/// Не зависит ни от одного экрана, контроллера или сервиса. Панель рисуется
/// в собственном [Stack] (без обращения к Navigator), поэтому работает на
/// любом маршруте и даже во время переходов.
class FeedbackOverlay extends StatefulWidget {
  const FeedbackOverlay({required this.child, super.key});

  final Widget child;

  @override
  State<FeedbackOverlay> createState() => _FeedbackOverlayState();
}

class _FeedbackOverlayState extends State<FeedbackOverlay> {
  static const double _fabSize = 48;

  Offset? _pos;
  bool _open = false;

  Offset _defaultPos(Size size) =>
      Offset(size.width - _fabSize - 16, size.height - _fabSize - 120);

  void _move(Offset delta, Size size) {
    final next = (_pos ?? _defaultPos(size)) + delta;
    setState(() {
      _pos = Offset(
        next.dx.clamp(0.0, size.width - _fabSize),
        next.dy.clamp(0.0, size.height - _fabSize),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final pos = _pos ?? _defaultPos(size);
    return Stack(
      children: [
        widget.child,
        Positioned(
          left: pos.dx,
          top: pos.dy,
          child: _DraggableFab(
            size: _fabSize,
            onTap: () => setState(() => _open = true),
            onMove: (delta) => _move(delta, size),
          ),
        ),
        if (_open) _FeedbackPanel(onClose: () => setState(() => _open = false)),
      ],
    );
  }
}

class _DraggableFab extends StatelessWidget {
  const _DraggableFab({
    required this.size,
    required this.onTap,
    required this.onMove,
  });

  final double size;
  final VoidCallback onTap;
  final ValueChanged<Offset> onMove;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      onPanUpdate: (d) => onMove(d.delta),
      child: Material(
        color: cs.secondaryContainer,
        shape: const CircleBorder(),
        elevation: 4,
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(
            Icons.feedback_outlined,
            color: cs.onSecondaryContainer,
            size: 22,
          ),
        ),
      ),
    );
  }
}

class _FeedbackPanel extends StatefulWidget {
  const _FeedbackPanel({required this.onClose});

  final VoidCallback onClose;

  @override
  State<_FeedbackPanel> createState() => _FeedbackPanelState();
}

class _FeedbackPanelState extends State<_FeedbackPanel> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _themeLabel() =>
      Theme.of(context).brightness == Brightness.dark ? 'тёмная' : 'светлая';

  Future<void> _submit() async {
    final messenger = ScaffoldMessenger.of(context);
    final report = buildFeedbackReport(
      text: _controller.text,
      route: feedbackRouteObserver.currentRouteName,
      themeLabel: _themeLabel(),
      now: DateTime.now(),
    );
    await Clipboard.setData(ClipboardData(text: report));
    widget.onClose();
    messenger.showSnackBar(
      const SnackBar(content: Text('Скопировано. Вставь в форму или чат.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Material(
        color: Colors.black54,
        child: GestureDetector(
          onTap: widget.onClose,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: GestureDetector(
              onTap: () {},
              child: _card(context),
            ),
          ),
        ),
      ),
    );
  }

  Widget _card(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + inset),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Обратная связь',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Опиши проблему или идею. Экран, версия и тема добавятся '
            'в отчёт автоматически.',
            style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            minLines: 3,
            maxLines: 5,
            autofocus: true,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'Что произошло?',
            ),
          ),
          const SizedBox(height: 10),
          _destinationLine(cs),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _submit,
              icon: const Icon(Icons.copy_all_outlined),
              label: const Text('Скопировать отчёт'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _destinationLine(ColorScheme cs) {
    return Row(
      children: [
        Icon(Icons.link, size: 16, color: cs.onSurfaceVariant),
        const SizedBox(width: 6),
        Expanded(
          child: SelectableText(
            kFeedbackDestination,
            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}
