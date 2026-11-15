import 'package:flutter/foundation.dart';

import '../constants/prefs_keys.dart';
import 'shared_prefs_helper.dart';

/// Adhkar the reader has kept, by their Hisn al-Muslim id. A [ValueNotifier]
/// so the index and an open chapter both follow a change made in either.
abstract final class AzkarFavourites {
  static final ValueNotifier<Set<int>> notifier = ValueNotifier(_read());

  static Set<int> _read() => {
    for (final s in LocalStorageServices.getStringList(PrefsKeys.azkarFavourites) ?? const <String>[]) ?int.tryParse(s),
  };

  /// Re-read storage (after init or a restore, and in tests).
  static void reload() => notifier.value = _read();

  static bool contains(int id) => notifier.value.contains(id);

  static Future<void> toggle(int id) async {
    final next = Set<int>.from(notifier.value);
    next.contains(id) ? next.remove(id) : next.add(id);
    notifier.value = next;
    await LocalStorageServices.setStringList(PrefsKeys.azkarFavourites, [for (final n in next) '$n']);
  }
}
