import 'package:flutter/material.dart';
import 'package:interview_helper_system/controllers/home_controller.dart';
import 'package:interview_helper_system/models/models.dart';
import 'package:interview_helper_system/screens/grades_screen.dart';
import 'package:interview_helper_system/screens/session_screen.dart';
import 'package:interview_helper_system/screens/tracks_loader.dart';
import 'package:interview_helper_system/services/progress_service.dart';
import 'package:interview_helper_system/services/question_repository.dart';
import 'package:interview_helper_system/utils/ru_format.dart';
import 'package:interview_helper_system/utils/tap_lock.dart';
import 'package:interview_helper_system/utils/track_visuals.dart';

/// Главная: шапка с датой и серией, карточка «Продолжить/Начать», дневная цель
/// и список направлений («ваши» / «другие»).
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    required this.repository,
    required this.progress,
    this.clock,
    super.key,
  });
  final QuestionRepository repository;
  final ProgressService progress;

  /// Источник «сейчас» для шапки-даты. По умолчанию [DateTime.now].
  final DateTime Function()? clock;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with TracksLoader<HomeScreen>, TapLock<HomeScreen> {
  @override
  QuestionRepository get repository => widget.repository;

  @override
  String get loadErrorMessage => 'Не удалось загрузить вопросы';

  DateTime get _now => (widget.clock ?? DateTime.now)();

  // ── Navigation helpers ──────────────────────────────────────────────────

  /// Запуск сессии из карточки «Продолжить/Начать». Пуш await-ится — лок
  /// держится до закрытия сессии (защита от двойного тапа).
  void _launch(SessionLaunch l) => guardTap(
        () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            settings: const RouteSettings(name: 'Вопросы'),
            builder: (_) => SessionScreen(
              track: l.track,
              grade: l.grade,
              questions: l.questions,
              progress: widget.progress,
              initialIndex: l.startIndex,
              previousAnswers: l.previousAnswers,
              topicTitle: l.topicTitle,
            ),
          ),
        ),
      );

  Future<void> _pushGrades(Track track) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: 'Грейды'),
        builder: (_) => GradesScreen(track: track, progress: widget.progress),
      ),
    );
  }

  // ── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: error != null
            ? ErrorRetryView(title: loadErrorMessage, onRetry: retryLoad)
            : ListenableBuilder(
                listenable: widget.progress,
                builder: (context, _) {
                  final controller = HomeController(
                    tracks: tracks,
                    progress: widget.progress,
                  );
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                    children: _content(controller),
                  );
                },
              ),
      ),
    );
  }

  List<Widget> _content(HomeController controller) {
    if (loading) {
      return [
        _header(),
        const SizedBox(height: 48),
        const Center(child: CircularProgressIndicator()),
      ];
    }

    final card = controller.buildContinueCard();
    final split = controller.splitDirections();

    return [
      _header(),
      const SizedBox(height: 20),
      if (card != null) ...[
        _ContinueCardView(card: card, onLaunch: () => _launch(card.launch)),
        const SizedBox(height: 12),
      ],
      _DailyGoalCard(
        answered: widget.progress.answeredToday,
        goal: ProgressService.dailyGoal,
      ),
      const SizedBox(height: 24),
      _sectionLabel('Ваши направления'),
      const SizedBox(height: 8),
      _directionsCard(split.yours),
      if (split.others.isNotEmpty) ...[
        const SizedBox(height: 20),
        _sectionLabel('Другие направления'),
        const SizedBox(height: 8),
        _directionsCard(split.others),
      ],
    ];
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _header() {
    final cs = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                formatRuDateHeader(_now),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.1,
                  color: cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'Главная',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        _StreakBadge(streak: widget.progress.streak),
      ],
    );
  }

  // ── Directions ──────────────────────────────────────────────────────────

  Widget _sectionLabel(String text) {
    final cs = Theme.of(context).colorScheme;
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: cs.onSurfaceVariant,
        letterSpacing: 0.6,
      ),
    );
  }

  Widget _directionsCard(List<Track> list) {
    final cs = Theme.of(context).colorScheme;
    if (list.isEmpty) return const SizedBox.shrink();
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        children: [
          for (var i = 0; i < list.length; i++) ...[
            if (i > 0)
              Divider(height: 1, thickness: 1, indent: 64, color: cs.outlineVariant),
            _trackRow(list[i]),
          ],
        ],
      ),
    );
  }

  Widget _trackRow(Track track) {
    final cs = Theme.of(context).colorScheme;
    final visual = trackVisual(track.id, cs);
    final hasAnyValid =
        track.grades.any((g) => g.questions.any((q) => q.isValid));
    final total = track.grades.fold<int>(0, (s, g) => s + g.questions.length);
    final mastered = track.grades.fold<int>(
      0,
      (s, g) => s + widget.progress.masteredIds(track.id, g.id).length,
    );
    final fraction = total == 0 ? 0.0 : mastered / total;

    return InkWell(
      onTap: hasAnyValid ? () => guardTap(() => _pushGrades(track)) : null,
      borderRadius: BorderRadius.circular(16),
      child: Opacity(
        opacity: hasAnyValid ? 1.0 : 0.55,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 14, 16, 14),
          child: Row(
            children: [
              _IconBadge(icon: visual.icon, color: visual.color),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      track.title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (hasAnyValid) ...[
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: fraction,
                          minHeight: 4,
                          backgroundColor: cs.surfaceContainerHighest,
                          color: cs.primary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              if (!hasAnyValid)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Скоро',
                    style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                  ),
                )
              else
                Text(
                  '$mastered/$total',
                  style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                ),
            ],
          ),
        ),
      ),
    );
  }

}

// ── Reusable sub-widgets ────────────────────────────────────────────────────

class _StreakBadge extends StatelessWidget {
  const _StreakBadge({required this.streak});
  final int streak;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (streak <= 0) {
      return Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.local_fire_department_outlined,
          size: 20,
          color: cs.onSurfaceVariant,
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.local_fire_department, size: 18, color: cs.primary),
          const SizedBox(width: 4),
          Text(
            '$streak',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: cs.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _IconBadge extends StatelessWidget {
  const _IconBadge({required this.icon, required this.color});
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: Colors.white, size: 22),
    );
  }
}

class _ContinueCardView extends StatelessWidget {
  const _ContinueCardView({required this.card, required this.onLaunch});
  final ContinueCard card;
  final VoidCallback onLaunch;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (card.isResume)
                Text(
                  'ПРОДОЛЖИТЬ',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              const Spacer(),
              Text(
                'Вопрос ${card.questionNumber} / ${card.questionTotal}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            card.title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          Text(
            card.subtitle,
            style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: card.progress,
              minHeight: 5,
              backgroundColor: cs.surfaceContainerHighest,
              color: cs.primary,
            ),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton(
              onPressed: onLaunch,
              child: Text(card.isResume ? 'Продолжить' : 'Начать'),
            ),
          ),
        ],
      ),
    );
  }
}

class _DailyGoalCard extends StatelessWidget {
  const _DailyGoalCard({required this.answered, required this.goal});
  final int answered;
  final int goal;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    // Счётчик за день может перевалить за цель (ответили больше нормы) — в
    // кольце показываем не больше «10/10», иначе «15/10» распирает кружок.
    final shown = answered.clamp(0, goal);
    final remaining = (goal - answered).clamp(0, goal);
    final fraction = goal == 0 ? 0.0 : (answered / goal).clamp(0.0, 1.0);
    final subtitle = remaining > 0
        ? 'Ещё $remaining ${pluralQuestions(remaining)} до цели дня'
        : 'Цель дня выполнена 🎉';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 46,
            height: 46,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 46,
                  height: 46,
                  child: CircularProgressIndicator(
                    value: fraction,
                    strokeWidth: 4,
                    backgroundColor: cs.surfaceContainerHighest,
                    color: cs.primary,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(6),
                  child: FittedBox(
                    child: Text(
                      '$shown/$goal',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Ежедневная цель',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
