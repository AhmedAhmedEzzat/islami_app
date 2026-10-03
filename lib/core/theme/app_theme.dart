import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_tokens.dart';

/// Material 3 themes for Sakina.
///
/// A single green seed drives both brightnesses. `fontFamily` is set once here
/// rather than repeated on every `TextStyle`, which is how the old theme did it.
abstract final class AppTheme {
  /// Material green 400. A lighter green desaturates towards white once
  /// Material 3 derives the dark scheme, which loses the identity entirely.
  static const Color seed = Color(0xFF66BB6A);

  static const String _fontFamily = 'Janna';

  static ThemeData get light => _build(Brightness.light, SakinaColors.light);
  static ThemeData get dark => _build(Brightness.dark, SakinaColors.dark);

  static ThemeData _build(Brightness brightness, SakinaColors extras) {
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
    );

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
