import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Круглый индикатор, который заполняется «жидкостью» снизу вверх до доли
/// [value] (0..1). Поверхность жидкости колышется волной — создаётся ощущение
/// налитого стакана. В центре поверх заливки рисуется [child] (обычно процент и
/// подпись «X из Y»).
///
/// Анимаций две: разовый подъём уровня 0 → [value] и бесконечная волна на
/// поверхности. Обе уважают системное «уменьшить движение»
/// ([MediaQueryData.disableAnimations]): при включённом флаге волна не
/// запускается, а уровень показывается сразу — это важно и для доступности, и
/// чтобы `pumpAndSettle` в тестах не зависал на бесконечной анимации.
class WaveGauge extends StatefulWidget {
  const WaveGauge({
    required this.value,
    required this.size,
    required this.fillColor,
    required this.backgroundColor,
    required this.child,
    super.key,
  });

  /// Доля заполнения 0..1 (значения вне диапазона зажимаются).
  final double value;
  final double size;
  final Color fillColor;
  final Color backgroundColor;
  final Widget child;

  @override
  State<WaveGauge> createState() => _WaveGaugeState();
}

class _WaveGaugeState extends State<WaveGauge> with TickerProviderStateMixin {
  late final AnimationController _wave; // фаза волны, бесконечный цикл
  late final AnimationController _fill; // подъём уровня, один проход
  late Animation<double> _level;

  double get _target => widget.value.clamp(0.0, 1.0);

  @override
  void initState() {
    super.initState();
    _wave = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _fill = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _level = _tween(0, _target);
  }

  Animation<double> _tween(double begin, double end) =>
      Tween<double>(begin: begin, end: end).animate(
        CurvedAnimation(parent: _fill, curve: Curves.easeOutCubic),
      );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _applyMotion();
  }

  @override
  void didUpdateWidget(covariant WaveGauge old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) {
      _level = _tween(_level.value, _target);
      unawaited(_fill.forward(from: 0));
      _applyMotion();
    }
  }

  /// Согласует контроллеры с режимом «уменьшить движение».
  void _applyMotion() {
    final reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduce) {
      _wave.stop();
      _fill.value = 1; // мгновенно показать финальный уровень
    } else {
      if (!_wave.isAnimating) unawaited(_wave.repeat());
      if (_fill.value == 0) unawaited(_fill.forward());
    }
  }

  @override
  void dispose() {
    _wave.dispose();
    _fill.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          ClipOval(
            child: AnimatedBuilder(
              animation: Listenable.merge([_wave, _fill]),
              builder: (context, _) => CustomPaint(
                size: Size.square(widget.size),
                painter: _LiquidPainter(
                  level: _level.value,
                  phase: _wave.value * 2 * math.pi,
                  fill: widget.fillColor,
                  background: widget.backgroundColor,
                ),
              ),
            ),
          ),
          widget.child,
        ],
      ),
    );
  }
}

class _LiquidPainter extends CustomPainter {
  _LiquidPainter({
    required this.level,
    required this.phase,
    required this.fill,
    required this.background,
  });

  final double level; // 0..1
  final double phase; // радианы
  final Color fill;
  final Color background;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = background);

    final w = size.width;
    final h = size.height;
    final baseY = h * (1 - level);
    // У самых краёв (пусто/полно) волну убираем, чтобы жидкость не «выплёскивалась».
    final amp = (level <= 0.02 || level >= 0.98) ? 0.0 : (h * 0.05).clamp(0, 6);

    void wave(double phaseShift, Color color) {
      final path = Path()..moveTo(0, baseY);
      for (var x = 0.0; x <= w; x += 2) {
        final y = baseY - amp * math.sin(2 * math.pi * (x / w) + phase + phaseShift);
        path.lineTo(x, y);
      }
      path
        ..lineTo(w, h)
        ..lineTo(0, h)
        ..close();
      canvas.drawPath(path, Paint()..color = color);
    }

    // Задняя волна — приглушённая, передняя — насыщенная: даёт глубину.
    wave(math.pi, fill.withValues(alpha: 0.40));
    wave(0, fill);
  }

  @override
  bool shouldRepaint(_LiquidPainter old) =>
      old.level != level ||
      old.phase != phase ||
      old.fill != fill ||
      old.background != background;
}
