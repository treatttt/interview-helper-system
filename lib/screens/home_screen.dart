import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/question_repository.dart';
import 'session_screen.dart';

class HomeScreen extends StatefulWidget {
  final QuestionRepository repository;
  const HomeScreen({super.key, required this.repository});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Topic> _topics = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final topics = await widget.repository.loadTopics();
    if (!mounted) return;
    setState(() {
      _topics = topics;
      _loading = false;
    });
  }

  Future<void> _openSession(Topic topic) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SessionScreen(topic: topic),
      ),
    );
    setState(() {}); // обновить после возврата (прогресс подтянем позже)
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Тренажёр',
            style: TextStyle(fontWeight: FontWeight.w500)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('System Analyst Junior',
              style: TextStyle(color: Colors.grey, fontSize: 13)),
          const SizedBox(height: 12),
          ..._topics.map(_topicCard),
        ],
      ),
    );
  }

  Widget _topicCard(Topic topic) {
    final total = topic.questions.length;
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
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(topic.title,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w500)),
              ),
              Text('$total вопросов',
                  style: const TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}