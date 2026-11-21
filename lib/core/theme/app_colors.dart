import 'package:material_ui/material_ui.dart';

/// The colours Material 3 has no slot for.
///
/// Anything that maps onto a real `ColorScheme` role (primary, surface,
/// outline, error...) must use that role instead of being added here.
@immutable
class SakinaColors extends ThemeExtension<SakinaColors> {
  const SakinaColors({
    required this.versePanel,
    required this.verseText,
    required this.nextPrayer,
    required this.ornamentTint,
  });

  /// Background of a single Quran verse card.
  final Color versePanel;

  /// Text drawn on [versePanel].
  final Color verseText;

  /// Highlight for the upcoming prayer in the prayer strip.
  final Color nextPrayer;

  /// Tint applied to the decorative PNG ornaments.
  final Color ornamentTint;

  /// A pale sage page for the verses, with ink a shade darker than body
  /// text; the ornaments are gold so they read as decoration, not content.
  static const light = SakinaColors(
    versePanel: Color(0xFFEEF4EF),
    verseText: Color(0xFF0F3328),
    nextPrayer: Color(0xFF1F6B57),
    ornamentTint: Color(0xFF9A7426),
  );

  static const dark = SakinaColors(
    versePanel: Color(0xFF16221D),
    verseText: Color(0xFFE2EEE7),
    nextPrayer: Color(0xFF86D5B9),
    ornamentTint: Color(0xFFE3BE78),
  );

  @override
  SakinaColors copyWith({
    Color? versePanel,
    Color? verseText,
    Color? nextPrayer,
    Color? ornamentTint,
  }) {
    return SakinaColors(
      versePanel: versePanel ?? this.versePanel,
      verseText: verseText ?? this.verseText,
      nextPrayer: nextPrayer ?? this.nextPrayer,
      ornamentTint: ornamentTint ?? this.ornamentTint,
    );
  }

  @override
  SakinaColors lerp(ThemeExtension<SakinaColors>? other, double t) {
    if (other is! SakinaColors) return this;
    return SakinaColors(
      versePanel: Color.lerp(versePanel, other.versePanel, t)!,
      verseText: Color.lerp(verseText, other.verseText, t)!,
      nextPrayer: Color.lerp(nextPrayer, other.nextPrayer, t)!,
      ornamentTint: Color.lerp(ornamentTint, other.ornamentTint, t)!,
    );
  }
}

/// Convenience accessor so widgets read `context.sakina.versePanel`.
extension SakinaColorsX on BuildContext {
  SakinaColors get sakina => Theme.of(this).extension<SakinaColors>()!;
  ColorScheme get colors => Theme.of(this).colorScheme;
  TextTheme get texts => Theme.of(this).textTheme;
}
