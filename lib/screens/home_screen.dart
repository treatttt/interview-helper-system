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

  void _openSession(Topic topic) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SessionScreen(topic: topic, progress: widget.progress),
      ),
    );
    // setState после возврата больше не нужен — ListenableBuilder
    // сам перерисует экран, когда progress изменится.
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
            builder: (context, _) => Padding(
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
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _topics.isEmpty
                  ? const Center(child: Text('Вопросов пока нет'))
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
                          ..._topics.map(_topicCard),
                        ],
                      ),
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
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(topic.title,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w500)),
                  ),
                  Text('$done/$total',
                      style: const TextStyle(color: Colors.grey, fontSize: 12)),
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
}
