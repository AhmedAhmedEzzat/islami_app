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
