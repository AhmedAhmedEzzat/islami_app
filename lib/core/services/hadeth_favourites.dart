import 'package:flutter/foundation.dart';

import '../constants/prefs_keys.dart';
import 'shared_prefs_helper.dart';

/// Favourite ahadeth, by file number. A [ValueNotifier] so any screen
/// showing a heart updates when another changes it.
abstract final class HadethFavourites {
  static final ValueNotifier<Set<int>> notifier = ValueNotifier(_read());

  static Set<int> _read() => {
    for (final s in LocalStorageServices.getStringList(PrefsKeys.hadethFavourites) ?? const <String>[])
      ?int.tryParse(s),
  };

  /// Re-read storage (after init, or in tests).
  static void reload() => notifier.value = _read();

  static bool contains(int number) => notifier.value.contains(number);

  static Future<void> toggle(int number) async {
    final next = Set<int>.from(notifier.value);
    next.contains(number) ? next.remove(number) : next.add(number);
    notifier.value = next;
    await LocalStorageServices.setStringList(
      PrefsKeys.hadethFavourites,
      [for (final n in next) '$n'],
    );
  }
}
