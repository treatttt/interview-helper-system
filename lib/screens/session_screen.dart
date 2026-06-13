import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/progress_service.dart';
import '../theme.dart';
import 'result_screen.dart';

class SessionScreen extends StatefulWidget {
  final Topic topic;
  final ProgressService progress;
  const SessionScreen(
      {super.key, required this.topic, required this.progress});

  @override
  State<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends State<SessionScreen> {
  int _index = 0;
  int _score = 0;
  int? _picked;

  Question get _q => widget.topic.questions[_index];
  bool get _answered => _picked != null;

  void _choose(int i) {
    if (_answered) return;
    setState(() {
      _picked = i;
      if (i == _q.correct) _score++;
    });
  }

  Future<void> _next() async {
    if (_index < widget.topic.questions.length - 1) {
      setState(() {
        _index++;
        _picked = null;
      });
    } else {
      await widget.progress.addXp(_score * 10);
      await widget.progress.setTopicDone(widget.topic.id, _score);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ResultScreen(
            score: _score,
            total: widget.topic.questions.length,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.topic.questions.length;
    return Scaffold(
      appBar: AppBar(title: Text('${_index + 1} / $total')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: _index / total,
                minHeight: 6,
                backgroundColor: AppColors.background,
                color: AppColors.info,
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.infoBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(widget.topic.title,
                  style: const TextStyle(color: AppColors.info, fontSize: 11)),
            ),
            const SizedBox(height: 14),
            Text(_q.text,
                style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w500,
                    height: 1.4)),
            const SizedBox(height: 18),
            ...List.generate(_q.options.length, (i) => _optionTile(i)),
            const Spacer(),
            if (_answered) _explanation(),
            if (_answered)
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _next,
                  style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14)),
                  child: Text(_index < total - 1 ? 'Дальше' : 'Завершить'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _optionTile(int i) {
    Color bg = AppColors.surface;
    Color border = AppColors.border;
    Color text = AppColors.textPrimary;
    if (_answered) {
      if (i == _q.correct) {
        bg = AppColors.successBg;
        border = AppColors.success;
        text = AppColors.success;
      } else if (i == _picked) {
        bg = AppColors.dangerBg;
        border = AppColors.danger;
        text = AppColors.danger;
      }
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => _choose(i),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: border),
          ),
          child: Text(_q.options[i],
              style: TextStyle(color: text, fontSize: 14)),
        ),
      ),
    );
  }

  Widget _explanation() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(_q.explanation,
          style: const TextStyle(
              color: AppColors.textSecondary, fontSize: 13, height: 1.5)),
    );
  }
}
