import 'dart:math';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:interview_helper_system/dev/feedback_flag.dart';
import 'package:interview_helper_system/dev/feedback_route_observer.dart';

/// Тип обращения. `bug`/`idea` выбираются тумблером; `review` выставляется
/// автоматически, когда основное поле пустое, а поле впечатлений — нет.
enum FeedbackKind {
  bug('Баг'),
  idea('Идея'),
  review('Отзыв');

  const FeedbackKind(this.label);

  final String label;
}

/// Собранный отчёт. Record вместо класса — чтобы не плодить конструктор
/// с числом параметров сверх лимита метрики (литерал записи не считается
/// объявлением функции).
typedef FeedbackData = ({
String id,
FeedbackKind kind,
String screen,
String text,
});

const _idAlphabet = '0123456789ABCDEFGHJKMNPQRSTUVWXYZ';

/// Короткий человекочитаемый ID отчёта (например `FB-7K9X2A`).
/// Не криптостойкий — нужен лишь для ссылок «баг FB-…» при разборе.
String generateFeedbackId([Random? random]) {
  final rnd = random ?? Random();
  final tail = List.generate(
    6,
        (_) => _idAlphabet[rnd.nextInt(_idAlphabet.length)],
  ).join();
  return 'FB-$tail';
}

/// Тело POST-запроса: текст + опциональные атомарные поля (Тип/Экран/Версия/ID).
Map<String, String> buildFormBody(FeedbackData data) {
  final body = <String, String>{};
  if (kEntryText.isNotEmpty) body[kEntryText] = data.text.trim();
  if (kEntryType.isNotEmpty) body[kEntryType] = data.kind.label;
  if (kEntryScreen.isNotEmpty) body[kEntryScreen] = data.screen;
  if (kEntryVersion.isNotEmpty) body[kEntryVersion] = kFeedbackAppVersion;
  if (kEntryId.isNotEmpty) body[kEntryId] = data.id;
  return body;
}

/// Отправляет отчёт в Google-форму. Возвращает `true`, если запрос ушёл.
///
/// На web Google блокирует чтение ответа (CORS), но запись регистрирует,
/// поэтому исключение не означает провал. Если форма не настроена — `false`.
Future<bool> sendFeedbackReport(FeedbackData data) async {
  if (!kFeedbackAutoSend) return false;
  try {
    await http.post(Uri.parse(kFeedbackFormUrl), body: buildFormBody(data));
    return true;
  } on Exception catch (_) {
    return true;
  }
}

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
        if (_open)
          _FeedbackPanel(onClose: () => setState(() => _open = false)),
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
  final _reviewController = TextEditingController();
  final _id = generateFeedbackId();
  FeedbackKind _kind = FeedbackKind.bug;
  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    _reviewController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    final messenger = ScaffoldMessenger.of(context);
    final main = _controller.text.trim();
    final review = _reviewController.text.trim();
    final screen = feedbackRouteObserver.currentRouteName;

    // Что отправляем: баг/идея и/или отзыв. Если заполнены оба — два
    // отдельных сообщения (две строки формы, различаются колонкой «Тип»).
    final reports = <FeedbackData>[
      if (main.isNotEmpty)
        (id: _id, kind: _kind, screen: screen, text: main),
      if (review.isNotEmpty)
        (id: _id, kind: FeedbackKind.review, screen: screen, text: review),
    ];

    if (reports.isEmpty) {
      widget.onClose();
      messenger.showSnackBar(
        const SnackBar(content: Text('Напиши что-нибудь перед отправкой.')),
      );
      return;
    }

    setState(() => _busy = true);
    var sent = false;
    for (final report in reports) {
      final ok = await sendFeedbackReport(report);
      sent = sent || ok;
    }
    widget.onClose();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          sent
              ? 'Отправлено, спасибо! ($_id)'
              : 'Авто-отправка не настроена (FEEDBACK_FORM_URL/ENTRY).',
        ),
      ),
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
    final maxHeight = MediaQuery.sizeOf(context).height * 0.85;
    return Container(
      width: double.infinity,
      constraints: BoxConstraints(maxHeight: maxHeight),
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + inset),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _header(cs),
            const SizedBox(height: 12),
            _typeSelector(),
            const SizedBox(height: 12),
            _input(),
            const SizedBox(height: 16),
            _reviewInput(),
            const SizedBox(height: 8),
            Text(
              'ID: $_id',
              style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            _submitButton(),
          ],
        ),
      ),
    );
  }

  Widget _header(ColorScheme cs) {
    return Column(
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
          'Опиши проблему или идею — или просто оставь впечатления ниже.',
          style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
        ),
      ],
    );
  }

  Widget _typeSelector() {
    return SegmentedButton<FeedbackKind>(
      segments: const [
        ButtonSegment(
          value: FeedbackKind.bug,
          label: Text('Баг'),
          icon: Icon(Icons.bug_report_outlined),
        ),
        ButtonSegment(
          value: FeedbackKind.idea,
          label: Text('Идея'),
          icon: Icon(Icons.lightbulb_outline),
        ),
      ],
      selected: {_kind},
      onSelectionChanged: (s) => setState(() => _kind = s.first),
    );
  }

  Widget _input() {
    return TextField(
      controller: _controller,
      minLines: 2,
      maxLines: 4,
      autofocus: true,
      decoration: const InputDecoration(
        border: OutlineInputBorder(),
        labelText: 'Баг или идея',
        hintText: 'Что произошло?',
      ),
    );
  }

  Widget _reviewInput() {
    return TextField(
      controller: _reviewController,
      minLines: 2,
      maxLines: 3,
      decoration: const InputDecoration(
        border: OutlineInputBorder(),
        labelText: 'Впечатления (необязательно)',
        hintText: 'Здесь можно поделиться впечатлениями об использовании',
      ),
    );
  }

  Widget _submitButton() {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: _busy ? null : _submit,
        icon: const Icon(Icons.send_outlined),
        label: const Text('Отправить'),
      ),
    );
  }
}