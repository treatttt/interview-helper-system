import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/question_repository.dart';
import '../services/progress_service.dart';
import 'session_screen.dart';

class HomeScreen extends StatefulWidget {
  final QuestionRepository repository;
  final ProgressService progress;

  const HomeScreen(
      {super.key, required this.repository, required this.progress});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Topic> _topics = [];
  bool _loading = true;
  String? _error; // текст ошибки, если загрузка упала целиком
  bool _opening = false; // защита от двойного тапа по карточке темы

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final topics = await widget.repository.loadTopics();
      if (!mounted) return;
      setState(() {
        _topics = topics;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Не удалось загрузить вопросы';
        _loading = false;
      });
    }
  }

  void _openSession(Topic topic) async {
    if (_opening) return; // переход уже стартовал — игнорируем повторный тап
    _opening = true;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SessionScreen(topic: topic, progress: widget.progress),
      ),
    );
    _opening = false; // вернулись с сессии — снова можно открывать
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Тренажёр',
            style: TextStyle(fontWeight: FontWeight.w500)),
        actions: [
          // Streak в шапке. Подписан на progress: обновится сам.
          ListenableBuilder(
            listenable: widget.progress,
            builder: (context, _) {
              // До первой сессии индикатора нет: огонёк появляется, когда серия зажглась.
              if (!widget.progress.hasTrainedEver) {
                return const SizedBox.shrink();
              }
              return Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Row(
                  children: [
                    const Icon(Icons.local_fire_department,
                        color: Colors.orange, size: 20),
                    const SizedBox(width: 4),
                    Text('${widget.progress.streak}',
                        style: const TextStyle(
                            color: Colors.orange, fontWeight: FontWeight.w500)),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _errorView()
              : _topics.isEmpty
                  ? _emptyTopicsView()
                  : ListenableBuilder(
                      listenable: widget.progress,
                      builder: (context, _) => ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          _xpCard(),
                          const SizedBox(height: 20),
                          const Text('System Analyst Junior',
                              style:
                                  TextStyle(color: Colors.grey, fontSize: 13)),
                          const SizedBox(height: 12),
                          if (!widget.progress.hasTrainedEver) ...[
                            _firstSessionHint(),
                            const SizedBox(height: 12),
                          ],
                          ..._topics.map(_topicCard),
                        ],
                      ),
                    ),
    );
  }

  Widget _emptyTopicsView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_outlined, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text('Вопросов пока нет',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w500)),
            const SizedBox(height: 6),
            Text('Темы появятся, когда будут добавлены вопросы.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }

  Widget _firstSessionHint() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.touch_app_outlined, size: 20, color: Colors.blue.shade400),
          const SizedBox(width: 10),
          const Expanded(
            child: Text('Выбери тему, чтобы начать первую сессию',
                style: TextStyle(fontSize: 14, height: 1.3)),
          ),
        ],
      ),
    );
  }

  Widget _xpCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Твой прогресс',
              style: TextStyle(color: Colors.blue, fontSize: 13)),
          const SizedBox(height: 4),
          Text('${widget.progress.xp} XP',
              style: const TextStyle(
                  color: Colors.blue,
                  fontSize: 22,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _topicCard(Topic topic) {
    final done = widget.progress.topicDone(topic.id);
    final total = topic.questions.length;
    final pct = total == 0 ? 0.0 : done / total;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () => _openSession(topic),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(topic.title,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w500)),
                  ),
                  Text('$done/$total',
                      style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  const SizedBox(width: 6),
                  Icon(Icons.chevron_right,
                      size: 20, color: Colors.grey.shade600),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: pct,
                  minHeight: 6,
                  backgroundColor: Colors.grey.shade200,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _errorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_outlined,
                size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text('Не удалось загрузить вопросы',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w500)),
            const SizedBox(height: 6),
            Text('Что-то пошло не так. Попробуй ещё раз.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () {
                setState(() {
                  _error = null;
                  _loading = true;
                });
                _load();
              },
              child: const Text('Попробовать снова'),
            ),
          ],
        ),
      ),
    );
  }
}
