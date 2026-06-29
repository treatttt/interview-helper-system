import 'dart:async';

import 'package:flutter/material.dart';
import 'package:interview_helper_system/controllers/session_controller.dart';
import 'package:interview_helper_system/models/incomplete_session.dart';
import 'package:interview_helper_system/models/models.dart';
import 'package:interview_helper_system/screens/result_screen.dart';
import 'package:interview_helper_system/services/progress_service.dart';
import 'package:interview_helper_system/theme.dart';
import 'package:interview_helper_system/utils/motion.dart';

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
    this.questionGradeKeys,
  });
  final Track track;
  final Grade grade;
  final ProgressService progress;

  /// Если задано — это «микс по слабым темам»: вопросы принадлежат разным
  /// грейдам (questionId → gradeKey). Прогресс пишется через
  /// [ProgressService.recordMixedSession], пауза не сохраняется. null — обычная
  /// сессия одного грейда. [track]/[grade] в режиме микса лишь представительные.
  final Map<String, String>? questionGradeKeys;

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

  /// Момент открытия экрана — для метрики «в сессии» на экране результата.
  final DateTime _startedAt = DateTime.now();

  bool get _isTopicDrill => widget.topicTitle != null;
  bool get _isMix => widget.questionGradeKeys != null;
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
    // Микс охватывает несколько грейдов — на паузу не сохраняется.
    if (_isMix) return;
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
          questionGradeKeys: widget.questionGradeKeys,
          elapsed: DateTime.now().difference(_startedAt),
        ),
        name: 'Результат',
      );
      if (_isMix) {
        // Микс охватывает несколько грейдов — раскладываем верные по их ключам.
        unawaited(
          widget.progress.recordMixedSession(
            _controller.result,
            widget.questionGradeKeys!,
          ),
        );
      } else {
        // Тема-дрилл не трогает грейдовую паузу (clearIncomplete: false), но
        // чистит свой тема-слот; полногрейдовая сессия чистит грейдовый слот.
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

  /// Содержимое одного вопроса. До ответа — текст/код/варианты; после ответа —
  /// окно обратной связи (бейдж, правильный ответ, «Почему», «Важно знать» или
  /// «Нужно повторить»). Обёрнуто ключом по индексу — это и кросс-фейдит
  /// [AnimatedSwitcher] при смене вопроса.
  Widget _questionBlock(SessionController c) {
    final q = c.current;
    return Column(
      key: ValueKey(c.index),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (q.isMultipleChoice && !c.answered)
          const Padding(
            padding: EdgeInsets.only(bottom: 6),
            child: Text(
              'Можно выбрать несколько вариантов',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ),
        const SizedBox(height: 6),
        Text(
          q.text,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w500,
            height: 1.4,
          ),
        ),
        if (q.codeSnippet != null && q.codeSnippet!.isNotEmpty) ...[
          const SizedBox(height: 14),
          _codeBlock(q.codeSnippet!),
        ],
        const SizedBox(height: 18),
        if (!c.answered)
          ...List.generate(q.options.length, (i) => _optionTile(c, i))
        else
          _feedbackBlock(c),
      ],
    );
  }

  /// Окно обратной связи после ответа. Верно → ✓ «Верно» и «+10 XP»;
  /// неверно → ✗ «Неверно» без XP. В обоих случаях — правильный ответ в рамке
  /// (зелёной/красной) без крестика, чтобы не путать, плюс «Почему» и блок
  /// «Важно знать» (верно) либо «Нужно повторить» (неверно) из данных вопроса.
  Widget _feedbackBlock(SessionController c) {
    final q = c.current;
    final s = AppSemanticColors.of(context);
    // Верность считаем напрямую из текущего вопроса и выбора — без обращения к
    // c.answers.last (тот бросает на пустом списке и завязан на порядок записей).
    // «Верно» = выбран ровно набор правильных индексов, без лишних и пропусков.
    final correctSet = q.correctIndexes.toSet();
    final isCorrect = c.selected.length == correctSet.length &&
        c.selected.containsAll(correctSet);

    final fg = isCorrect ? s.successFg : s.dangerFg;
    final bg = isCorrect ? s.successBg : s.dangerBg;
    final border = isCorrect ? s.successBorder : s.dangerBorder;

    final hint = isCorrect ? q.importantToKnow : q.mustRepeat;
    final hintLabel = isCorrect ? 'Важно знать' : 'Нужно повторить';
    final hasExplanation =
        q.explanation != null && q.explanation!.trim().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              isCorrect ? Icons.check_circle : Icons.cancel,
              color: fg,
              size: 22,
            ),
            const SizedBox(width: 8),
            Text(
              isCorrect ? 'Верно' : 'Неверно',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: fg,
              ),
            ),
            const Spacer(),
            if (isCorrect)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: s.successBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '+10 XP',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: s.successFg,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 14),
        // Правильный ответ(ы). В рамке — только верный вариант и галочка
        // (никакого крестика), чтобы пользователь не принял его за неверный.
        for (final i in q.correctIndexes)
          _answerBox(q.options[i], fg: fg, bg: bg, border: border),
        if (hasExplanation) ...[
          const SizedBox(height: 16),
          _feedbackLabel('Почему'),
          const SizedBox(height: 6),
          Text(q.explanation!, style: const TextStyle(fontSize: 13, height: 1.5)),
        ],
        if (hint != null && hint.isNotEmpty) ...[
          const SizedBox(height: 16),
          _feedbackLabel(hintLabel),
          const SizedBox(height: 8),
          for (final point in hint) _bullet(point),
        ],
      ],
    );
  }

  Widget _answerBox(
    String text, {
    required Color fg,
    required Color bg,
    required Color border,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.check, size: 18, color: fg),
            const SizedBox(width: 10),
            Expanded(
              child: Text(text, style: TextStyle(color: fg, fontSize: 14)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _feedbackLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        letterSpacing: 0.3,
      ),
    );
  }

  Widget _bullet(String text) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 7, right: 8),
            child: Container(
              width: 5,
              height: 5,
              decoration:
                  BoxDecoration(color: cs.onSurfaceVariant, shape: BoxShape.circle),
            ),
          ),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 13, height: 1.45)),
          ),
        ],
      ),
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

  /// Вариант ответа до фиксации: подсвечивается только выбор. Подсветка
  /// верный/неверный после ответа больше не нужна — её заменило окно
  /// обратной связи ([_feedbackBlock]).
  Widget _optionTile(SessionController c, int i) {
    final cs = Theme.of(context).colorScheme;
    final picked = c.selected.contains(i);

    final bg = picked ? cs.primaryContainer : cs.surface;
    final border = picked ? cs.primary : cs.outlineVariant;
    final text = picked ? cs.onPrimaryContainer : cs.onSurface;

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
