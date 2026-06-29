import 'package:flutter/material.dart';
import 'package:interview_helper_system/controllers/session_controller.dart';
import 'package:interview_helper_system/models/models.dart';
import 'package:interview_helper_system/screens/review_screen.dart';
import 'package:interview_helper_system/services/progress_service.dart';
import 'package:interview_helper_system/theme.dart';
import 'package:interview_helper_system/utils/result_grade.dart';
import 'package:interview_helper_system/widgets/wave_gauge.dart';

/// Экран результата сессии: круг-«стакан», заполняющийся по проценту верных
/// ответов, похвала по этому проценту, метрики (XP / серия / время) и блок
/// «Стоит повторить» со слабыми темами пройденного теста.
class ResultScreen extends StatelessWidget {
  const ResultScreen({
    required this.result,
    required this.track,
    required this.grade,
    required this.progress,
    super.key,
    this.questionGradeKeys,
    this.elapsed,
  });
  final SessionResult result;
  final Track track;
  final Grade grade;
  final ProgressService progress;

  /// Проброс для разбора: если это был микс — «Проработать ошибки» тоже
  /// записывается как микс. null — обычная сессия.
  final Map<String, String>? questionGradeKeys;

  /// Время, проведённое в сессии (для метрики «в сессии»). null — не показываем.
  final Duration? elapsed;

  int get _total => result.correct + result.partial + result.wrong;
  int get _percent =>
      _total == 0 ? 0 : (result.correct / _total * 100).round();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final s = AppSemanticColors.of(context);
    // Заливка круга — всегда брендовый цвет, как у кнопок «Продолжить»,
    // независимо от доли верных ответов.
    final accent = cs.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Сессия завершена'),
        automaticallyImplyLeading: false,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          const SizedBox(height: 8),
          Center(
            child: WaveGauge(
              value: _total == 0 ? 0 : result.correct / _total,
              size: 132,
              fillColor: accent,
              backgroundColor: cs.surfaceContainerHighest,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$_percent%',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    '${result.correct} из $_total',
                    style: TextStyle(
                      fontSize: 12,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            praiseForScore(_percent),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            _subtitle(),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 22),
          _legend(s),
          const SizedBox(height: 18),
          _statsRow(context),
          ..._repeatSection(context),
        ],
      ),
      bottomNavigationBar: _bottomBar(context),
    );
  }

  // ── Подзаголовок ──────────────────────────────────────────────────────────

  /// «Аналитика · Junior» (+ « · Тема», если вся сессия про одну тему).
  String _subtitle() {
    final topics = result.answers
        .map((a) => a.question.topic)
        .where((t) => t != null && t.trim().isNotEmpty)
        .toSet();
    final parts = [track.title, grade.title];
    if (topics.length == 1) parts.add(topics.first!);
    return parts.join(' · ');
  }

  // ── Легенда верно/частично/неверно ──────────────────────────────────────

  Widget _legend(AppSemanticColors s) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _legendItem(s.successFg, 'Верно', result.correct),
        const SizedBox(width: 18),
        _legendItem(s.warningFg, 'Частично', result.partial),
        const SizedBox(width: 18),
        _legendItem(s.dangerFg, 'Неверно', result.wrong),
      ],
    );
  }

  Widget _legendItem(Color color, String label, int value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text('$label $value', style: const TextStyle(fontSize: 13)),
      ],
    );
  }

  // ── Метрики: XP / серия / время ──────────────────────────────────────────

  Widget _statsRow(BuildContext context) {
    final stats = <Widget>[
      _statBox(context, value: '+${result.xpEarned}', label: 'XP'),
      const SizedBox(width: 9),
      _statBox(context, value: '${progress.streak}', label: 'серия дней'),
    ];
    if (elapsed != null) {
      stats
        ..add(const SizedBox(width: 9))
        ..add(_statBox(context, value: _elapsedLabel(elapsed!), label: 'в сессии'));
    }
    return Row(children: stats);
  }

  Widget _statBox(
    BuildContext context, {
    required String value,
    required String label,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Column(
          children: [
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  String _elapsedLabel(Duration d) =>
      d.inMinutes >= 1 ? '${d.inMinutes} мин' : '<1 мин';

  // ── «Стоит повторить» ──────────────────────────────────────────────────

  List<Widget> _repeatSection(BuildContext context) {
    final weak = weakTopicsFromAnswers(result.answers);
    if (weak.isEmpty) return const [];
    final cs = Theme.of(context).colorScheme;

    return [
      const SizedBox(height: 24),
      Text(
        'Стоит повторить',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
          color: cs.onSurfaceVariant,
        ),
      ),
      const SizedBox(height: 8),
      Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Column(
          children: [
            for (var i = 0; i < weak.length; i++) ...[
              if (i > 0)
                Divider(
                  height: 1,
                  thickness: 1,
                  indent: 14,
                  endIndent: 14,
                  color: cs.outlineVariant,
                ),
              _topicRow(context, weak[i], cs.primary),
            ],
          ],
        ),
      ),
    ];
  }

  Widget _topicRow(BuildContext context, TopicScore topic, Color color) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  topic.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: topic.percent / 100,
                    minHeight: 5,
                    backgroundColor: cs.surfaceContainerHighest,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Text(
            '${topic.percent}%',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // ── Нижние кнопки ────────────────────────────────────────────────────────

  Widget _bottomBar(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    settings: const RouteSettings(name: 'Разбор'),
                    builder: (_) => ReviewScreen(
                      result: result,
                      track: track,
                      grade: grade,
                      progress: progress,
                      questionGradeKeys: questionGradeKeys,
                    ),
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Разбор ошибок'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: () =>
                    Navigator.of(context).popUntil((r) => r.isFirst),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Продолжить'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
