import 'package:flutter/foundation.dart';
import 'package:interview_helper_system/controllers/session_controller.dart'
    show AnswerOutcome, AnsweredQuestion;
import 'package:interview_helper_system/models/incomplete_session.dart';
import 'package:interview_helper_system/models/models.dart';
import 'package:interview_helper_system/services/progress_service.dart';

/// Готовый план запуска сессии с Главной: либо продолжение сохранённой паузы,
/// либо свежий старт рекомендованного грейда. Экран строит из него
/// сессию без знания о деталях резюма.
@immutable
class SessionLaunch {
  const SessionLaunch({
    required this.track,
    required this.grade,
    required this.questions,
    this.startIndex = 0,
    this.previousAnswers = const [],
    this.topicTitle,
  });

  final Track track;
  final Grade grade;
  final List<Question> questions;
  final int startIndex;
  final List<AnsweredQuestion> previousAnswers;

  /// Не null — это тема-дрилл (пауза пишется в тема-слот).
  final String? topicTitle;
}

/// Отображаемое состояние сохранённого «микса по слабым темам».
/// Микс — фиксированный набор из [total] вопросов; [mastered] из них уже
/// освоены (счётчик X/N), а [remaining] — ещё нерешённые (их и гоняет сессия).
@immutable
class PracticeMixView {
  const PracticeMixView({
    required this.total,
    required this.mastered,
    required this.remaining,
    required this.questionGradeKeys,
    this.repTrack,
    this.repGrade,
  });

  final int total;
  final int mastered;

  /// Нерешённые вопросы микса — что предъявит сессия.
  final List<Question> remaining;

  /// id → gradeKey для [remaining] (корректная запись прогресса по миксу).
  final Map<String, String> questionGradeKeys;

  /// Представительные трек/грейд (первого нерешённого вопроса) для конструктора
  /// сессии. null — когда нерешённых нет (микс пройден).
  final Track? repTrack;
  final Grade? repGrade;

  bool get isComplete => total > 0 && mastered >= total;
}

/// Данные карточки «Продолжить / Начать» на Главной.
@immutable
class ContinueCard {
  const ContinueCard({
    required this.title,
    required this.subtitle,
    required this.questionNumber,
    required this.questionTotal,
    required this.isResume,
    required this.launch,
  });

  /// Крупный заголовок: тема текущего вопроса (или направление при старте).
  final String title;

  /// Подзаголовок «Направление · Грейд».
  final String subtitle;

  /// Номер текущего вопроса (1-based). 0 — свежий старт, сессия не начата.
  final int questionNumber;
  final int questionTotal;

  /// true → «Продолжить» (есть пауза), false → «Начать» (рекомендация).
  final bool isResume;

  final SessionLaunch launch;

  /// Заполнение полосы — доля уже отвеченных вопросов, а не позиции текущего.
  /// Текущий вопрос ещё не отвечен, поэтому считаем `questionNumber - 1`
  /// (на последнем вопросе 2/2 это даёт 1/2, а не «полную» полосу). При свежем
  /// старте questionNumber == 0 → 0.
  double get progress => questionTotal == 0
      ? 0
      : ((questionNumber - 1).clamp(0, questionTotal) / questionTotal)
          .clamp(0.0, 1.0);
}

/// Разбиение направлений на «ваши» (начатые) и «другие».
@immutable
class DirectionSplit {
  const DirectionSplit({required this.yours, required this.others});
  final List<Track> yours;
  final List<Track> others;
}

/// Восстановленные из паузы аргументы сессии.
typedef _ResumeArgs = ({
  Track track,
  Grade grade,
  List<Question> questions,
  int startIndex,
  List<AnsweredQuestion> previousAnswers,
});

/// Чистая бизнес-логика Главной: что показать в карточке «Продолжить/Начать» и
/// как разложить направления. Не зависит от Flutter-виджетов — легко тестируется.
class HomeController {
  HomeController({required this.tracks, required this.progress});

  final List<Track> tracks;
  final ProgressService progress;

  /// Контентные направления (без языковых треков) в порядке [Track.order].
  List<Track> get _contentTracks {
    final list = tracks.where((t) => t.category != 'language').toList()
      ..sort((a, b) => a.order.compareTo(b.order));
    return list;
  }

  /// Карточка «Продолжить/Начать». null — если стартовать нечего
  /// (нет треков или всё освоено и нет пауз).
  ContinueCard? buildContinueCard() {
    return _resumeCard(progress.incompleteSession) ??
        _resumeCard(progress.incompleteTopicSession) ??
        _recommendCard();
  }

  /// Направления: начатые → «ваши», остальные → «другие». Если ничего не начато,
  /// рекомендованный трек поднимается в «ваши» (как в дизайне после онбординга).
  DirectionSplit splitDirections() {
    final content = _contentTracks;
    final yours = <Track>[];
    final others = <Track>[];
    for (final t in content) {
      (_isStarted(t) ? yours : others).add(t);
    }
    if (yours.isEmpty) {
      final rec = _recommendTarget();
      if (rec != null) {
        yours.add(rec.track);
        others.removeWhere((t) => t.id == rec.track.id);
      }
    }
    return DirectionSplit(yours: yours, others: others);
  }

  // ── Карточка из паузы ──────────────────────────────────────────────────────

  ContinueCard? _resumeCard(Map<String, Object?>? raw) {
    if (raw == null) return null;
    final _ResumeArgs args;
    final String? pausedTopic;
    try {
      final paused = IncompleteSession.fromJson(raw);
      final resolved = _resolveResume(paused);
      if (resolved == null) return null;
      args = resolved;
      pausedTopic = paused.topicTitle;
    } on Object {
      // Повреждённая/протухшая пауза — карточку из неё не строим.
      return null;
    }

    final current = args.startIndex < args.questions.length
        ? args.questions[args.startIndex]
        : null;
    final title = current?.topic ?? pausedTopic ?? args.grade.title;

    return ContinueCard(
      title: title,
      subtitle: '${args.track.title} · ${args.grade.title}',
      questionNumber: args.startIndex + 1,
      questionTotal: args.questions.length,
      isResume: true,
      launch: SessionLaunch(
        track: args.track,
        grade: args.grade,
        questions: args.questions,
        startIndex: args.startIndex,
        previousAnswers: args.previousAnswers,
        topicTitle: pausedTopic,
      ),
    );
  }

  /// Реконструирует сессию из паузы. null — если грейд/вопросы не нашлись
  /// (данные каталога изменились) → пауза считается протухшей.
  _ResumeArgs? _resolveResume(IncompleteSession paused) {
    final loc = _findGrade(paused.gradeKey);
    if (loc == null) return null;

    final byId = {for (final q in loc.grade.questions) q.id: q};
    final questions =
        paused.questionIds.map((id) => byId[id]).whereType<Question>().toList();
    // Не нашлись все вопросы или их вовсе нет (пустой/битый слот) — пауза
    // протухла. Пустой список важно отсечь до clamp(0, length - 1): при length
    // == 0 это clamp(0, -1) и ArgumentError.
    if (questions.isEmpty || questions.length != paused.questionIds.length) {
      return null;
    }

    final previous = <AnsweredQuestion>[];
    for (final d in paused.answeredData) {
      final q = byId[d.id];
      if (q == null) return null;
      previous.add(
        AnsweredQuestion(
          question: q,
          selected: d.selected.toSet(),
          outcome: AnswerOutcome.values.byName(d.outcome),
        ),
      );
    }

    final start = paused.currentIndex.clamp(0, questions.length - 1);
    return (
      track: loc.track,
      grade: loc.grade,
      questions: questions,
      startIndex: start,
      previousAnswers: previous,
    );
  }

  // ── Микс по слабым темам ───────────────────────────────────────────────────

  /// Сгенерировать новый набор id для микса: до [size] непройденных вопросов,
  /// сбалансированно (по кругу) разобранных из слабых тем. null — если слабых
  /// тем с вопросами меньше двух (микс не из чего/незачем собирать).
  List<String>? generateMix({int size = ProgressService.practiceMixSize}) {
    final candidates = _weakTopicCandidates();
    if (candidates.length < 2) return null;

    // Перемешиваем пул каждой темы и разбираем по кругу — поровну с каждой.
    final pools = [for (final l in candidates.values) [...l]..shuffle()];
    final chosen = <String>[];
    var added = true;
    while (chosen.length < size && added) {
      added = false;
      for (final pool in pools) {
        if (chosen.length >= size) break;
        if (pool.isNotEmpty) {
          chosen.add(pool.removeLast().q.id);
          added = true;
        }
      }
    }
    if (chosen.isEmpty) return null;
    return chosen..shuffle();
  }

  /// Состояние сохранённого микса: освоено X из N, что осталось решать.
  /// null — если микса нет или его вопросы исчезли из каталога (нужна
  /// перегенерация).
  PracticeMixView? practiceMixView() {
    final mix = progress.practiceMix;
    if (mix.isEmpty) return null;

    final lookup = <String, ({Question q, Track track, Grade grade})>{};
    for (final track in tracks) {
      for (final grade in track.grades) {
        for (final q in grade.questions) {
          lookup[q.id] = (q: q, track: track, grade: grade);
        }
      }
    }

    final remaining = <Question>[];
    final keys = <String, String>{};
    Track? repTrack;
    Grade? repGrade;
    var mastered = 0;

    for (final id in mix) {
      final found = lookup[id];
      if (found == null) return null; // каталог изменился — микс невалиден.
      final isMastered =
          progress.masteredIds(found.track.id, found.grade.id).contains(id);
      if (isMastered) {
        mastered++;
      } else {
        remaining.add(found.q);
        keys[id] = '${found.track.id}_${found.grade.id}';
        repTrack ??= found.track;
        repGrade ??= found.grade;
      }
    }

    return PracticeMixView(
      total: mix.length,
      mastered: mastered,
      remaining: remaining,
      questionGradeKeys: keys,
      repTrack: repTrack,
      repGrade: repGrade,
    );
  }

  /// Названия тем, где у пользователя есть ошибки (accuracy < 1, ≥1 попытка).
  Set<String> _weakTopicTitles() => progress
      .weakestTopics(limit: 1 << 30)
      .where((t) => t.correct < t.attempts)
      .map((t) => t.title)
      .toSet();

  /// Слабые темы → их непройденные валидные вопросы (с треком/грейдом) в
  /// контентных треках. Темы без доступных вопросов не попадают.
  Map<String, List<({Question q, Track track, Grade grade})>>
      _weakTopicCandidates() {
    final weak = _weakTopicTitles();
    final byTopic = <String, List<({Question q, Track track, Grade grade})>>{};
    if (weak.isEmpty) return byTopic;

    for (final track in _contentTracks) {
      for (final grade in track.grades) {
        final mastered = progress.masteredIds(track.id, grade.id);
        for (final q in grade.questions) {
          final topic = q.topic;
          if (topic == null || !weak.contains(topic)) continue;
          if (!q.isValid || mastered.contains(q.id)) continue;
          (byTopic[topic] ??= []).add((q: q, track: track, grade: grade));
        }
      }
    }
    return byTopic;
  }

  ContinueCard? _recommendCard() {
    final target = _recommendTarget();
    if (target == null) return null;
    final (:track, :grade, :remaining) = target;

    String? topic;
    for (final q in remaining) {
      final t = q.topic;
      if (t != null && t.isNotEmpty) {
        topic = t;
        break;
      }
    }

    return ContinueCard(
      title: topic ?? track.title,
      subtitle: '${track.title} · ${grade.title}',
      questionNumber: 0,
      questionTotal: remaining.length,
      isResume: false,
      launch: SessionLaunch(
        track: track,
        grade: grade,
        questions: remaining,
      ),
    );
  }

  /// Цель рекомендации: первый (по порядку грейдов) грейд с непройденными
  /// вопросами. Приоритет — грейд, где есть вопрос из слабейшей темы.
  ({Track track, Grade grade, List<Question> remaining})? _recommendTarget() {
    final weak = progress.weakestTopics(limit: 1);
    final weakTopic = weak.isNotEmpty ? weak.first.title : null;

    ({Track track, Grade grade, List<Question> remaining})? firstAny;

    for (final track in _contentTracks) {
      final grades = [...track.grades]
        ..sort((a, b) => a.order.compareTo(b.order));
      for (final grade in grades) {
        final mastered = progress.masteredIds(track.id, grade.id);
        final remaining = grade.questions
            .where((q) => q.isValid && !mastered.contains(q.id))
            .toList();
        if (remaining.isEmpty) continue;

        final hit = (track: track, grade: grade, remaining: remaining);
        firstAny ??= hit;
        if (weakTopic != null && remaining.any((q) => q.topic == weakTopic)) {
          return hit;
        }
      }
    }
    return firstAny;
  }

  // ── Вспомогательное ────────────────────────────────────────────────────────

  bool _isStarted(Track track) {
    for (final g in track.grades) {
      if (progress.masteredIds(track.id, g.id).isNotEmpty) return true;
    }
    final gradeKey = progress.incompleteSession?['gradeKey'];
    return gradeKey is String && gradeKey.startsWith('${track.id}_');
  }

  ({Track track, Grade grade})? _findGrade(String gradeKey) {
    for (final track in tracks) {
      for (final grade in track.grades) {
        if ('${track.id}_${grade.id}' == gradeKey) {
          return (track: track, grade: grade);
        }
      }
    }
    return null;
  }
}
