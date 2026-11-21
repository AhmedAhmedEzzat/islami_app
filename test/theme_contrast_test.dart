import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakina/core/theme/app_colors.dart';
import 'package:sakina/core/theme/app_theme.dart';

/// WCAG 2.x contrast ratio between two opaque colours.
double contrast(Color a, Color b) {
  double lum(Color c) {
    double ch(double v) =>
        v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
    return 0.2126 * ch(c.r) + 0.7152 * ch(c.g) + 0.0722 * ch(c.b);
  }

  final la = lum(a), lb = lum(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  for (final brightness in Brightness.values) {
    group('$brightness theme', () {
      final s = AppTheme.schemeFor(brightness);
      final extras =
          brightness == Brightness.light ? SakinaColors.light : SakinaColors.dark;

      // Body text: AA for normal text (4.5:1).
      final textPairs = <String, (Color, Color)>{
        'onSurface/surface': (s.onSurface, s.surface),
        'onSurface/surfaceContainerHighest':
            (s.onSurface, s.surfaceContainerHighest),
        'onSurfaceVariant/surface': (s.onSurfaceVariant, s.surface),
        'onSurfaceVariant/surfaceContainerLow':
            (s.onSurfaceVariant, s.surfaceContainerLow),
        'onSurfaceVariant/surfaceContainerHigh':
            (s.onSurfaceVariant, s.surfaceContainerHigh),
        'primary/surface': (s.primary, s.surface),
        'primary/surfaceContainerLow': (s.primary, s.surfaceContainerLow),
        'onPrimary/primary': (s.onPrimary, s.primary),
        'onPrimaryContainer/primaryContainer':
            (s.onPrimaryContainer, s.primaryContainer),
        'onSecondaryContainer/secondaryContainer':
            (s.onSecondaryContainer, s.secondaryContainer),
        'onSecondary/secondary': (s.onSecondary, s.secondary),
        'onTertiary/tertiary': (s.onTertiary, s.tertiary),
        'tertiary/surface': (s.tertiary, s.surface),
        'onTertiaryContainer/tertiaryContainer':
            (s.onTertiaryContainer, s.tertiaryContainer),
        'onError/error': (s.onError, s.error),
        'onInverseSurface/inverseSurface': (s.onInverseSurface, s.inverseSurface),
        'verseText/versePanel': (extras.verseText, extras.versePanel),
        'nextPrayer/surface': (extras.nextPrayer, s.surface),
      };
      for (final MapEntry(key: name, value: (fg, bg)) in textPairs.entries) {
        test('$name is at least 4.5:1', () {
          expect(contrast(fg, bg), greaterThanOrEqualTo(4.5));
        });
      }

      // Controls and borders: AA for non-text UI (3:1).
      test('outline stands out from the surface', () {
        expect(contrast(s.outline, s.surface), greaterThanOrEqualTo(3));
      });

      test('cards are distinguishable from the page', () {
        expect(s.surfaceContainerLow, isNot(s.surface));
      });
    });
  }
}
