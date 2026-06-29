import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:interview_helper_system/models/models.dart';
import 'package:interview_helper_system/screens/progress_metrics.dart';
import 'package:interview_helper_system/screens/tracks_loader.dart';
import 'package:interview_helper_system/services/progress_service.dart';
import 'package:interview_helper_system/services/question_repository.dart';
import 'package:interview_helper_system/theme.dart';
import 'package:interview_helper_system/widgets/app_dialog.dart';

/// Экран «Прогресс»: агрегированная статистика, динамика точности, прогресс по грейдам.
class ProgressScreen extends StatefulWidget {
  const ProgressScreen({
    required this.repository,
    required this.progress,
    super.key,
  });

  final QuestionRepository repository;
  final ProgressService progress;

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen>
    with TracksLoader<ProgressScreen> {
  @override
  QuestionRepository get repository => widget.repository;

  @override
  String get loadErrorMessage => 'Не удалось загрузить данные';

  /// Выбранная в секции «По грейдам» роль. null → берётся первый трек.
  String? _selectedTrackId;

  /// Текущий трек секции грейдов: выбранный пользователем либо первый из каталога.
  Track get _selectedTrack {
    for (final t in tracks) {
      if (t.id == _selectedTrackId) return t;
    }
    return tracks.first;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListenableBuilder(
          listenable: widget.progress,
          builder: (context, _) {
            if (loading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (error != null) {
              return ErrorRetryView(title: error!, onRetry: retryLoad);
            }
            return _buildContent(context);
          },
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final p = widget.progress;
    final masteredTopics = countMasteredTopics(tracks, p.masteredIds);
    final log = p.dailyAccuracyLog;
    final delta = accuracyDelta(log);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 19),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 6),
          _title(context),
          const SizedBox(height: 16),
          _statsGrid(context, p, masteredTopics),
          const SizedBox(height: 18),
          _chartCard(context, log, delta),
          const SizedBox(height: 22),
          _gradeSectionHeader(context),
          const SizedBox(height: 8),
          _gradeCard(context, p),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ── Заголовок ────────────────────────────────────────────────────────────

  Widget _title(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 2, bottom: 14),
      child: Text(
        'Прогресс',
        style: TextStyle(
          fontSize: 25,
          fontWeight: FontWeight.w400,
          letterSpacing: -0.62,
          color: cs.onSurface,
        ),
      ),
    );
  }

  // ── Сетка 2×2 метрик ─────────────────────────────────────────────────────

  Widget _statsGrid(
    BuildContext context,
    ProgressService p,
    int masteredTopics,
  ) {
    final hasData = p.hasTrainedEver;
    final accuracyText =
        hasData ? '${(p.overallAccuracy * 100).round()}%' : '—';

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _statCard(
                context,
                value: '${p.totalAnswers}',
                label: 'Ответов',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _statCard(
                context,
                value: accuracyText,
                label: 'Точность',
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _statCard(
                context,
                value: '${p.streak}',
                label: 'Серия, дней',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _statCard(
                context,
                value: '$masteredTopics',
                label: 'Освоено тем',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _statCard(
    BuildContext context, {
    required String value,
    required String label,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border.all(color: cs.outlineVariant),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.65,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              color: cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  // ── Карточка графика ──────────────────────────────────────────────────────

  Widget _chartCard(
    BuildContext context,
    Map<String, ({int answers, int correct})> log,
    double? delta,
  ) {
    final cs = Theme.of(context).colorScheme;
    final sem = AppSemanticColors.of(context);
    final points = _chartPoints(log);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border.all(color: cs.outlineVariant),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Динамика точности',
                style: TextStyle(
                  fontSize: 14.5,
                  color: cs.onSurface,
                ),
              ),
              const Spacer(),
              if (delta != null) _deltaBadge(delta, sem),
            ],
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 120,
            child: points.length < 2
                ? _emptyChart(sem)
                : CustomPaint(
                    painter: _AccuracyChartPainter(
                      points: points,
                      lineColor: cs.primary,
                      fillColor: cs.primary.withValues(alpha: 0.12),
                    ),
                    size: const Size(double.infinity, 120),
                  ),
          ),
          const SizedBox(height: 4),
          _chartDateLabels(points, sem),
        ],
      ),
    );
  }

  Widget _deltaBadge(double delta, AppSemanticColors sem) {
    final isPositive = delta >= 0;
    final pct = (delta.abs() * 100).round();
    final label = isPositive ? '+$pct%' : '-$pct%';
    final bgColor = isPositive ? sem.successBg : sem.dangerBg;
    final fgColor = isPositive ? sem.progressGreen : sem.dangerFg;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isPositive ? Icons.trending_up : Icons.trending_down,
            size: 14,
            color: fgColor,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: fgColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyChart(AppSemanticColors sem) {
    return Center(
      child: Text(
        'Пока нет данных',
        style: TextStyle(
          fontSize: 13,
          color: sem.mutedForeground,
        ),
      ),
    );
  }

  Widget _chartDateLabels(List<(DateTime, double)> points, AppSemanticColors sem) {
    if (points.isEmpty) return const SizedBox.shrink();

    final labelStyle = TextStyle(fontSize: 10.5, color: sem.mutedForeground);

    // Показываем до 4 меток: первую, последнюю и 2 промежуточных
    final labels = _pickDateLabels(points);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: labels
          .map((d) => Text(_formatDate(d), style: labelStyle))
          .toList(),
    );
  }

  // ── Секция «По грейдам» ───────────────────────────────────────────────────

  Widget _gradeSectionHeader(BuildContext context) {
    final sem = AppSemanticColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Text(
        'ПО ГРЕЙДАМ',
        style: TextStyle(
          fontSize: 11,
          letterSpacing: 1.1,
          color: sem.mutedForeground,
        ),
      ),
    );
  }

  Widget _gradeCard(BuildContext context, ProgressService p) {
    if (tracks.isEmpty) return const SizedBox.shrink();

    final cs = Theme.of(context).colorScheme;
    final sem = AppSemanticColors.of(context);

    final track = _selectedTrack;

    // Только грейды выбранной роли (сортировка по order)
    final sorted = [...track.grades]..sort((a, b) => a.order.compareTo(b.order));
    final rows = <_GradeRow>[];
    for (final grade in sorted) {
      final progress = gradeProgress(track.id, grade, p.masteredIds);
      rows.add(
        _GradeRow(
          label: grade.title,
          fraction: progress.fraction,
          isSoon: progress.isSoon,
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border.all(color: cs.outlineVariant),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          _roleSelector(context, track, cs),
          for (var i = 0; i < rows.length; i++) ...[
            Divider(
              height: 1,
              thickness: 1,
              color: cs.surfaceContainerHighest,
            ),
            _gradeRow(rows[i], cs, sem),
          ],
        ],
      ),
    );
  }

  // ── Селектор роли (всплывающий список) ────────────────────────────────────

  Widget _roleSelector(BuildContext context, Track track, ColorScheme cs) {
    return InkWell(
      onTap: () => _pickRole(context),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 13, 12, 13),
        child: Row(
          children: [
            Expanded(
              child: Text(
                track.title,
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface,
                ),
              ),
            ),
            Icon(Icons.expand_more, size: 20, color: cs.onSurfaceVariant),
          ],
        ),
      ),
    );
  }

  Future<void> _pickRole(BuildContext context) async {
    final picked = await showAppSelectionDialog<String>(
      context: context,
      title: 'Выберите роль',
      selected: _selectedTrack.id,
      options: [
        for (final track in tracks)
          AppSelectionOption(value: track.id, label: track.title),
      ],
    );
    if (picked != null && picked != _selectedTrackId && mounted) {
      setState(() => _selectedTrackId = picked);
    }
  }

  Widget _gradeRow(_GradeRow row, ColorScheme cs, AppSemanticColors sem) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          SizedBox(
            width: 62,
            child: Text(
              row.label,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: row.isSoon ? sem.mutedForeground : cs.onSurface,
              ),
            ),
          ),
          const SizedBox(width: 12),
          if (row.isSoon)
            _soonBadge(cs, sem)
          else ...[
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: row.fraction,
                  minHeight: 5,
                  backgroundColor: cs.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    row.fraction >= 0.5 ? sem.progressGreen : cs.primary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 36,
              child: Text(
                '${(row.fraction * 100).round()}%',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurfaceVariant,
                ),
                textAlign: TextAlign.end,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _soonBadge(ColorScheme cs, AppSemanticColors sem) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        'Скоро',
        style: TextStyle(
          fontSize: 11,
          color: sem.mutedForeground,
        ),
      ),
    );
  }

  // ── Вспомогательные ───────────────────────────────────────────────────────

  List<(DateTime, double)> _chartPoints(
    Map<String, ({int answers, int correct})> log,
  ) {
    final points = log.entries.map((e) {
      final parts = e.key.split('-');
      if (parts.length != 3) return null;
      try {
        final date = DateTime(
          int.parse(parts[0]),
          int.parse(parts[1]),
          int.parse(parts[2]),
        );
        final acc = e.value.answers == 0
            ? 0.0
            : e.value.correct / e.value.answers;
        return (date, acc);
      } on Object {
        return null;
      }
    }).whereType<(DateTime, double)>().toList()
      ..sort((a, b) => a.$1.compareTo(b.$1));
    return points;
  }

  List<DateTime> _pickDateLabels(List<(DateTime, double)> points) {
    if (points.isEmpty) return [];
    if (points.length == 1) return [points.first.$1];
    if (points.length <= 4) return points.map((p) => p.$1).toList();

    // 4 равноотстоящих индекса: первый, треть, две трети, последний
    final n = points.length - 1;
    return [
      points[0].$1,
      points[(n ~/ 3)].$1,
      points[(n * 2 ~/ 3)].$1,
      points[n].$1,
    ];
  }

  static const _months = [
    '', 'янв', 'фев', 'мар', 'апр', 'май', 'июн',
    'июл', 'авг', 'сен', 'окт', 'ноя', 'дек',
  ];

  String _formatDate(DateTime d) => '${d.day} ${_months[d.month]}';
}

// ── Структура строки грейда ───────────────────────────────────────────────

class _GradeRow {
  const _GradeRow({
    required this.label,
    required this.fraction,
    required this.isSoon,
  });
  final String label;
  final double fraction;
  final bool isSoon;
}

// ── CustomPainter для графика точности ───────────────────────────────────

class _AccuracyChartPainter extends CustomPainter {
  const _AccuracyChartPainter({
    required this.points,
    required this.lineColor,
    required this.fillColor,
  });

  final List<(DateTime, double)> points;
  final Color lineColor;
  final Color fillColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final offsets = _computeOffsets(size);
    if (offsets.length < 2) {
      // Единственная точка — горизонтальная линия посередине
      final y = size.height * 0.5;
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        Paint()
          ..color = lineColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      return;
    }

    // Заливка под линией
    final fillPath = Path()..moveTo(offsets.first.dx, size.height);
    for (final o in offsets) {
      fillPath.lineTo(o.dx, o.dy);
    }
    fillPath
      ..lineTo(offsets.last.dx, size.height)
      ..close();
    canvas.drawPath(fillPath, Paint()..color = fillColor);

    // Линия
    final linePath = Path()..moveTo(offsets.first.dx, offsets.first.dy);
    for (var i = 1; i < offsets.length; i++) {
      linePath.lineTo(offsets[i].dx, offsets[i].dy);
    }
    canvas.drawPath(
      linePath,
      Paint()
        ..color = lineColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  List<Offset> _computeOffsets(Size size) {
    if (points.isEmpty) return [];

    final minTime = points.first.$1.millisecondsSinceEpoch.toDouble();
    final maxTime = points.last.$1.millisecondsSinceEpoch.toDouble();
    final timeRange = maxTime - minTime;

    final accs = points.map((p) => p.$2);
    final minAcc = accs.reduce(math.min);
    final maxAcc = accs.reduce(math.max);
    final accRange = maxAcc - minAcc;

    // Отступ сверху и снизу 8% высоты — линия не прижимается к краям
    const vPad = 0.08;

    return points.map((p) {
      final x = timeRange == 0
          ? size.width / 2
          : (p.$1.millisecondsSinceEpoch - minTime) / timeRange * size.width;
      final normAcc = accRange == 0 ? 0.5 : (p.$2 - minAcc) / accRange;
      final y = size.height * (1 - vPad) - normAcc * size.height * (1 - 2 * vPad);
      return Offset(x.clamp(0.0, size.width), y.clamp(0.0, size.height));
    }).toList();
  }

  @override
  bool shouldRepaint(_AccuracyChartPainter old) =>
      old.points != points || old.lineColor != lineColor;
}
