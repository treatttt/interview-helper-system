import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:interview_helper_system/utils/track_visuals.dart';

void main() {
  final cs = ColorScheme.fromSeed(seedColor: const Color(0xFFAB12CD));

  group('trackVisual — иконка и цвет направления', () {
    test('analytics → bar_chart + фирменный синий', () {
      final v = trackVisual('analytics', cs);
      expect(v.icon, Icons.bar_chart);
      expect(v.color, const Color(0xFF5A6AD6));
    });

    test('development → code + зелёный', () {
      final v = trackVisual('development', cs);
      expect(v.icon, Icons.code);
      expect(v.color, const Color(0xFF1F9D6B));
    });

    test('testing → bug_report + охра', () {
      final v = trackVisual('testing', cs);
      expect(v.icon, Icons.bug_report);
      expect(v.color, const Color(0xFFC2871C));
    });

    test('фирменные цвета не зависят от темы', () {
      final other = ColorScheme.fromSeed(seedColor: const Color(0xFF00FF00));
      expect(trackVisual('analytics', other).color, const Color(0xFF5A6AD6));
    });

    test('неизвестный трек → menu_book + cs.primary', () {
      final v = trackVisual('mystery', cs);
      expect(v.icon, Icons.menu_book);
      expect(v.color, cs.primary);
    });
  });
}
