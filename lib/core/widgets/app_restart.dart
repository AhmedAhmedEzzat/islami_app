import 'package:flutter/widgets.dart';

/// Rebuilds every screen from scratch, keeping the app-wide state above it
/// (the cubits), for after a backup is restored: a screen built before would
/// otherwise go on showing, and saving, what it read at the start.
abstract final class AppRestart {
  /// The screens below rebuild whenever this changes.
  static final ValueNotifier<int> generation = ValueNotifier(0);

  /// Fresh for each build of the screens, since a global key kept across a
  /// rebuild would carry the old state over to the new tree.
  static GlobalKey<NavigatorState> navigatorKey = GlobalKey();

  static bool _running = false;

  /// Whether a rebuild is under way.
  static bool get busy => _running;

  static Future<void> _rebuild() async {
    navigatorKey = GlobalKey();
    generation.value++;
    await WidgetsBinding.instance.endOfFrame;
  }

  /// Runs [change] with the old screens already gone, so none of them can
  /// write over it on the way out, then builds the screens again on the
  /// result. A second call while one runs is ignored; false then.
  static Future<bool> around(Future<void> Function() change) async {
    if (_running) return false;
    _running = true;
    try {
      await _rebuild();
      await change();
      await _rebuild();
      return true;
    } finally {
      _running = false;
    }
  }
}
