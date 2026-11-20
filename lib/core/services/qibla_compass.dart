import 'dart:math' as math;

import 'package:adhan/adhan.dart' show Coordinates;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// The arithmetic behind the Qibla compass, kept apart from the screen so it
/// can be tested.
abstract final class QiblaCompass {
  static const _channel = MethodChannel('sakina/compass');

  /// Angle in [0, 360).
  static double normalize(double degrees) {
    final d = degrees % 360;
    return d < 0 ? d + 360 : d;
  }

  /// How far (degrees, -180..180) the phone must turn to face [qibla].
  /// Positive is clockwise (to the right).
  static double turnNeeded(double heading, double qibla) {
    var d = normalize(qibla - heading);
    if (d > 180) d -= 360;
    return d;
  }

  /// Magnetic declination at [c], degrees east of true north.
  ///
  /// Android's compass reads magnetic north, but the Qibla bearing is from
  /// true north; the difference is up to 20 degrees in some countries, which
  /// is why the arrow was wrong on some phones. iOS already reports true
  /// north, so nothing is added there.
  static Future<double> declination(Coordinates c) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return 0;
    try {
      final d = await _channel.invokeMethod<double>('declination', {
        'latitude': c.latitude,
        'longitude': c.longitude,
      });
      return d ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// Whether the phone has a magnetometer.
  ///
  /// Some budget Android phones have none, and on those the compass plugin
  /// still streams a heading of 0, so the dial would sit frozen pointing
  /// north. Anywhere the answer cannot be had it is taken to be yes, and the
  /// stream itself decides.
  static Future<bool> hasCompass() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return true;
    try {
      return await _channel.invokeMethod<bool>('hasCompass') ?? true;
    } catch (_) {
      return true;
    }
  }

  /// Whether a reading from the compass plugin can be used.
  ///
  /// On iOS the plugin passes on Core Location's true heading, which is -1
  /// while there is no location fix. It adds 90 or 180 for a phone held
  /// sideways or upside down, so other negative readings are real headings
  /// and only the bare -1 of a phone held upright is thrown away. Android's
  /// run from -180 to 180 and are all valid.
  static bool isValidHeading(double heading, {TargetPlatform? platform}) =>
      !((platform ?? defaultTargetPlatform) == TargetPlatform.iOS && heading == -1);

  /// [turn] (see [turnNeeded]) in steps of [step] degrees, never 0, for a
  /// screen reader: announcing every degree as the phone turns would talk
  /// over everything else.
  static int spokenDegrees(double turn, {int step = 10}) {
    final d = (turn.abs() / step).round() * step;
    return d < step ? step : d;
  }

  /// Whether the reported accuracy says the compass should be calibrated.
  ///
  /// flutter_compass gives 15, 30 or 45 on Android for high, medium and low,
  /// and nothing when the magnetometer is unreliable. On iOS it is the
  /// heading's error in degrees, negative or missing when invalid.
  static bool needsCalibration(double? accuracy, {TargetPlatform? platform}) {
    final p = platform ?? defaultTargetPlatform;
    if (accuracy == null || accuracy < 0) return true;
    if (p == TargetPlatform.android) return accuracy >= 45;
    return accuracy > 25;
  }
}

/// Smooths a stream of compass headings.
///
/// Raw headings jitter by a few degrees even on a still phone. Averaging the
/// direction as a unit vector, rather than the angle, keeps the 359°→1°
/// crossing from sending the dial the long way round. Big turns are followed
/// quickly and small shakes are damped.
class HeadingFilter {
  HeadingFilter({this.slow = 0.12, this.fast = 0.5});

  /// Weight of a new reading when it is close to the current heading.
  final double slow;

  /// Weight of a new reading when the phone is turning quickly.
  final double fast;

  double? _x;
  double? _y;

  double? get value {
    final x = _x, y = _y;
    if (x == null || y == null) return null;
    return QiblaCompass.normalize(math.atan2(y, x) * 180 / math.pi);
  }

  /// Feeds one reading in degrees and returns the smoothed heading.
  double add(double degrees) {
    final r = degrees * math.pi / 180;
    final nx = math.cos(r), ny = math.sin(r);
    final current = value;
    if (current == null) {
      _x = nx;
      _y = ny;
      return QiblaCompass.normalize(degrees);
    }
    // 0 when the new reading agrees, 1 at 30 degrees or more away.
    final gap = (QiblaCompass.turnNeeded(current, degrees).abs() / 30).clamp(0.0, 1.0);
    final a = slow + (fast - slow) * gap;
    _x = _x! + a * (nx - _x!);
    _y = _y! + a * (ny - _y!);
    return value!;
  }

  void reset() {
    _x = null;
    _y = null;
  }
}
