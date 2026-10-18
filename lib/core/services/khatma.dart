import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../constants/prefs_keys.dart';
import 'mushaf_layout.dart';
import 'shared_prefs_helper.dart';

/// A plan to read the whole mushaf in a set number of days.
///
/// Progress is the furthest page reached by turning pages in order, so
/// jumping ahead to look something up does not count as reading it.
@immutable
class KhatmaPlan {
  const KhatmaPlan({required this.start, required this.days, this.furthest = 0});

  /// The day the plan began, at midnight.
  final DateTime start;
  final int days;

  /// The last page read, 0 before the first.
  final int furthest;

  static const int pages = MushafLayout.pageCount;

  static const List<int> dayChoices = [7, 10, 15, 20, 30, 60, 90];

  bool get isComplete => furthest >= pages;

  /// 0-based day of the plan for [now], from 0 to [days] - 1.
  int dayIndex(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    // Calendar days, not 24-hour spans, so a DST change cannot skip a day.
    final elapsed = DateTime.utc(today.year, today.month, today.day)
        .difference(DateTime.utc(start.year, start.month, start.day))
        .inDays;
    return elapsed.clamp(0, days - 1);
  }

  /// The page the reader should have reached by the end of day [index].
  int targetFor(int index) => (pages * (index + 1) / days).ceil().clamp(1, pages);

  /// Today's portion: from the next unread page to today's target. Empty
  /// (from > to) once today's reading is done.
  ({int from, int to}) today(DateTime now) =>
      (from: furthest + 1, to: targetFor(dayIndex(now)));

  /// Pages left to read today.
  int pagesLeftToday(DateTime now) {
    final t = today(now);
    return t.to >= t.from ? t.to - t.from + 1 : 0;
  }

  /// Share of the whole mushaf read, 0..1.
  double get progress => furthest / pages;

  KhatmaPlan copyWith({int? furthest}) =>
      KhatmaPlan(start: start, days: days, furthest: furthest ?? this.furthest);

  Map<String, Object> toJson() => {
    'start': start.toIso8601String(),
    'days': days,
    'furthest': furthest,
  };

  static KhatmaPlan? fromJson(Object? json) {
    if (json is! Map) return null;
    final start = DateTime.tryParse('${json['start']}');
    final days = json['days'];
    final furthest = json['furthest'];
    if (start == null || days is! int || days < 1 || furthest is! int) return null;
    return KhatmaPlan(start: start, days: days, furthest: furthest.clamp(0, pages));
  }

  @override
  bool operator ==(Object other) =>
      other is KhatmaPlan && other.start == start && other.days == days && other.furthest == furthest;

  @override
  int get hashCode => Object.hash(start, days, furthest);
}

/// The reader's current khatma, if any, kept in storage.
abstract final class Khatma {
  static final ValueNotifier<KhatmaPlan?> notifier = ValueNotifier(_read());

  static KhatmaPlan? _read() {
    final raw = LocalStorageServices.getString(PrefsKeys.khatma);
    if (raw == null || raw.isEmpty) return null;
    try {
      return KhatmaPlan.fromJson(jsonDecode(raw));
    } on FormatException {
      return null;
    }
  }

  /// A plan is running and not yet complete.
  static bool get isActive {
    final plan = notifier.value;
    return plan != null && !plan.isComplete;
  }

  /// Re-reads storage, for tests and for after storage is first ready.
  static void reload() => notifier.value = _read();

  static Future<void> _save(KhatmaPlan? plan) async {
    notifier.value = plan;
    await LocalStorageServices.setString(PrefsKeys.khatma, plan == null ? '' : jsonEncode(plan.toJson()));
  }

  static Future<void> start(int days, {DateTime? now}) {
    final n = now ?? DateTime.now();
    return _save(KhatmaPlan(start: DateTime(n.year, n.month, n.day), days: days));
  }

  static Future<void> stop() => _save(null);

  /// Records that [page] is on screen. Counts only the next page in order.
  /// Returns true when this page completes the khatma.
  static bool notePage(int page) {
    final plan = notifier.value;
    if (plan == null || page != plan.furthest + 1) return false;
    _save(plan.copyWith(furthest: page));
    return page == KhatmaPlan.pages;
  }
}
