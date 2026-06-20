import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:interview_helper_system/theme.dart';

void main() {
  // === AppSemanticColors.of (строки 88-92) =================================
  group('AppSemanticColors.of', () {
    testWidgets('возвращает расширение, зарегистрированное в теме',
        (tester) async {
      late AppSemanticColors result;
      await tester.pumpWidget(
        MaterialApp(
          theme: buildLightTheme(),
          home: Builder(
            builder: (ctx) {
              result = AppSemanticColors.of(ctx);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(result.successFg, AppSemanticColors.light.successFg);
    },);

    testWidgets(
        'фолбэк на light, если расширение не зарегистрировано (светлая)',
        (tester) async {
      late AppSemanticColors result;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: Brightness.light),
          home: Builder(
            builder: (ctx) {
              result = AppSemanticColors.of(ctx);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(result.successFg, AppSemanticColors.light.successFg);
    },);

    testWidgets('фолбэк на dark при тёмной яркости без расширения',
        (tester) async {
      late AppSemanticColors result;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: Brightness.dark),
          home: Builder(
            builder: (ctx) {
              result = AppSemanticColors.of(ctx);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(result.successFg, AppSemanticColors.dark.successFg);
    },);
  });

  // === copyWith (строки 94-123) ============================================
  test('copyWith переопределяет указанные поля и сохраняет остальные', () {
    const base = AppSemanticColors.light;
    final updated = base.copyWith(
      successFg: const Color(0xFF123456),
      dangerBg: const Color(0xFF654321),
    );

    expect(updated.successFg, const Color(0xFF123456));
    expect(updated.dangerBg, const Color(0xFF654321));
    // Не переданные поля остаются как в базовом наборе.
    expect(updated.warningFg, base.warningFg);
    expect(updated.infoBg, base.infoBg);
    expect(updated.successBorder, base.successBorder);
    expect(updated.dangerFg, base.dangerFg);
  });

  // === lerp (бонус, строки 125-143) ========================================
  test('leap интерполирует наборы; не-AppSemanticColors возвращает this', () {
    const a = AppSemanticColors.light;
    const b = AppSemanticColors.dark;

    expect(a.lerp(b, 0.5), isA<AppSemanticColors>());
    expect(a.lerp(null, 0.5), same(a));
  });
}
