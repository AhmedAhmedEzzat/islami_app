import 'package:flutter/widgets.dart';

import '../../models/sura_data_model.dart';

/// The bottom tabs, in order.
abstract final class AppTab {
  static const int home = 0;
  static const int quran = 1;
  static const int prayer = 2;
  static const int azkar = 3;
  static const int more = 4;
}

/// Lets any screen move between tabs, e.g. Home's "next prayer" card opening
/// the Prayer tab, or "continue reading" opening the sura in the Quran tab.
class LayoutScope extends InheritedWidget {
  const LayoutScope({
    super.key,
    required this.selectTab,
    required this.openSura,
    required super.child,
  });

  final void Function(int tab) selectTab;

  /// Switches to the Quran tab and opens [sura], optionally at [ayah] or at
  /// a mushaf [page].
  final void Function(SuraDataModel sura, {int? ayah, int? page}) openSura;

  static LayoutScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<LayoutScope>();

  @override
  bool updateShouldNotify(LayoutScope old) => false;
}

/// Distraction-free reading: while on, the layout hides the bottom tabs and
/// the now-playing bar. The mushaf turns it on and off with a tap.
abstract final class FocusMode {
  static final ValueNotifier<bool> on = ValueNotifier(false);
}
