import 'package:material_ui/material_ui.dart';

import 'app_colors.dart';
import 'app_tokens.dart';

/// Material 3 themes for Sakina.
///
/// The palette is a deep emerald with a warm gold accent on ivory paper by
/// day, and on a green-black night sky in the dark. Material 3 derives every
/// role from [seed]; the roles people actually look at (surfaces, primary,
/// secondary, tertiary and their containers) are then pinned by hand, because
/// the derived tones came out grey-green in light mode and washed out in dark.
/// `test/theme_contrast_test.dart` checks each text/background pair against
/// WCAG AA, so a change here that hurts legibility fails CI.
///
/// `fontFamily` is set once here rather than repeated on every `TextStyle`.
abstract final class AppTheme {
  static const Color seed = Color(0xFF1F6B57);

  static const String _fontFamily = 'Janna';

  static ThemeData get light => _build(Brightness.light, SakinaColors.light);
  static ThemeData get dark => _build(Brightness.dark, SakinaColors.dark);

  static ThemeData _build(Brightness brightness, SakinaColors extras) {
    final scheme = schemeFor(brightness);

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: _fontFamily,
    );

    return base.copyWith(
      extensions: [extras],
      scaffoldBackgroundColor: scheme.surface,
      textTheme: _textTheme(base.textTheme),
      appBarTheme: AppBarTheme(
        centerTitle: true,
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 2,
        titleTextStyle: base.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: scheme.onSurface,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 68,
        backgroundColor: scheme.surfaceContainer,
        indicatorColor: scheme.secondaryContainer,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => base.textTheme.labelMedium?.copyWith(
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w400,
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: scheme.surfaceContainerLow,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: const RoundedRectangleBorder(
          borderRadius: AppRadius.cardRadius,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHigh,
        border: const OutlineInputBorder(
          borderRadius: AppRadius.pillRadius,
          borderSide: BorderSide.none,
        ),
        enabledBorder: const OutlineInputBorder(
          borderRadius: AppRadius.pillRadius,
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.pillRadius,
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
      ),
      listTileTheme: const ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: AppRadius.cardRadius),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        space: 1,
        thickness: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: TextStyle(color: scheme.onInverseSurface),
        shape: const RoundedRectangleBorder(
          borderRadius: AppRadius.cardRadius,
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: scheme.primary),
    );
  }

  /// The colour scheme for [brightness]. Public so tests can check contrast.
  static ColorScheme schemeFor(Brightness brightness) {
    final derived = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
    );
    return brightness == Brightness.light
        ? derived.copyWith(
            primary: const Color(0xFF1F6B57),
            onPrimary: const Color(0xFFFFFFFF),
            primaryContainer: const Color(0xFFCDEBDF),
            onPrimaryContainer: const Color(0xFF07382B),
            secondary: const Color(0xFF4A6158),
            onSecondary: const Color(0xFFFFFFFF),
            secondaryContainer: const Color(0xFFDDE9E2),
            onSecondaryContainer: const Color(0xFF12271F),
            tertiary: const Color(0xFF835F1C),
            onTertiary: const Color(0xFFFFFFFF),
            tertiaryContainer: const Color(0xFFF7E4BD),
            onTertiaryContainer: const Color(0xFF392905),
            surface: const Color(0xFFFAF8F3),
            onSurface: const Color(0xFF1A1D1B),
            onSurfaceVariant: const Color(0xFF46504B),
            surfaceDim: const Color(0xFFDCDAD3),
            surfaceBright: const Color(0xFFFAF8F3),
            surfaceContainerLowest: const Color(0xFFFFFFFF),
            surfaceContainerLow: const Color(0xFFF3F1EA),
            surfaceContainer: const Color(0xFFEDEBE4),
            surfaceContainerHigh: const Color(0xFFE7E5DE),
            surfaceContainerHighest: const Color(0xFFE1DFD8),
            outline: const Color(0xFF747D78),
            outlineVariant: const Color(0xFFC8CDC8),
          )
        : derived.copyWith(
            primary: const Color(0xFF86D5B9),
            onPrimary: const Color(0xFF00382A),
            primaryContainer: const Color(0xFF145241),
            onPrimaryContainer: const Color(0xFFB8F0DA),
            secondary: const Color(0xFFB2CBBF),
            onSecondary: const Color(0xFF1E352C),
            secondaryContainer: const Color(0xFF314840),
            onSecondaryContainer: const Color(0xFFD2E8DD),
            tertiary: const Color(0xFFE3BE78),
            onTertiary: const Color(0xFF3F2D00),
            tertiaryContainer: const Color(0xFF5A4312),
            onTertiaryContainer: const Color(0xFFFFE0A8),
            surface: const Color(0xFF0E1412),
            onSurface: const Color(0xFFE2E8E4),
            onSurfaceVariant: const Color(0xFFBDC8C2),
            surfaceDim: const Color(0xFF0E1412),
            surfaceBright: const Color(0xFF333B37),
            surfaceContainerLowest: const Color(0xFF090E0C),
            surfaceContainerLow: const Color(0xFF151C19),
            surfaceContainer: const Color(0xFF19211E),
            surfaceContainerHigh: const Color(0xFF222B27),
            surfaceContainerHighest: const Color(0xFF2C3631),
            outline: const Color(0xFF88928D),
            outlineVariant: const Color(0xFF3E4843),
          );
  }

  /// Arabic needs generous line height or the diacritics clip against the
  /// line above.
  static TextTheme _textTheme(TextTheme base) {
    return base.copyWith(
      headlineSmall: base.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
      titleLarge: base.titleLarge?.copyWith(fontWeight: FontWeight.w700),
      titleMedium: base.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      bodyLarge: base.bodyLarge?.copyWith(height: 1.5),
      bodyMedium: base.bodyMedium?.copyWith(height: 1.5),
    );
  }

  /// The Quran verse style, sized by the user's font-scale setting.
  static TextStyle quranVerse(BuildContext context, double scale) {
    return TextStyle(
      fontFamily: _fontFamily,
      fontSize: 18 * scale,
      height: 1.9,
      fontWeight: FontWeight.w500,
      color: Theme.of(context).extension<SakinaColors>()!.verseText,
    );
  }
}
