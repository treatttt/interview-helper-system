import 'dart:async';

import 'package:flutter/material.dart';
import 'package:interview_helper_system/controllers/session_controller.dart';
import 'package:interview_helper_system/models/incomplete_session.dart';
import 'package:interview_helper_system/models/models.dart';
import 'package:interview_helper_system/screens/result_screen.dart';
import 'package:interview_helper_system/services/progress_service.dart';
import 'package:interview_helper_system/theme.dart';
import 'package:interview_helper_system/utils/motion.dart';
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
    this.topicTitle,
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

  /// Если задано — это тема-дрилл по [topicTitle]: пауза пишется в тема-слот
  /// (по названию темы), грейдовый слот не трогается, на финише грейдовая пауза
  /// не сбрасывается. null — обычная полногрейдовая сессия (пауза в грейдовом
  /// слоте по gradeKey).
  final String? topicTitle;

  @override
  State<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends State<SessionScreen> {
  late final SessionController _controller;
  bool _finishing = false;

  bool get _isTopicDrill => widget.topicTitle != null;
  String get _gradeKey => '${widget.track.id}_${widget.grade.id}';

  @override
  void initState() {
    super.initState();
    _controller = widget.previousAnswers.isEmpty && widget.initialIndex == 0
        ? SessionController(widget.questions)
        : SessionController.resume(
      questions: widget.questions,
      startIndex: widget.initialIndex,
      previousAnswers: widget.previousAnswers,
    );
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
    final c = _controller;
    // Сохраняем только если хотя бы один вопрос отвечен и сессия не завершена.
    if (c.answers.isEmpty || c.answers.length >= c.total) return;

    final session = IncompleteSession(
      gradeKey: _gradeKey,
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
      topicTitle: widget.topicTitle,
    );

    if (_isTopicDrill) {
      widget.progress.saveIncompleteTopicSessionSync(session.toJson());
    } else {
      widget.progress.saveIncompleteSessionSync(session.toJson());
    }
  }

  void _onNext() {
    if (_finishing) return;
    final hasMore = _controller.next();
    if (!hasMore) {
      _finishing = true;
      // Берём navigator и роут из context ДО вызовов, возвращающих Future
      // (recordSession/clearIncompleteTopicSession), чтобы не трогать
      // BuildContext после возможного async-гэпа.
      final navigator = Navigator.of(context);
      final route = fadeThroughRoute<void>(
        context,
        ResultScreen(
          result: _controller.result,
          track: widget.track,
          grade: widget.grade,
          progress: widget.progress,
        ),
        name: 'Результат',
      );
      // Тема-дрилл не трогает грейдовую паузу (clearIncomplete: false), но чистит
      // свой тема-слот; полногрейдовая сессия чистит грейдовый слот.
      unawaited(
        widget.progress.recordSession(
          _gradeKey,
          _controller.result,
          clearIncomplete: !_isTopicDrill,
        ),
      );
      if (_isTopicDrill) {
        unawaited(
          widget.progress
              .clearIncompleteTopicSession(topicTitle: widget.topicTitle),
        );
      }
      unawaited(navigator.pushReplacement(route));
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
                      // Прогресс-бар и чип трека статичны — анимируем только
                      // содержимое вопроса при смене индекса.
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
                      // Кросс-фейд между вопросами. Ключ — индекс вопроса:
                      // смена индекса → переход; фиксация ответа (тот же индекс)
                      // обновляет подсветку мгновенно, без анимации. Уважает
                      // reduce-motion через motionDuration.
                      AnimatedSwitcher(
                        // Длительность — главный (и единственный) рычаг видимости чистого фейда.
                        // 350мс читается заметно; 220мс глаз почти не ловит.
                        duration: motionDuration(
                          context, const Duration(milliseconds: 350),),
                        switchInCurve: Curves.easeInOut,
                        switchOutCurve: Curves.easeInOut,
                        transitionBuilder: (child, animation) =>
                            FadeTransition(opacity: animation, child: child),
                        child: _questionBlock(c),
                      ),
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
                      onPressed: _primaryAction(c),
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

  /// Содержимое одного вопроса (текст, варианты, пояснение). Обёрнуто ключом по
  /// индексу — это то, что кросс-фейдит [AnimatedSwitcher] при смене вопроса.
  Widget _questionBlock(SessionController c) {
    return Column(
      key: ValueKey(c.index),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (c.current.isMultipleChoice && !c.answered)
          const Padding(
            padding: EdgeInsets.only(bottom: 6),
            child: Text(
              'Можно выбрать несколько вариантов',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ),
        const SizedBox(height: 6),
        Text(
          c.current.text,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w500,
            height: 1.4,
          ),
        ),
        if (c.current.codeSnippet != null &&
            c.current.codeSnippet!.isNotEmpty) ...[
          const SizedBox(height: 14),
          _codeBlock(c.current.codeSnippet!),
        ],
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
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              c.current.explanation!,
              style: const TextStyle(fontSize: 13, height: 1.5),
            ),
          ),
        ],
      ],
    );
  }

  String _buttonLabel(SessionController c) {
    if (!c.answered) return 'Ответить';
    return c.isLast ? 'Завершить' : 'Дальше';
  }

  /// Действие основной кнопки: после ответа — переход дальше; до ответа —
  /// фиксация (или null, пока ничего не выбрано → кнопка неактивна).
  VoidCallback? _primaryAction(SessionController c) {
    if (c.answered) return _onNext;
    if (c.selected.isEmpty) return null;
    return c.submit;
  }

  Widget _codeBlock(String code) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.all(14),
        child: Text(
          code,
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 13,
            height: 1.5,
          ),
        ),
      ),
    );
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
