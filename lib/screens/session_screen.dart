import 'package:flutter/material.dart';
import '../models/models.dart';
import '../controllers/session_controller.dart';
import 'result_screen.dart';
import '../services/progress_service.dart';

class SessionScreen extends StatefulWidget {
  final Topic topic;
  final ProgressService progress;

  const SessionScreen({super.key, required this.topic, required this.progress});

  @override
  State<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends State<SessionScreen> {
  late final SessionController _controller;
  bool _finishing = false; // защита от двойного тапа на «Завершить»

  @override
  void initState() {
    super.initState();
    // Контроллер создаётся один раз и владеет логикой сессии.
    _controller = SessionController(widget.topic.questions);
  }

  @override
  void dispose() {
    _controller.dispose(); // ChangeNotifier нужно освобождать
    super.dispose();
  }

  void _onNext() {
    if (_finishing) return; // повторный вход после старта завершения — игнор
    final hasMore = _controller.next();
    if (!hasMore) {
      _finishing = true;
      widget.progress.recordSession(widget.topic.id, _controller.result);
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ResultScreen(
            result: _controller.result,
            topic: widget.topic,
            progress: widget.progress,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // ListenableBuilder перерисовывает экран при каждом notifyListeners().
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final c = _controller;
        return Scaffold(
          appBar: AppBar(title: Text('${c.index + 1} / ${c.total}')),
          body: Column(
            children: [
              // Прокручиваемая зона: прогресс, вопрос, варианты, пояснение.
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: c.index / c.total,
                          minHeight: 6,
                          backgroundColor: Colors.grey.shade200,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(widget.topic.title,
                            style: const TextStyle(fontSize: 11)),
                      ),
                      const SizedBox(height: 8),
                      if (c.current.isMultipleChoice && !c.answered)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 6),
                          child: Text('Можно выбрать несколько вариантов',
                              style:
                                  TextStyle(color: Colors.grey, fontSize: 12)),
                        ),
                      const SizedBox(height: 6),
                      Text(c.current.text,
                          style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w500,
                              height: 1.4)),
                      const SizedBox(height: 18),
                      ...List.generate(
                          c.current.options.length, (i) => _optionTile(c, i)),
                      if (c.answered &&
                          c.current.explanation != null &&
                          c.current.explanation!.trim().isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(c.current.explanation!,
                              style:
                                  const TextStyle(fontSize: 13, height: 1.5)),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              // Закреплённая кнопка: не уезжает со скроллом, всегда под рукой.
              Padding(
                padding: const EdgeInsets.all(16),
                child: SafeArea(
                  top: false,
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: c.answered
                          ? _onNext
                          : (c.selected.isEmpty ? null : c.submit),
                      style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14)),
                      child: Text(_buttonLabel(c)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _buttonLabel(SessionController c) {
    if (!c.answered) return 'Ответить';
    return c.isLast ? 'Завершить' : 'Дальше';
  }

  Widget _optionTile(SessionController c, int i) {
    final correct = c.current.correctIndexes.contains(i);
    final picked = c.selected.contains(i);

    Color bg = Colors.white;
    Color border = Colors.grey.shade300;
    Color text = Colors.black87;

    if (!c.answered) {
      // До ответа подсвечиваем только выбранные.
      if (picked) {
        bg = Colors.blue.shade50;
        border = Colors.blue;
      }
    } else {
      // После ответа: независимая раскраска каждого варианта.
      if (correct && picked) {
        // верно отмечен
        bg = Colors.green.shade50;
        border = Colors.green;
        text = Colors.green.shade800;
      } else if (correct && !picked) {
        // пропущенный правильный
        bg = Colors.amber.shade50;
        border = Colors.amber.shade700;
        text = Colors.amber.shade900;
      } else if (!correct && picked) {
        // ошибочно отмечен
        bg = Colors.red.shade50;
        border = Colors.red;
        text = Colors.red.shade800;
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => c.toggle(i),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: border),
          ),
          child: Text(c.current.options[i],
              style: TextStyle(color: text, fontSize: 14)),
        ),
      ),
    );
  }
}
