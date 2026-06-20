import 'package:flutter/material.dart';
import 'package:interview_helper_system/controllers/session_controller.dart';
import 'package:interview_helper_system/models/incomplete_session.dart';
import 'package:interview_helper_system/models/models.dart';
import 'package:interview_helper_system/screens/result_screen.dart';
import 'package:interview_helper_system/services/progress_service.dart';
import 'package:interview_helper_system/theme.dart';
import 'package:interview_helper_system/utils/option_highlight.dart';

class SessionScreen extends StatefulWidget {
  const SessionScreen({
    required this.track,
    required this.grade,
    required this.progress,
    required this.questions,
    super.key,
    this.initialIndex = 0,
    this.previousAnswers = const [],
    this.persistIncomplete = true,
  });
  final Track track;
  final Grade grade;
  final ProgressService progress;

  /// Отфильтрованный список вопросов для сессии (без уже освоенных).
  final List<Question> questions;

  /// Индекс вопроса, с которого начинать (для resume).
  final int initialIndex;

  /// Уже отвеченные вопросы из предыдущей части сессии (для resume).
  final List<AnsweredQuestion> previousAnswers;

  /// Сохранять ли незавершённое состояние в слот грейда.
  /// false — для коротких тема-дриллов: они не резюмируются и не трогают
  /// единственный слот незавершённой сессии грейда.
  final bool persistIncomplete;

  @override
  State<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends State<SessionScreen> {
  late final SessionController _controller;
  bool _finishing = false;

  @override
  void initState() {
    super.initState();
    if (widget.previousAnswers.isEmpty && widget.initialIndex == 0) {
      _controller = SessionController(widget.questions);
    } else {
      _controller = SessionController.resume(
        questions: widget.questions,
        startIndex: widget.initialIndex,
        previousAnswers: widget.previousAnswers,
      );
    }
  }

  @override
  void dispose() {
    if (!_finishing) {
      _saveIncompleteSession();
    }
    _controller.dispose();
    super.dispose();
  }

  /// Сохранить состояние сессии при выходе без завершения.
  void _saveIncompleteSession() {
    // Тема-дрилл (persistIncomplete: false) не сохраняется и не трогает слот.
    if (!widget.persistIncomplete) return;
    final c = _controller;
    // Сохраняем только если хотя бы один вопрос отвечен и сессия не завершена.
    if (c.answers.isEmpty || c.answers.length >= c.total) return;

    final session = IncompleteSession(
      gradeKey: '${widget.track.id}_${widget.grade.id}',
      questionIds: widget.questions.map((q) => q.id).toList(),
      currentIndex: c.answers.length,
      answeredData: c.answers
          .map(
            (a) => AnsweredItemData(
              id: a.question.id,
              selected: a.selected.toList(),
              outcome: a.outcome.name,
            ),
          )
          .toList(),
    );
    widget.progress.saveIncompleteSessionSync(session.toJson());
  }

  void _onNext() {
    if (_finishing) return;
    final hasMore = _controller.next();
    if (!hasMore) {
      _finishing = true;
      final sessionKey = '${widget.track.id}_${widget.grade.id}';
      widget.progress.recordSession(
        sessionKey,
        _controller.result,
        clearIncomplete: widget.persistIncomplete,
      );
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => ResultScreen(
            result: _controller.result,
            track: widget.track,
            grade: widget.grade,
            progress: widget.progress,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final c = _controller;
        return Scaffold(
          appBar: AppBar(title: Text('${c.index + 1} / ${c.total}')),
          body: Column(
            children: [
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
                          backgroundColor: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${widget.track.title} · ${widget.grade.title}',
                          style: TextStyle(
                            fontSize: 11,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (c.current.isMultipleChoice && !c.answered)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 6),
                          child: Text('Можно выбрать несколько вариантов',
                            style: TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                        ),
                      const SizedBox(height: 6),
                      Text(c.current.text,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w500,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 18),
                      ...List.generate(
                        c.current.options.length,
                        (i) => _optionTile(c, i),
                      ),
                      if (c.answered &&
                          c.current.explanation != null &&
                          c.current.explanation!.trim().isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(c.current.explanation!,
                            style: const TextStyle(fontSize: 13, height: 1.5),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
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
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
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
    final cs = Theme.of(context).colorScheme;
    final s = AppSemanticColors.of(context);
    final correct = c.current.correctIndexes.contains(i);
    final picked = c.selected.contains(i);

    var bg = cs.surface;
    var border = cs.outlineVariant;
    var text = cs.onSurface;

    if (!c.answered) {
      if (picked) {
        bg = cs.primaryContainer;
        border = cs.primary;
        text = cs.onPrimaryContainer;
      }
    } else {
      switch (resolveOptionHighlight(
        isCorrect: correct,
        isPicked: picked,
        isMultiChoice: c.current.isMultipleChoice,
      )) {
        case OptionHighlight.correct:
          bg = s.successBg;
          border = s.successBorder;
          text = s.successFg;
        case OptionHighlight.missed:
          bg = s.warningBg;
          border = s.warningBorder;
          text = s.warningFg;
        case OptionHighlight.wrong:
          bg = s.dangerBg;
          border = s.dangerBorder;
          text = s.dangerFg;
        case OptionHighlight.neutral:
          break; // остаётся цвет поверхности
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
            style: TextStyle(color: text, fontSize: 14),
          ),
        ),
      ),
    );
  }
}