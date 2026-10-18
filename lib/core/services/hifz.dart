import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../constants/constants.dart';
import '../constants/prefs_keys.dart';
import 'shared_prefs_helper.dart';

enum HifzStatus { learning, memorised }

/// Where one sura stands in the reader's memorisation.
@immutable
class HifzEntry {
  const HifzEntry(this.status, {this.reviewed, this.step = 0});

  final HifzStatus status;

  /// The day it was memorised or last revised, for a memorised sura.
  final DateTime? reviewed;

  /// Index into [Hifz.intervals]: how long until the next revision.
  final int step;

  /// The day the next revision falls due, for a memorised sura.
  DateTime? get due {
    final r = reviewed;
    if (status != HifzStatus.memorised || r == null) return null;
    // Calendar days, so a clock change cannot move it.
    return DateTime(r.year, r.month, r.day + Hifz.intervals[step]);
  }

  Map<String, dynamic> toJson() => {
    's': status.name,
    if (reviewed case final r?) 'r': '${r.year}-${r.month}-${r.day}',
    if (step > 0) 'i': step,
  };

  static HifzEntry? fromJson(Object? json) {
    if (json is! Map) return null;
    final status = HifzStatus.values.asNameMap()[json['s']];
    if (status == null) return null;
    DateTime? reviewed;
    final parts = (json['r'] as String?)?.split('-').map(int.tryParse).toList();
    if (parts != null && parts.length == 3 && !parts.contains(null)) {
      reviewed = DateTime(parts[0]!, parts[1]!, parts[2]!);
    }
    final step = (json['i'] as int? ?? 0).clamp(0, Hifz.intervals.length - 1);
    return HifzEntry(status, reviewed: reviewed, step: step);
  }
}

/// The reader's memorisation: which suras are being learnt or are known by
/// heart, and when each known sura is next due for revision.
///
/// Revision is spaced: a sura revised comfortably waits longer each time
/// ([intervals]), and one that was hard comes back the next day.
abstract final class Hifz {
  static const List<int> intervals = [1, 2, 4, 7, 14, 30];

  /// Bumps on every change, for screens showing progress.
  static final ValueNotifier<int> changes = ValueNotifier(0);

  static Map<int, HifzEntry> all() {
    final raw = LocalStorageServices.getString(PrefsKeys.hifz);
    if (raw == null || raw.isEmpty) return {};
    try {
      return {
        for (final MapEntry(:key, :value) in (jsonDecode(raw) as Map).entries)
          if ((int.tryParse('$key'), HifzEntry.fromJson(value)) case (final sura?, final entry?)) sura: entry,
      };
    } catch (e) {
      debugPrint('Ignoring unreadable hifz progress: $e');
      return {};
    }
  }

  static HifzEntry? of(int sura) => all()[sura];

  /// Sets where [sura] stands; null clears it. Marking it memorised starts
  /// its revisions from tomorrow.
  static Future<void> setStatus(int sura, HifzStatus? status, {DateTime? now}) async {
    final map = all();
    if (status == null) {
      map.remove(sura);
    } else if (map[sura]?.status != status) {
      map[sura] = status == HifzStatus.memorised
          ? HifzEntry(status, reviewed: _day(now ?? DateTime.now()))
          : HifzEntry(status);
    }
    await _save(map);
  }

  /// Records a revision of [sura] today: [easy] spaces the next one further
  /// out, otherwise it comes back tomorrow.
  static Future<void> revised(int sura, {required bool easy, DateTime? now}) async {
    final map = all();
    final entry = map[sura];
    if (entry == null || entry.status != HifzStatus.memorised) return;
    map[sura] = HifzEntry(
      HifzStatus.memorised,
      reviewed: _day(now ?? DateTime.now()),
      step: easy ? (entry.step + 1).clamp(0, intervals.length - 1) : 0,
    );
    await _save(map);
  }

  /// Memorised suras due for revision by [day], the most overdue first.
  static List<int> dueBy(DateTime day) {
    final today = _day(day);
    final due = [
      for (final MapEntry(key: sura, value: e) in all().entries)
        if (e.due case final d? when !d.isAfter(today)) (sura, d),
    ]..sort((a, b) => a.$2 != b.$2 ? a.$2.compareTo(b.$2) : a.$1.compareTo(b.$1));
    return [for (final (sura, _) in due) sura];
  }

  static int count(HifzStatus status) => all().values.where((e) => e.status == status).length;

  /// Verses in the memorised suras, out of the Quran's 6,236.
  static int memorisedVerses() => [
    for (final MapEntry(key: sura, value: e) in all().entries)
      if (e.status == HifzStatus.memorised && sura >= 1 && sura <= Constants.suraDataLists.length)
        int.parse(Constants.suraDataLists[sura - 1].suraVersesNumber),
  ].fold(0, (a, b) => a + b);

  static DateTime _day(DateTime t) => DateTime(t.year, t.month, t.day);

  static Future<void> _save(Map<int, HifzEntry> map) async {
    await LocalStorageServices.setString(
      PrefsKeys.hifz,
      jsonEncode({for (final MapEntry(:key, :value) in map.entries) '$key': value.toJson()}),
    );
    changes.value++;
  }
}
