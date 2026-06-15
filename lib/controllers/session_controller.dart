import 'package:flutter/foundation.dart';
import '../models/models.dart';

enum AnswerOutcome { correct, partial, wrong }

class AnsweredQuestion {
  final Question
  question; // сам вопрос: текст, options, correctIndexes, explanation
  final Set<int> selected; // что выбрал пользователь
  final AnswerOutcome outcome; // вердикт — чтобы экран не пересчитывал логику
  const AnsweredQuestion({
    required this.question,
    required this.selected,
    required this.outcome,
  });
}

/// Разбивка вопросов по категориям и итоговые баллы
class SessionResult {
  final int correct; // верно
  final int partial; // частично верно
  final int wrong; // неверно
  final int points; // итого баллов
  final int maxPoints; // максимум баллов за сессию
  final List<AnsweredQuestion> answers; // вся сессия для разбора

  const SessionResult({
    required this.correct,
    required this.partial,
    required this.wrong,
    required this.points,
    required this.maxPoints,
    required this.answers,
  });
}

/// Управляет прохождением одной сессии вопросв
/// Держит состояние вне виджета,
/// чтобы экран только рисовал, а логика жила здесь и была тестируемой
class SessionController extends ChangeNotifier {
  final List<Question> _questions;

  SessionController(this._questions);

  int _index = 0;
  final Set<int> _selected = {};
  bool _answered = false;

  // Накопленные итоги
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

  // Отметить/снять варинт Множественный вопрос — переключаем (можно несколько),
  // одиночный — заменяем выбор
  void toggle(int option) {
    if (_answered) return; // после фиксации ответа выбор не меняем
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

  /// Зафиксировать ответ и определить тип вопроса
  void submit() {
    if (_answered || _selected.isEmpty) return;
    final correctSet = current.correctIndexes.toSet();
    final hit = _selected
        .intersection(correctSet)
        .length;

    _points += hit;
    _maxPoints += correctSet.length;

    // +1 к счётчику и запоминаем, КАКАЯ это категория
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

    // сохраняем этот вопрос целиком для разбора
    _answers.add(AnsweredQuestion(
      question: current,
      selected: {..._selected}, // копия, не ссылка!
      outcome: outcome,
    ));

    _answered = true;
    notifyListeners();
  }

  /// Следующий вопрос, false - когда конец
  bool next() {
    if (!_answered) return true; // без ответа нельзя листать
    if (isLast) return false;
    _index++;
    _selected.clear();
    _answered = false;
    notifyListeners();
    return true;
  }

  /// Итог сессии
  SessionResult get result =>
      SessionResult(
        correct: _correct,
        partial: _partial,
        wrong: _wrong,
        points: _points,
        maxPoints: _maxPoints,
        answers: _answers,);
}
