import 'dart:async';
import 'dart:math' as math;

import 'package:adhan/adhan.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_compass/flutter_compass.dart';

import '../../../core/services/prayer_times_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/l10n_ext.dart';

/// A compass that points at the Kaaba.
class QiblaView extends StatefulWidget {
  const QiblaView({super.key, required this.location});

  final PrayerLocation location;

  /// Great-circle distance to the Kaaba, kilometres.
  static double distanceToKaabaKm(Coordinates from) {
    const r = 6371.0;
    final kaaba = Qibla.MAKKAH;
    double rad(double d) => d * math.pi / 180;
    final dLat = rad(kaaba.latitude - from.latitude);
    final dLng = rad(kaaba.longitude - from.longitude);
    final a =
        math.pow(math.sin(dLat / 2), 2) +
        math.cos(rad(from.latitude)) *
            math.cos(rad(kaaba.latitude)) *
            math.pow(math.sin(dLng / 2), 2);
    return 2 * r * math.asin(math.sqrt(a));
  }

  /// How far (degrees, -180..180) the phone must turn to face the Qibla.
  static double turnNeeded(double heading, double qibla) {
    var d = (qibla - heading) % 360;
    if (d > 180) d -= 360;
    return d;
  }

  @override
  State<QiblaView> createState() => _QiblaViewState();
}

class _QiblaViewState extends State<QiblaView> {
  StreamSubscription<CompassEvent>? _sub;
  double? _heading;
  double? _accuracy;
  bool _noSensor = false;
  bool _wasFacing = false;

  late final double _qibla = PrayerTimesService.qiblaBearing(widget.location.coordinates);

  @override
  void initState() {
    super.initState();
    final events = FlutterCompass.events;
    if (events == null) {
      _noSensor = true;
      return;
    }
    _sub = events.listen((e) {
      if (!mounted) return;
      if (e.heading == null) {
        setState(() => _noSensor = true);
        return;
      }
      final facing = QiblaView.turnNeeded(e.heading!, _qibla).abs() < 5;
      // One tap of haptics on arriving, not a continuous buzz while aligned.
      if (facing && !_wasFacing) HapticFeedback.mediumImpact();
      setState(() {
        _heading = e.heading;
        _accuracy = e.accuracy;
        _wasFacing = facing;
      });
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = context.colors;
    final heading = _heading;
    final turn = heading == null ? null : QiblaView.turnNeeded(heading, _qibla);
    final facing = turn != null && turn.abs() < 5;
    final km = QiblaView.distanceToKaabaKm(widget.location.coordinates);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.qiblaTitle)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        children: [
          Text(
            l10n.qiblaBearing(_qibla.round()),
            textAlign: TextAlign.center,
            style: context.texts.titleMedium,
          ),
          Text(
            l10n.qiblaDistance(km.round().toString()),
            textAlign: TextAlign.center,
            style: context.texts.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.xxl),
          AspectRatio(
            aspectRatio: 1,
            child: AnimatedContainer(
              duration: AppDurations.normal,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: facing ? scheme.primaryContainer : scheme.surfaceContainer,
                border: Border.all(
                  color: facing ? scheme.primary : scheme.outlineVariant,
                  width: 3,
                ),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // The dial turns with the phone so north stays north.
                  AnimatedRotation(
                    duration: const Duration(milliseconds: 200),
                    turns: -(heading ?? 0) / 360,
                    child: _Dial(color: scheme.onSurfaceVariant),
                  ),
                  // The needle points at the Qibla relative to the phone.
                  AnimatedRotation(
                    duration: const Duration(milliseconds: 200),
                    turns: ((turn ?? _qibla) / 360),
                    child: Column(
                      children: [
                        Icon(Icons.navigation, size: 56, color: scheme.primary),
                        const Text('🕋', style: TextStyle(fontSize: 26)),
                        const Spacer(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            _noSensor ? l10n.qiblaNoSensor : (facing ? l10n.qiblaFacing : l10n.qiblaTurn),
            textAlign: TextAlign.center,
            style: context.texts.titleMedium?.copyWith(
              color: facing ? scheme.primary : scheme.onSurface,
              fontWeight: facing ? FontWeight.w700 : null,
            ),
          ),
          // flutter_compass reports accuracy in degrees on Android; a large
          // value means the magnetometer needs calibrating.
          if (!_noSensor && (_accuracy ?? 0) > 30) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              l10n.qiblaCalibrate,
              textAlign: TextAlign.center,
              style: context.texts.bodySmall?.copyWith(color: scheme.error),
            ),
          ],
        ],
      ),
    );
  }
}

class _Dial extends StatelessWidget {
  const _Dial({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    Widget mark(String text, Alignment a, {bool north = false}) => Align(
      alignment: a,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Text(
          text,
          style: TextStyle(
            color: north ? Colors.red : color,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
    return Stack(
      children: [
        mark('N', Alignment.topCenter, north: true),
        mark('E', Alignment.centerRight),
        mark('S', Alignment.bottomCenter),
        mark('W', Alignment.centerLeft),
      ],
    );
  }
}
