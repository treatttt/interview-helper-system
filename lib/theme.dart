import 'package:flutter/material.dart';

/// Бренд-семя. От него обе схемы (светлая/тёмная) производят стандартные роли.
/// Тема-независимо — это исходный цвет бренда, не «светлый» и не «тёмный».
const _brandSeed = Color(0xFF993556); // розовый бренд-акцент

// ─────────────────────────────────────────────────────────────────────────
//  Семантические цвета (success / warning / danger / info).
//  В стандартном ColorScheme для них нет слотов, поэтому они живут в
//  ThemeExtension. Экран берёт их так:
//      final s = AppSemanticColors.of(context);
//      ... color: s.successFg, border: s.successBorder, bg: s.successBg ...
//  of() null-безопасен: если расширение не зарегистрировано — отдаёт дефолт
//  под текущую яркость, а не падает. На happy-path значения приходят под
//  текущую тему автоматически, без проверок brightness.
// ─────────────────────────────────────────────────────────────────────────
@immutable
class AppSemanticColors extends ThemeExtension<AppSemanticColors> {

  const AppSemanticColors({
    required this.successFg,
    required this.successBorder,
    required this.successBg,
    required this.warningFg,
    required this.warningBorder,
    required this.warningBg,
    required this.dangerFg,
    required this.dangerBorder,
    required this.dangerBg,
    required this.infoFg,
    required this.infoBorder,
    required this.infoBg,
    required this.progressGreen,
    required this.mutedForeground,
  });

  final Color successFg;
  final Color successBorder;
  final Color successBg;
  final Color warningFg;
  final Color warningBorder;
  final Color warningBg;
  final Color dangerFg;
  final Color dangerBorder;
  final Color dangerBg;
  final Color infoFg;
  final Color infoBorder;
  final Color infoBg;
  /// Зелёный акцент для прогресс-баров и бейджей (Figma: spring-green/37 #1F9D6B).
  final Color progressGreen;
  /// Третичный текст — даты, вспомогательные подписи (Figma: #9A9AA4).
  final Color mutedForeground;

  /// Светлая палитра. Значения foreground тёмные (читаемы на светлом фоне),
  /// bg — светлые тинты, border — средняя насыщенность.
  static const light = AppSemanticColors(
    successFg: Color(0xFF0F6E56),
    successBorder: Color(0xFF2E9E7E),
    successBg: Color(0xFFE1F5EE),
    warningFg: Color(0xFF854F0B),
    warningBorder: Color(0xFFC08A2E),
    warningBg: Color(0xFFFBEFD9),
    dangerFg: Color(0xFFA32D2D),
    dangerBorder: Color(0xFFD06464),
    dangerBg: Color(0xFFFCEBEB),
    infoFg: Color(0xFF185FA5),
    infoBorder: Color(0xFF5A95CE),
    infoBg: Color(0xFFE6F1FB),
    progressGreen: Color(0xFF1F9D6B),
    mutedForeground: Color(0xFF9A9AA4),
  );

  /// Тёмная палитра. Foreground осветлён (контраст ≥4.5:1 на тёмной поверхности),
  /// bg — тёмные приглушённые контейнеры (не чёрные), border — средний тон.
  /// Это инженерный дефолт по принципам тёмной темы, а не бренд-решение —
  /// безопасно подкрутить, когда появится дизайнер.
  static const dark = AppSemanticColors(
    successFg: Color(0xFF5CD0AC),
    successBorder: Color(0xFF2E6E5C),
    successBg: Color(0xFF13302A),
    warningFg: Color(0xFFE6B45C),
    warningBorder: Color(0xFF7A5A1E),
    warningBg: Color(0xFF332813),
    dangerFg: Color(0xFFF09393),
    dangerBorder: Color(0xFF8A3A3A),
    dangerBg: Color(0xFF381E1E),
    infoFg: Color(0xFF7CB6F0),
    infoBorder: Color(0xFF2E5C8A),
    infoBg: Color(0xFF14283D),
    progressGreen: Color(0xFF3DBF8C),
    mutedForeground: Color(0xFF6E6E78),
  );

  /// Безопасный доступ к семантическим цветам взамен `extension<...>()!`.
  /// Happy-path: расширение всегда зарегистрировано в _baseTheme, возвращается оно.
  /// Fallback (виджет вне темизированного MaterialApp, изолированный тест):
  /// дефолт под текущую яркость — не падаем на null.
  static AppSemanticColors of(BuildContext context) {
    final theme = Theme.of(context);
    return theme.extension<AppSemanticColors>() ??
        (theme.brightness == Brightness.dark ? dark : light);
  }

  @override
  AppSemanticColors copyWith({
    Color? successFg,
    Color? successBorder,
    Color? successBg,
    Color? warningFg,
    Color? warningBorder,
    Color? warningBg,
    Color? dangerFg,
    Color? dangerBorder,
    Color? dangerBg,
    Color? infoFg,
    Color? infoBorder,
    Color? infoBg,
    Color? progressGreen,
    Color? mutedForeground,
  }) {
    return AppSemanticColors(
      successFg: successFg ?? this.successFg,
      successBorder: successBorder ?? this.successBorder,
      successBg: successBg ?? this.successBg,
      warningFg: warningFg ?? this.warningFg,
      warningBorder: warningBorder ?? this.warningBorder,
      warningBg: warningBg ?? this.warningBg,
      dangerFg: dangerFg ?? this.dangerFg,
      dangerBorder: dangerBorder ?? this.dangerBorder,
      dangerBg: dangerBg ?? this.dangerBg,
      infoFg: infoFg ?? this.infoFg,
      infoBorder: infoBorder ?? this.infoBorder,
      infoBg: infoBg ?? this.infoBg,
      progressGreen: progressGreen ?? this.progressGreen,
      mutedForeground: mutedForeground ?? this.mutedForeground,
    );
  }

  /// Нужен для плавной интерполяции при анимированной смене темы.
  @override
  AppSemanticColors lerp(ThemeExtension<AppSemanticColors>? other, double t) {
    if (other is! AppSemanticColors) return this;
    return AppSemanticColors(
      successFg: Color.lerp(successFg, other.successFg, t)!,
      successBorder: Color.lerp(successBorder, other.successBorder, t)!,
      successBg: Color.lerp(successBg, other.successBg, t)!,
      warningFg: Color.lerp(warningFg, other.warningFg, t)!,
      warningBorder: Color.lerp(warningBorder, other.warningBorder, t)!,
      warningBg: Color.lerp(warningBg, other.warningBg, t)!,
      dangerFg: Color.lerp(dangerFg, other.dangerFg, t)!,
      dangerBorder: Color.lerp(dangerBorder, other.dangerBorder, t)!,
      dangerBg: Color.lerp(dangerBg, other.dangerBg, t)!,
      infoFg: Color.lerp(infoFg, other.infoFg, t)!,
      infoBorder: Color.lerp(infoBorder, other.infoBorder, t)!,
      infoBg: Color.lerp(infoBg, other.infoBg, t)!,
      progressGreen: Color.lerp(progressGreen, other.progressGreen, t)!,
      mutedForeground: Color.lerp(mutedForeground, other.mutedForeground, t)!,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
//  Сборки тем. Стандартные роли (фон, поверхность, текст, primary, border)
//  идут через ColorScheme; семантика — через extension выше.
// ─────────────────────────────────────────────────────────────────────────

ThemeData buildLightTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: _brandSeed,
  ).copyWith(
    primary: _brandSeed,
    onPrimary: const Color(0xFFFFFFFF),
    primaryContainer: const Color(0xFFFBDCE6),
    onPrimaryContainer: const Color(0xFF3E0A1E),
    surface: const Color(0xFFFFFFFF),
    onSurface: const Color(0xFF1A1A18),
    onSurfaceVariant: const Color(0xFF5F5E5A),
    outlineVariant: const Color(0xFFE4E2DA),
  );

  return _baseTheme(
    scheme: scheme,
    scaffoldBg: const Color(0xFFF7F6F2), // тёплый off-white
    semantic: AppSemanticColors.light,
  );
}

ThemeData buildDarkTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: _brandSeed,
    brightness: Brightness.dark,
  ).copyWith(
    primary: const Color(0xFFD4537E),
    onPrimary: const Color(0xFFFFFFFF),
    primaryContainer: const Color(0xFF5A2238),
    onPrimaryContainer: const Color(0xFFFBDCE6),
    surface: const Color(0xFF232220),
    onSurface: const Color(0xFFF2F1EC),
    onSurfaceVariant: const Color(0xFFA6A49D),
    outlineVariant: const Color(0xFF3A3833),
  );

  return _baseTheme(
    scheme: scheme,
    scaffoldBg: const Color(0xFF1A1916), // тёплый тёмный, не чёрный
    semantic: AppSemanticColors.dark,
  );
}

/// Общая часть обеих тем, чтобы не дублировать настройки.
ThemeData _baseTheme({
  required ColorScheme scheme,
  required Color scaffoldBg,
  required AppSemanticColors semantic,
}) {
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: scaffoldBg,
    fontFamily: 'Roboto',
    appBarTheme: AppBarTheme(
      backgroundColor: scaffoldBg,
      foregroundColor: scheme.onSurface,
      elevation: 0,
      centerTitle: false,
    ),
    extensions: [semantic],
  );
}
