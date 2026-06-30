import 'dart:async';

import 'package:flutter/material.dart';
import 'package:interview_helper_system/controllers/home_controller.dart';
import 'package:interview_helper_system/models/models.dart';
import 'package:interview_helper_system/screens/practice_topics_screen.dart';
import 'package:interview_helper_system/screens/session_screen.dart';
import 'package:interview_helper_system/screens/tracks_loader.dart';
import 'package:interview_helper_system/services/progress_service.dart';
import 'package:interview_helper_system/services/question_repository.dart';
import 'package:interview_helper_system/utils/ru_format.dart';
import 'package:interview_helper_system/utils/tap_lock.dart';
import 'package:interview_helper_system/utils/track_visuals.dart';

/// Первый экран Практики: выбор направления. Сверху — заголовок, поиск и
/// карточка «Тренировка дня» (умный микс по слабым темам); ниже — список
/// направлений с прогрессом. Тап по направлению ведёт к темам внутри него.
class PracticeScreen extends StatefulWidget {
  const PracticeScreen({
    required this.repository,
    required this.progress,
    super.key,
  });
  final QuestionRepository repository;
  final ProgressService progress;

  @override
  State<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends State<PracticeScreen>
    with TracksLoader<PracticeScreen>, TapLock<PracticeScreen> {
  @override
  QuestionRepository get repository => widget.repository;

  @override
  String get loadErrorMessage => 'Не удалось загрузить направления';

  final _searchController = TextEditingController();
  String _query = '';
  bool _ensuringMix = false;

  @override
  void initState() {
    super.initState();
    // Пересобираем микс на любое изменение прогресса (сессия завершилась,
    // появились новые слабые темы и т.п.).
    widget.progress.addListener(_onProgressChanged);
  }

  @override
  void dispose() {
    widget.progress.removeListener(_onProgressChanged);
    _searchController.dispose();
    super.dispose();
  }

  /// После загрузки треков сразу приводим микс в актуальное состояние.
  @override
  Future<void> loadTracks() async {
    await super.loadTracks();
    await _ensureMix();
  }

  void _onProgressChanged() => unawaited(_ensureMix());

  /// Поддерживает сохранённый микс актуальным: пересобирает завершённый/пустой,
  /// очищает, если слабых тем больше не хватает. Пишет только при изменении —
  /// иначе тихо выходит (защита от циклов перерисовки).
  Future<void> _ensureMix() async {
    if (_ensuringMix || !mounted || loading) return;
    _ensuringMix = true;
    try {
      final controller =
          HomeController(tracks: tracks, progress: widget.progress);
      final view = controller.practiceMixView();
      if (view != null && !view.isComplete) return; // здоровый активный микс
      final fresh = controller.generateMix();
      if (fresh == null) {
        await widget.progress.clearPracticeMix(); // no-op, если уже пуст
      } else {
        await widget.progress.savePracticeMix(fresh);
      }
    } finally {
      _ensuringMix = false;
    }
  }

  /// Контентные направления (без языковых треков).
  List<Track> get _contentTracks =>
      tracks.where((t) => t.category != 'language').toList();

  List<Track> get _filteredTracks {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _contentTracks;
    return _contentTracks
        .where(
          (t) =>
              t.title.toLowerCase().contains(q) ||
              (t.description?.toLowerCase().contains(q) ?? false),
        )
        .toList();
  }

  // ── Navigation ────────────────────────────────────────────────────────────

  void _openTrack(Track track) => guardTap(
        () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            settings: RouteSettings(name: 'Темы направления: ${track.title}'),
            builder: (_) => PracticeTopicsScreen(
              track: track,
              progress: widget.progress,
            ),
          ),
        ),
      );

  /// «Тренировка дня»: гоняем ещё не решённые вопросы текущего микса. На финише
  /// сессии прогресс пишется по своим грейдам, а слушатель пересоберёт микс,
  /// если он окажется пройден.
  void _startDailyTraining(PracticeMixView view) {
    if (view.remaining.isEmpty ||
        view.repTrack == null ||
        view.repGrade == null) {
      return;
    }
    guardTap(
      () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          settings: const RouteSettings(name: 'Вопросы: Тренировка дня'),
          builder: (_) => SessionScreen(
            track: view.repTrack!,
            grade: view.repGrade!,
            questions: view.remaining,
            progress: widget.progress,
            questionGradeKeys: view.questionGradeKeys,
          ),
        ),
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
                builder: (context, _) => _body(),
              ),
      ),
    );
  }

  Widget _body() {
    final searching = _query.trim().isNotEmpty;
    final filtered = _filteredTracks;
    // Микс показываем, пока он есть (ошибки ≥2 в разных темах накопили
    // вопросы). Завершённый микс остаётся видимым (X/X) до того, как слушатель
    // пересоберёт его на месте — так карточка не «мигает». Если пересобрать
    // нечем, слушатель очистит микс и карточка исчезнет.
    final mixView = searching
        ? null
        : HomeController(tracks: tracks, progress: widget.progress)
            .practiceMixView();
    final showMix = mixView != null;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        const Text(
          'Практика',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 16),
        _searchBar(),
        const SizedBox(height: 16),
        if (loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child: Center(child: CircularProgressIndicator()),
          )
        else ...[
          if (showMix) ...[
            _DailyTrainingCard(
              mastered: mixView.mastered,
              total: mixView.total,
              onStart: () => _startDailyTraining(mixView),
            ),
            const SizedBox(height: 24),
          ],
          _sectionLabel('Выберите направление'),
          const SizedBox(height: 8),
          if (filtered.isEmpty)
            _noResults()
          else
            ...filtered.map(_trackCard),
        ],
      ],
    );
  }

  Widget _searchBar() {
    final cs = Theme.of(context).colorScheme;
    return TextField(
      controller: _searchController,
      onChanged: (v) => setState(() => _query = v),
      decoration: InputDecoration(
        hintText: 'Поиск по направлению',
        prefixIcon: const Icon(Icons.search, size: 20),
        suffixIcon: _query.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: () {
                  _searchController.clear();
                  setState(() => _query = '');
                },
              )
            : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: cs.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: cs.outlineVariant),
        ),
        filled: true,
        fillColor: cs.surface,
        contentPadding: EdgeInsets.zero,
      ),
    );
  }

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

  Widget _trackCard(Track track) {
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
    final topicCount = _distinctTopicCount(track);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: hasAnyValid ? () => _openTrack(track) : null,
        borderRadius: BorderRadius.circular(16),
        child: Opacity(
          opacity: hasAnyValid ? 1.0 : 0.55,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: cs.outlineVariant),
            ),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: visual.color,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(visual.icon, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        track.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _tagline(track, topicCount),
                        style:
                            TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                      ),
                      const SizedBox(height: 10),
                      if (hasAnyValid)
                        Row(
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(3),
                                child: LinearProgressIndicator(
                                  value: fraction,
                                  minHeight: 5,
                                  backgroundColor: cs.surfaceContainerHighest,
                                  color: cs.primary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              '$mastered / $total',
                              style: TextStyle(
                                fontSize: 13,
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ],
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: cs.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Скоро',
                            style: TextStyle(
                              fontSize: 11,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (hasAnyValid) ...[
                  const SizedBox(width: 8),
                  Icon(
                    Icons.chevron_right,
                    size: 20,
                    color: cs.onSurfaceVariant,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Подзаголовок направления: краткий тэглайн + число тем.
  /// Тэглайн — первая часть описания (до запятой), как в макете.
  String _tagline(Track track, int topicCount) {
    final desc = track.description;
    final short = (desc == null || desc.isEmpty)
        ? null
        : desc.split(',').first.trim();
    final topics = '$topicCount ${pluralTopics(topicCount)}';
    return short == null ? topics : '$short · $topics';
  }

  int _distinctTopicCount(Track track) {
    final topics = <String>{};
    for (final g in track.grades) {
      for (final q in g.questions) {
        final t = q.topic;
        if (t != null && t.isNotEmpty) topics.add(t);
      }
    }
    return topics.length;
  }

  Widget _noResults() {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off, size: 40, color: cs.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(
              'Ничего не найдено',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DailyTrainingCard extends StatelessWidget {
  const _DailyTrainingCard({
    required this.mastered,
    required this.total,
    required this.onStart,
  });

  /// Сколько вопросов микса уже решено верно (X из [total]).
  final int mastered;
  final int total;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fraction = total == 0 ? 0.0 : (mastered / total).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.local_fire_department, color: cs.primary, size: 24),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Тренировка дня',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Умный микс из слабых тем',
                      style: TextStyle(fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
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
                    Text(
                      '$mastered/$total',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onStart,
              child: const Text('Начать'),
            ),
          ),
        ],
      ),
    );
  }
}
