import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/question_repository.dart';
import '../services/progress_service.dart';
import '../services/theme_service.dart';
import '../theme.dart';
import 'grades_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  final QuestionRepository repository;
  final ProgressService progress;
  final ThemeService themeService;

  const HomeScreen({
    super.key,
    required this.repository,
    required this.progress,
    required this.themeService,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Track> _tracks = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final tracks = await widget.repository.loadTracks();
      if (!mounted) return;
      setState(() {
        _tracks = tracks.toList()..sort((a, b) => a.order.compareTo(b.order));
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Не удалось загрузить вопросы';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Тренажёр',
            style: TextStyle(fontWeight: FontWeight.w500)),
        actions: [
          ListenableBuilder(
            listenable: widget.progress,
            builder: (context, _) {
              if (!widget.progress.hasTrainedEver) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Row(
                  children: [
                    const Icon(Icons.local_fire_department,
                        color: Colors.orange, size: 20),
                    const SizedBox(width: 4),
                    Text('${widget.progress.streak}',
                        style: const TextStyle(
                            color: Colors.orange,
                            fontWeight: FontWeight.w500)),
                  ],
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Настройки',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) =>
                    SettingsScreen(themeService: widget.themeService),
              ),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _errorView()
              : _tracks.isEmpty
                  ? _emptyView()
                  : ListenableBuilder(
                      listenable: widget.progress,
                      builder: (context, _) => ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          _xpCard(),
                          const SizedBox(height: 20),
                          ..._tracks.map(_trackCard),
                        ],
                      ),
                    ),
    );
  }

  Widget _xpCard() {
    final s = AppSemanticColors.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: s.infoBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Твой прогресс',
              style: TextStyle(color: s.infoFg, fontSize: 13)),
          const SizedBox(height: 4),
          Text('${widget.progress.xp} XP',
              style: TextStyle(
                  color: s.infoFg,
                  fontSize: 22,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _trackCard(Track track) {
    final cs = Theme.of(context).colorScheme;
    final totalQuestions = track.grades
        .fold<int>(0, (sum, g) => sum + g.questions.length);
    final gradeCounts = track.grades
        .where((g) => g.questions.isNotEmpty)
        .length;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => GradesScreen(
              track: track,
              progress: widget.progress,
            ),
          ),
        ),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: cs.outlineVariant),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      track.title,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    if (track.description != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        track.description!,
                        style: TextStyle(
                            fontSize: 12, color: cs.onSurfaceVariant),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      totalQuestions == 0
                          ? 'Нет вопросов'
                          : '$totalQuestions вопр. · $gradeCounts из ${track.grades.length} грейдов заполнены',
                      style: TextStyle(
                          fontSize: 12, color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, size: 20, color: cs.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emptyView() {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_outlined, size: 48, color: cs.onSurfaceVariant),
            const SizedBox(height: 16),
            const Text('Вопросов пока нет',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w500)),
            const SizedBox(height: 6),
            Text('Направления появятся, когда будут добавлены вопросы.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }

  Widget _errorView() {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_outlined,
                size: 48, color: cs.onSurfaceVariant),
            const SizedBox(height: 16),
            const Text('Не удалось загрузить вопросы',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w500)),
            const SizedBox(height: 6),
            Text('Что-то пошло не так. Попробуй ещё раз.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant)),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () {
                setState(() {
                  _error = null;
                  _loading = true;
                });
                _load();
              },
              child: const Text('Попробовать снова'),
            ),
          ],
        ),
      ),
    );
  }
}
