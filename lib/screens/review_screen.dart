import 'package:flutter/material.dart';
import 'package:interview_helper_system/controllers/session_controller.dart';
import 'package:interview_helper_system/models/models.dart';
import 'package:interview_helper_system/screens/session_screen.dart';
import 'package:interview_helper_system/services/progress_service.dart';
import 'package:interview_helper_system/theme.dart';
import 'package:interview_helper_system/utils/motion.dart';

/// Экран «Разбор ответов»: список вопросов, на которые ответили неверно или
/// частично. Каждая карточка сворачивается/разворачивается на месте по тапу —
/// без перехода на отдельный экран. В развёрнутом виде показывает правильный
/// ответ, пояснение «Почему» и смежные знания «Что ещё важно знать».
class ReviewScreen extends StatelessWidget {
  const ReviewScreen({
    required this.result,
    required this.track,
    required this.grade,
    required this.progress,
    super.key,
    this.questionGradeKeys,
  });
  final SessionResult result;
  final Track track;
  final Grade grade;
  final ProgressService progress;

  /// Если задано — исходная сессия была миксом; «Проработать ошибки»
  /// перезапускается тоже как микс (прогресс пишется по своим грейдам).
  final Map<String, String>? questionGradeKeys;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final errors = result.answers
        .where((a) => a.outcome != AnswerOutcome.correct)
        .toList();
    final errorQuestions = errors.map((a) => a.question).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Разбор ответов'),
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: errors.isEmpty
          ? _EmptyState(color: cs.onSurfaceVariant)
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              itemCount: errors.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, i) => _ErrorCard(answer: errors[i]),
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: errorQuestions.isEmpty
                      ? null
                      : () {
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute<void>(
                              settings: RouteSettings(
                                name: 'Вопросы',
                                arguments: '${track.title} → ${grade.title}',
                              ),
                              builder: (_) => SessionScreen(
                                track: track,
                                grade: grade,
                                questions: errorQuestions,
                                progress: progress,
                                questionGradeKeys: questionGradeKeys,
                              ),
                            ),
                            (r) => r.isFirst,
                          );
                        },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text(
                    errorQuestions.isEmpty ? 'Ошибок нет' : 'Проработать ошибки',
                  ),
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
                  child: const Text('В меню'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Сворачиваемая карточка одного неверного ответа. По тапу разворачивается
/// вниз, показывая правильный ответ и пояснения — без навигации.
class _ErrorCard extends StatefulWidget {
  const _ErrorCard({required this.answer});

  final AnsweredQuestion answer;

  @override
  State<_ErrorCard> createState() => _ErrorCardState();
}

class _ErrorCardState extends State<_ErrorCard> {
  bool _expanded = false;

  /// Текст правильного ответа: варианты по correctIndexes, каждый с новой
  /// строки (на случай мультивыбора).
  String get _correctAnswer {
    final q = widget.answer.question;
    return q.correctIndexes
        .where((i) => i >= 0 && i < q.options.length)
        .map((i) => q.options[i])
        .join('\n');
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final s = AppSemanticColors.of(context);
    final q = widget.answer.question;
    final explanation = q.explanation?.trim();
    final important = q.importantToKnow
            ?.where((e) => e.trim().isNotEmpty)
            .toList() ??
        const <String>[];

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: s.dangerFg),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => setState(() => _expanded = !_expanded),
        child: AnimatedSize(
          duration: motionDuration(context, const Duration(milliseconds: 220)),
          curve: Curves.easeInOut,
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Шапка: бейдж-крестик, текст вопроса, стрелка.
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _CrossBadge(color: s.dangerFg),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        q.text,
                        style: TextStyle(
                          fontSize: 14.5,
                          height: 1.4,
                          color: cs.onSurface,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    AnimatedRotation(
                      turns: _expanded ? 0.25 : 0,
                      duration: motionDuration(
                        context,
                        const Duration(milliseconds: 220),
                      ),
                      child: Icon(
                        Icons.arrow_forward,
                        size: 20,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                if (_expanded) ...[
                  if (_correctAnswer.isNotEmpty)
                    _Section(
                      label: 'Правильный ответ',
                      child: _bodyText(context, _correctAnswer),
                    ),
                  if (explanation != null && explanation.isNotEmpty)
                    _Section(
                      label: 'Почему',
                      child: _bodyText(context, explanation),
                    ),
                  if (important.isNotEmpty)
                    _Section(
                      label: 'Что ещё важно знать',
                      child: _Bullets(items: important, marker: cs.primary),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _bodyText(BuildContext context, String text) {
    final cs = Theme.of(context).colorScheme;
    return Text(
      text,
      style: TextStyle(
        fontSize: 13.5,
        height: 1.5,
        color: cs.onSurface,
      ),
    );
  }
}

/// Красный квадрат-бейдж с крестиком — маркер неверного ответа из макета.
class _CrossBadge extends StatelessWidget {
  const _CrossBadge({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(7),
      ),
      child: const Icon(Icons.close, size: 15, color: Colors.white),
    );
  }
}

/// Подпись-секция «ПОЧЕМУ»/«ПРАВИЛЬНЫЙ ОТВЕТ» с контентом под ней.
class _Section extends StatelessWidget {
  const _Section({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final s = AppSemanticColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              letterSpacing: 1.1,
              fontWeight: FontWeight.w500,
              color: s.mutedForeground,
            ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

/// Маркированный список «Что ещё важно знать» с розовыми квадратами-точками.
class _Bullets extends StatelessWidget {
  const _Bullets({required this.items, required this.marker});

  final List<String> items;
  final Color marker;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < items.length; i++)
          Padding(
            padding: EdgeInsets.only(top: i == 0 ? 0 : 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 6),
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: marker,
                    borderRadius: BorderRadius.circular(2.5),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    items[i],
                    style: TextStyle(
                      fontSize: 13.5,
                      height: 1.45,
                      color: cs.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_outline, size: 48, color: color),
            const SizedBox(height: 12),
            Text(
              'Ошибок нет — все ответы верны',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: color),
            ),
          ],
        ),
      ),
    );
  }
}
