import 'package:flutter/widgets.dart';

/// Spacing scale. Every gap in the app should come from here rather than a
/// literal, so rhythm stays consistent as screens are added.
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;

  static const EdgeInsets pageH = EdgeInsets.symmetric(horizontal: lg);
  static const EdgeInsets card = EdgeInsets.all(lg);
}

abstract final class AppRadius {
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double pill = 999;

  static const BorderRadius cardRadius = BorderRadius.all(Radius.circular(md));
  static const BorderRadius pillRadius = BorderRadius.all(Radius.circular(pill));
}

abstract final class AppDurations {
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 250);
  static const Duration slow = Duration(milliseconds: 400);
}

/// How strongly the decorative artwork shows through behind a header.
///
/// The app ships heavy full-bleed photographs. At full strength they make body
/// text unreadable in light mode, so they are reduced to a faint ornament whose
/// weight depends on the brightness.
abstract final class AppOrnament {
  static const double lightOpacity = 0.07;
  static const double darkOpacity = 0.20;
  static const double height = 180;
}
