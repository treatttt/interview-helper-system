import 'package:flutter/foundation.dart';
import '../models/models.dart';

enum AnswerOutcome { correct, partial, wrong }

class AnsweredQuestion {
  final Question question;
  final Set<int> selected;
  final AnswerOutcome outcome;
  const AnsweredQuestion({
    required this.question,
    required this.selected,
    required this.outcome,
  });
}

/// Разбивка вопросов по категориям и итоговые баллы
class SessionResult {
  final int correct;
  final int partial;
  final int wrong;
  final int points;
  final int maxPoints;
  final List<AnsweredQuestion> answers;

  /// ID вопросов, отвеченных верно в этой сессии.
  /// Используется ProgressService для обновления множества освоенных вопросов.
  final Set<String> correctIds;

  const SessionResult({
    required this.correct,
    required this.partial,
    required this.wrong,
    required this.points,
    required this.maxPoints,
    required this.answers,
    this.correctIds = const {},
  });
}

/// Управляет прохождением одной сессии вопросов.
class SessionController extends ChangeNotifier {
  final List<Question> _questions;

  SessionController(this._questions)
      : assert(_questions.isNotEmpty, 'Сессия требует хотя бы один вопрос');

  /// Восстановить контроллер из сохранённого состояния незавершённой сессии.
  SessionController.resume({
    required List<Question> questions,
    required int startIndex,
    required List<AnsweredQuestion> previousAnswers,
  })  : assert(questions.isNotEmpty, 'Сессия требует хотя бы один вопрос'),
        _questions = questions {
    _index = startIndex;
    for (final a in previousAnswers) {
      final correctSet = a.question.correctIndexes.toSet();
      final hit = a.selected.intersection(correctSet).length;
      _points += hit;
      _maxPoints += correctSet.length;
      switch (a.outcome) {
        case AnswerOutcome.correct:
          _correct++;
          break;
        case AnswerOutcome.partial:
          _partial++;
          break;
        case AnswerOutcome.wrong:
          _wrong++;
          break;
      }
      _answers.add(a);
    }
  }

  int _index = 0;
  final Set<int> _selected = {};
  bool _answered = false;

  int _correct = 0;
  int _partial = 0;
  int _wrong = 0;
  int _points = 0;
  int _maxPoints = 0;
  final List<AnsweredQuestion> _answers = [];

  Question get current => _questions[_index];
  int get index => _index;
  int get total => _questions.length;
  Set<int> get selected => _selected;
  bool get answered => _answered;
  bool get isLast => _index == _questions.length - 1;

  /// Все уже данные ответы (для сериализации незавершённой сессии).
  List<AnsweredQuestion> get answers => List.unmodifiable(_answers);

  void toggle(int option) {
    if (_answered) return;
    if (current.isMultipleChoice) {
      _selected.contains(option)
          ? _selected.remove(option)
          : _selected.add(option);
    } else {
      _selected
        ..clear()
        ..add(option);
    }
    notifyListeners();
  }

  void submit() {
    if (_answered || _selected.isEmpty) return;
    final correctSet = current.correctIndexes.toSet();
    final hit = _selected.intersection(correctSet).length;

    _points += hit;
    _maxPoints += correctSet.length;

    final AnswerOutcome outcome;
    if (_selected.length == correctSet.length && hit == correctSet.length) {
      _correct++;
      outcome = AnswerOutcome.correct;
    } else if (hit > 0) {
      _partial++;
      outcome = AnswerOutcome.partial;
    } else {
      _wrong++;
      outcome = AnswerOutcome.wrong;
    }

    _answers.add(AnsweredQuestion(
      question: current,
      selected: {..._selected},
      outcome: outcome,
    ));

    _answered = true;
    notifyListeners();
  }

  bool next() {
    if (!_answered) return true;
    if (isLast) return false;
    _index++;
    _selected.clear();
    _answered = false;
    notifyListeners();
    return true;
  }

  SessionResult get result => SessionResult(
        correct: _correct,
        partial: _partial,
        wrong: _wrong,
        points: _points,
        maxPoints: _maxPoints,
        answers: List.unmodifiable(_answers),
        correctIds: _answers
            .where((a) => a.outcome == AnswerOutcome.correct)
            .map((a) => a.question.id)
            .toSet(),
      );
}
