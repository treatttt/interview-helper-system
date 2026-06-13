import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/question_repository.dart';
import '../services/progress_service.dart';
import '../theme.dart';
import 'session_screen.dart';

class HomeScreen extends StatefulWidget {
  final ProgressService progress;
  const HomeScreen({super.key, required this.progress});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _repo = QuestionRepository();
  List<Topic> _topics = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final topics = await _repo.loadTopics();
    setState(() {
      _topics = topics;
      _loading = false;
    });
  }

  Future<void> _openSession(Topic topic) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SessionScreen(topic: topic, progress: widget.progress),
      ),
    );
    setState(() {}); // обновить прогресс после возврата
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Тренажёр',
            style: TextStyle(fontWeight: FontWeight.w500)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Row(
              children: [
                const Icon(Icons.local_fire_department,
                    color: AppColors.warning, size: 20),
                const SizedBox(width: 4),
                Text('${widget.progress.streak}',
                    style: const TextStyle(
                        color: AppColors.warning,
                        fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _goalCard(),
                const SizedBox(height: 20),
                const Text('System Analyst Junior',
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 13)),
                const SizedBox(height: 12),
                ..._topics.map(_topicCard),
              ],
            ),
    );
  }

  Widget _goalCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.infoBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Твой прогресс',
              style: TextStyle(color: AppColors.info, fontSize: 13)),
          const SizedBox(height: 4),
          Text('${widget.progress.xp} XP',
              style: const TextStyle(
                  color: AppColors.info,
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
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
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
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 12)),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: pct,
                  minHeight: 6,
                  backgroundColor: AppColors.background,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
