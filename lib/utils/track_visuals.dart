import 'package:flutter/material.dart';

/// Иконка и фирменный цвет направления — единый источник для Главной и
/// Практики, чтобы карточки направлений выглядели одинаково во всём приложении.
/// Для неизвестных треков — нейтральный дефолт на акценте темы.
///
/// Иконки — встроенные Material как временные заглушки; при желании их можно
/// заменить на любой свой набор, не трогая остальной код.
({IconData icon, Color color}) trackVisual(String trackId, ColorScheme cs) {
  return switch (trackId) {
    'analytics' => (icon: Icons.bar_chart, color: const Color(0xFF5A6AD6)),
    'development' => (icon: Icons.code, color: const Color(0xFF1F9D6B)),
    'testing' => (icon: Icons.bug_report, color: const Color(0xFFC2871C)),
    _ => (icon: Icons.menu_book, color: cs.primary),
  };
}
