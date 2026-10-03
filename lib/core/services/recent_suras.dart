import 'package:flutter/foundation.dart';

import '../constants/constants.dart';
import '../constants/prefs_keys.dart';
import '../../models/sura_data_model.dart';
import 'shared_prefs_helper.dart';

/// The last few suras opened, newest first.
///
/// A notifier rather than a one-off read: Home and the Quran tab both show the
/// list and either can open a sura, so each must see the other's change.
abstract final class RecentSuras {
  static const int _keep = 5;

  static final ValueNotifier<List<SuraDataModel>> notifier = ValueNotifier(_read());

  static List<SuraDataModel> _read() {
    // Stored as 0-based indices, the format older builds already wrote.
    final stored = LocalStorageServices.getStringList(PrefsKeys.recentSuraIndex) ?? [];
    return stored
        .map(int.tryParse)
        .whereType<int>()
        .where((i) => i >= 0 && i < Constants.suraDataLists.length)
        .map((i) => Constants.suraDataLists[i])
        .toList();
  }

  /// Re-reads storage, for tests that swap the preferences underneath.
  @visibleForTesting
  static void reload() => notifier.value = _read();

  static Future<void> remember(SuraDataModel sura) async {
    final key = '${int.parse(sura.suraID) - 1}';
    final stored = LocalStorageServices.getStringList(PrefsKeys.recentSuraIndex) ?? [];
    stored
      ..remove(key)
      ..insert(0, key);
    await LocalStorageServices.setStringList(
      PrefsKeys.recentSuraIndex,
      stored.take(_keep).toList(),
    );
    notifier.value = _read();
  }
}
