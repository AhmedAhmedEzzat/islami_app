import 'dart:async';

import 'package:flutter/foundation.dart';

/// When recitation or the radio should stop on its own.
@immutable
class SleepSetting {
  const SleepSetting.at(DateTime this.endsAt) : endOfSura = false;
  const SleepSetting.endOfSura() : endsAt = null, endOfSura = true;

  final DateTime? endsAt;

  /// Stop when the sura being recited ends, instead of at a time.
  final bool endOfSura;

  Duration remaining(DateTime now) {
    final end = endsAt;
    if (end == null) return Duration.zero;
    final left = end.difference(now);
    return left.isNegative ? Duration.zero : left;
  }
}

/// A sleep timer shared by Quran recitation and the radio: pick a time, or
/// the end of the sura, and audio stops by itself.
abstract final class SleepTimer {
  static const List<int> minuteChoices = [15, 30, 45, 60, 90];

  static final ValueNotifier<SleepSetting?> setting = ValueNotifier(null);
  static Timer? _timer;

  /// Stops all audio. Set from `main()` once the players exist.
  static VoidCallback? onFire;

  static void start(Duration duration, {DateTime? now}) {
    cancel();
    setting.value = SleepSetting.at((now ?? DateTime.now()).add(duration));
    _timer = Timer(duration, _fire);
  }

  static void stopAtEndOfSura() {
    cancel();
    setting.value = const SleepSetting.endOfSura();
  }

  static void cancel() {
    _timer?.cancel();
    _timer = null;
    setting.value = null;
  }

  /// Called by the player when a sura ends. True if it should stop there,
  /// which also clears the timer.
  static bool takeEndOfSura() {
    if (setting.value?.endOfSura != true) return false;
    cancel();
    return true;
  }

  static void _fire() {
    _timer = null;
    setting.value = null;
    onFire?.call();
  }
}
