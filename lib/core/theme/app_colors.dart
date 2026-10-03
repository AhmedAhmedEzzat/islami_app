import 'package:flutter/material.dart';

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

  static const light = SakinaColors(
    versePanel: Color(0xFFE8F5E9),
    verseText: Color(0xFF1B3B1E),
    nextPrayer: Color(0xFF2E7D32),
    ornamentTint: Color(0xFF2E7D32),
  );

  static const dark = SakinaColors(
    versePanel: Color(0xFF1E3322),
    verseText: Color(0xFFDCEFDD),
    nextPrayer: Color(0xFF81C784),
    ornamentTint: Color(0xFF81C784),
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
