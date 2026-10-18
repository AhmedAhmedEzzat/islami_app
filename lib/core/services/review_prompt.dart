import 'package:flutter/foundation.dart';
import 'package:in_app_review/in_app_review.dart';

import '../constants/prefs_keys.dart';
import 'shared_prefs_helper.dart';

/// Asks for a store rating, rarely, and only right after something went well.
///
/// A "good moment" is a day with all five prayers logged, or today's khatma
/// portion finished. The review card is requested once there have been
/// [momentsNeeded] since the last ask, the app has been in use for
/// [minAge], the last ask was at least [gap] ago, and it has been asked
/// fewer than [maxAsks] times. The store then decides whether to show it.
abstract final class ReviewPrompt {
  static const int momentsNeeded = 3;
  static const Duration minAge = Duration(days: 5);
  static const Duration gap = Duration(days: 120);
  static const int maxAsks = 3;

  /// The rule, without storage, for tests.
  @visibleForTesting
  static bool shouldAsk({
    required DateTime now,
    required DateTime? firstUse,
    required DateTime? lastAsked,
    required int moments,
    required int asks,
  }) {
    if (firstUse == null || now.difference(firstUse) < minAge) return false;
    if (asks >= maxAsks || moments < momentsNeeded) return false;
    return lastAsked == null || now.difference(lastAsked) >= gap;
  }

  static DateTime? _date(String key) {
    final ms = LocalStorageServices.getInt(key);
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  /// Records the first day of use. Call on every launch; only the first sticks.
  static Future<void> noteLaunch({DateTime? now}) async {
    if (LocalStorageServices.getInt(PrefsKeys.reviewFirstUse) != null) return;
    await LocalStorageServices.setInt(
      PrefsKeys.reviewFirstUse,
      (now ?? DateTime.now()).millisecondsSinceEpoch,
    );
  }

  /// Counts a good moment, and asks for a review when the time is right.
  static Future<void> noteGoodMoment({DateTime? now}) async {
    final at = now ?? DateTime.now();
    final moments = (LocalStorageServices.getInt(PrefsKeys.reviewMoments) ?? 0) + 1;
    await LocalStorageServices.setInt(PrefsKeys.reviewMoments, moments);
    final asks = LocalStorageServices.getInt(PrefsKeys.reviewAsks) ?? 0;
    if (!shouldAsk(
      now: at,
      firstUse: _date(PrefsKeys.reviewFirstUse),
      lastAsked: _date(PrefsKeys.reviewLastAsked),
      moments: moments,
      asks: asks,
    )) {
      return;
    }
    await LocalStorageServices.setInt(PrefsKeys.reviewLastAsked, at.millisecondsSinceEpoch);
    await LocalStorageServices.setInt(PrefsKeys.reviewAsks, asks + 1);
    await LocalStorageServices.setInt(PrefsKeys.reviewMoments, 0);
    if (kIsWeb) return;
    try {
      final review = InAppReview.instance;
      if (await review.isAvailable()) await review.requestReview();
    } catch (e) {
      debugPrint('Review prompt unavailable: $e');
    }
  }

  /// Opens the app's store page, from "Rate Sakina".
  static Future<void> openStore() async {
    try {
      await InAppReview.instance.openStoreListing();
    } catch (e) {
      debugPrint('Store listing unavailable: $e');
    }
  }
}
