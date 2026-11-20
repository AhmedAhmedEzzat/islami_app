import 'dart:async';
import 'dart:math' as math;

import 'package:adhan/adhan.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_compass/flutter_compass.dart';

import '../../../core/services/notification_refresh.dart';
import '../../../core/services/prayer_times_service.dart';
import '../../../core/services/qibla_compass.dart';
import '../../../core/state/settings_cubit.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/l10n_ext.dart';
import 'location_sheet.dart';

/// A compass that points at the Kaaba.
///
/// The dial turns with the phone so north stays north, and the Kaaba sits on
/// the dial at the Qibla bearing. The marker at the top is the direction the
/// phone is pointing: turn until the Kaaba is under it.
class QiblaView extends StatefulWidget {
  const QiblaView({
    super.key,
    required this.location,
    this.compassEvents,
    this.hasCompass,
  });

  final PrayerLocation location;

  /// For tests; the phone's compass otherwise.
  final Stream<CompassEvent>? compassEvents;

  /// For tests; asks the phone otherwise.
  final Future<bool> Function()? hasCompass;

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
  static double turnNeeded(double heading, double qibla) =>
      QiblaCompass.turnNeeded(heading, qibla);

  /// Facing is entered within [enterWithin] degrees and left beyond
  /// [leaveBeyond], so a steady hand does not flicker in and out of it.
  static const double enterWithin = 4;
  static const double leaveBeyond = 7;

  @override
  State<QiblaView> createState() => _QiblaViewState();
}

class _QiblaViewState extends State<QiblaView> {
  StreamSubscription<CompassEvent>? _sub;
  final _filter = HeadingFilter();
  late PrayerLocation _location = widget.location;
  double _declination = 0;
  double? _heading;
  double? _accuracy;
  bool _noSensor = false;

  /// The phone has no magnetometer, so whatever the stream sends is not a
  /// heading.
  bool _noMagnetometer = false;
  bool _facing = false;
  bool _locating = false;

  /// Calibration advice waits a moment: the first readings often arrive
  /// before the sensor has said how sure it is.
  bool _settled = false;
  Timer? _settle;

  double get _qibla => PrayerTimesService.qiblaBearing(_location.coordinates);

  @override
  void initState() {
    super.initState();
    _loadDeclination();
    if (!_location.isManual) _refreshLocation();
    _settle = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _settled = true);
    });
    final events = widget.compassEvents ?? FlutterCompass.events;
    if (events == null) {
      _noSensor = true;
      return;
    }
    _sub = events.listen(_onCompass, onError: (_) {
      if (mounted) setState(() => _noSensor = true);
    });
    _checkMagnetometer();
  }

  Future<void> _checkMagnetometer() async {
    final hasCompass = await (widget.hasCompass ?? QiblaCompass.hasCompass)();
    if (hasCompass || !mounted) return;
    _sub?.cancel();
    _sub = null;
    setState(() {
      _noMagnetometer = true;
      _noSensor = true;
      _heading = null;
      _facing = false;
    });
  }

  void _onCompass(CompassEvent e) {
    if (!mounted || _noMagnetometer) return;
    final raw = e.heading;
    if (raw == null) {
      // Some phones send one empty reading before the first real one; only
      // a phone that never sends a heading has no compass.
      if (_heading == null) setState(() => _noSensor = true);
      return;
    }
    if (!QiblaCompass.isValidHeading(raw)) return;
    final heading = _filter.add(raw + _declination);
    final off = QiblaCompass.turnNeeded(heading, _qibla).abs();
    final facing = _facing ? off <= QiblaView.leaveBeyond : off <= QiblaView.enterWithin;
    // One tap of haptics on arriving, not a continuous buzz while aligned.
    if (facing && !_facing) HapticFeedback.mediumImpact();
    setState(() {
      _noSensor = false;
      _heading = heading;
      _accuracy = e.accuracy;
      _facing = facing;
    });
  }

  Future<void> _loadDeclination() async {
    final d = await QiblaCompass.declination(_location.coordinates);
    if (!mounted) return;
    // Readings so far were from magnetic north; start the average afresh.
    if ((d - _declination).abs() > 0.1) _filter.reset();
    setState(() => _declination = d);
  }

  Future<void> _refreshLocation() async {
    final before = _location.coordinates;
    setState(() => _locating = true);
    final fresh = await PrayerTimesService.refreshLocation();
    if (!mounted) return;
    setState(() {
      _locating = false;
      _location = fresh;
    });
    _loadDeclination();
    // A new fix is saved for the whole app, so the adhan and the home screen
    // widget move with it, as they do when Home or the Prayer tab finds one.
    if (!_samePlace(before, fresh.coordinates)) _reschedule();
  }

  static bool _samePlace(Coordinates a, Coordinates b) =>
      (a.latitude - b.latitude).abs() < 1e-4 && (a.longitude - b.longitude).abs() < 1e-4;

  void _reschedule() {
    final settings = context.read<SettingsCubit>().state;
    NotificationRefresh.reschedule(settings, Localizations.localeOf(context));
  }

  Future<void> _changeLocation() async {
    final changed = await LocationSheet.show(context);
    if (changed != true || !mounted) return;
    setState(() => _location = PrayerTimesService.currentLocation());
    _loadDeclination();
    if (!_location.isManual) await _refreshLocation();
    if (!mounted) return;
    // Prayer times moved with the place, so the alerts follow.
    _reschedule();
  }

  @override
  void dispose() {
    _settle?.cancel();
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = context.colors;
    final heading = _heading;
    final qibla = _qibla;
    final turn = heading == null ? null : QiblaCompass.turnNeeded(heading, qibla);
    final km = QiblaView.distanceToKaabaKm(_location.coordinates);
    final calibrate = !_noSensor &&
        heading != null &&
        _settled &&
        QiblaCompass.needsCalibration(_accuracy);

    final String status;
    // What a screen reader announces as the phone turns: the same, but in
    // steps of ten degrees, so it is not read out again at every degree.
    final String spoken;
    if (_noSensor) {
      status = spoken = l10n.qiblaNoSensor;
    } else if (turn == null) {
      status = spoken = l10n.qiblaTurn;
    } else if (_facing) {
      status = spoken = l10n.qiblaFacing;
    } else if (turn > 0) {
      status = l10n.qiblaTurnRight(turn.round());
      spoken = l10n.qiblaTurnRight(QiblaCompass.spokenDegrees(turn));
    } else {
      status = l10n.qiblaTurnLeft((-turn).round());
      spoken = l10n.qiblaTurnLeft(QiblaCompass.spokenDegrees(turn));
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.qiblaTitle)),
      body: LayoutBuilder(
        builder: (context, constraints) {
          // The dial fills the width on a phone and stays a sensible size on
          // a tablet or in landscape.
          final dial = math.min(constraints.maxWidth - AppSpacing.xl * 2, 360.0);
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            children: [
              _LocationLine(
                location: _location,
                locating: _locating,
                onChange: _changeLocation,
              ),
              if (_location.isFallback && !_locating) ...[
                const SizedBox(height: AppSpacing.md),
                _FallbackCard(onSet: _changeLocation),
              ],
              const SizedBox(height: AppSpacing.lg),
              Text(
                l10n.qiblaBearing(qibla.round()),
                textAlign: TextAlign.center,
                style: context.texts.titleMedium,
              ),
              Text(
                l10n.qiblaDistance(km.round().toString()),
                textAlign: TextAlign.center,
                style: context.texts.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: AppSpacing.xl),
              Center(
                child: SizedBox.square(
                  dimension: dial,
                  child: Semantics(
                    label: spoken,
                    liveRegion: true,
                    child: _Compass(
                      heading: heading ?? 0,
                      qibla: qibla,
                      facing: _facing,
                      active: heading != null,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              AnimatedSwitcher(
                duration: AppDurations.normal,
                child: Text(
                  status,
                  key: ValueKey(_facing ? 'facing' : _noSensor ? 'none' : 'turn'),
                  textAlign: TextAlign.center,
                  style: context.texts.titleLarge?.copyWith(
                    color: _facing ? scheme.primary : scheme.onSurface,
                    fontWeight: _facing ? FontWeight.w700 : null,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              AnimatedSize(
                duration: AppDurations.normal,
                child: calibrate
                    ? const _CalibrateCard()
                    : const SizedBox(width: double.infinity),
              ),
              if (!_noSensor) ...[
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Icon(Icons.info_outline, size: 18, color: scheme.onSurfaceVariant),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        l10n.qiblaTips,
                        style: context.texts.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// Where the bearing is worked out from, with a way to change it.
class _LocationLine extends StatelessWidget {
  const _LocationLine({
    required this.location,
    required this.locating,
    required this.onChange,
  });

  final PrayerLocation location;
  final bool locating;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = context.colors;
    final place = locating
        ? l10n.qiblaLocating
        : location.isFallback
        ? l10n.defaultLocation
        : location.name ??
              '${location.coordinates.latitude.toStringAsFixed(2)}, '
                  '${location.coordinates.longitude.toStringAsFixed(2)}';
    return Row(
      children: [
        Icon(
          location.isManual ? Icons.location_city_outlined : Icons.my_location,
          size: 18,
          color: scheme.primary,
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            place,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: context.texts.bodyMedium,
          ),
        ),
        if (locating)
          const SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        else
          TextButton(onPressed: onChange, child: Text(l10n.qiblaChangeLocation)),
      ],
    );
  }
}

/// Shown when neither GPS nor a chosen city is known, so the bearing is
/// from the built-in default rather than from where the reader is.
class _FallbackCard extends StatelessWidget {
  const _FallbackCard({required this.onSet});

  final VoidCallback onSet;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = context.colors;
    return Card(
      color: scheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.qiblaFallbackTitle,
              style: context.texts.titleSmall?.copyWith(color: scheme.onErrorContainer),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              l10n.qiblaFallbackBody,
              style: context.texts.bodyMedium?.copyWith(color: scheme.onErrorContainer),
            ),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton(
                onPressed: onSet,
                child: Text(l10n.qiblaSetLocation),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A figure 8 being traced, with the words for it.
class _CalibrateCard extends StatefulWidget {
  const _CalibrateCard();

  @override
  State<_CalibrateCard> createState() => _CalibrateCardState();
}

class _CalibrateCardState extends State<_CalibrateCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = context.colors;
    return Card(
      color: scheme.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          children: [
            SizedBox(
              width: 56,
              height: 40,
              child: AnimatedBuilder(
                animation: _c,
                builder: (context, _) => CustomPaint(
                  painter: _FigureEightPainter(
                    t: _c.value,
                    color: scheme.onTertiaryContainer,
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.qiblaCalibrateTitle,
                    style: context.texts.titleSmall?.copyWith(
                      color: scheme.onTertiaryContainer,
                    ),
                  ),
                  Text(
                    l10n.qiblaCalibrate,
                    style: context.texts.bodySmall?.copyWith(
                      color: scheme.onTertiaryContainer,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FigureEightPainter extends CustomPainter {
  _FigureEightPainter({required this.t, required this.color});

  final double t;
  final Color color;

  Offset _at(double s, Size size) {
    final a = s * 2 * math.pi;
    return Offset(
      size.width / 2 + math.sin(a) * size.width * 0.42,
      size.height / 2 + math.sin(2 * a) * size.height * 0.36,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()..moveTo(_at(0, size).dx, _at(0, size).dy);
    for (var i = 1; i <= 64; i++) {
      final p = _at(i / 64, size);
      path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    canvas.drawCircle(_at(t, size), 5, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_FigureEightPainter old) => old.t != t || old.color != color;
}

/// The dial, the Kaaba on it and the fixed marker for where the phone points.
class _Compass extends StatelessWidget {
  const _Compass({
    required this.heading,
    required this.qibla,
    required this.facing,
    required this.active,
  });

  final double heading;
  final double qibla;
  final bool facing;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final rad = -heading * math.pi / 180;
    final qiblaRad = qibla * math.pi / 180;
    return LayoutBuilder(
      builder: (context, c) {
        final size = c.biggest.shortestSide;
        final ring = size / 2 - 22;
        return Stack(
          alignment: Alignment.center,
          children: [
            AnimatedContainer(
              duration: AppDurations.slow,
              curve: Curves.easeOut,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: facing ? scheme.primaryContainer : scheme.surfaceContainer,
                boxShadow: [
                  if (facing)
                    BoxShadow(
                      color: scheme.primary.withValues(alpha: 0.35),
                      blurRadius: 32,
                      spreadRadius: 4,
                    ),
                ],
              ),
            ),
            AnimatedOpacity(
              duration: AppDurations.slow,
              opacity: active ? 1 : 0.4,
              child: Transform.rotate(
                angle: rad,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(
                      size: Size.square(size),
                      painter: _DialPainter(
                        ticks: scheme.onSurfaceVariant,
                        north: scheme.error,
                        qibla: qibla,
                        qiblaColor: scheme.primary,
                        textStyle: context.texts.titleSmall!,
                        textDirection: Directionality.of(context),
                        letters: context.isArabic ? _DialPainter.arabicLetters : _DialPainter.latinLetters,
                      ),
                    ),
                    // The Kaaba on the ring, kept upright as the dial turns.
                    Transform.translate(
                      offset: Offset(
                        math.sin(qiblaRad) * (ring - 58),
                        -math.cos(qiblaRad) * (ring - 58),
                      ),
                      child: Transform.rotate(
                        angle: -rad,
                        child: AnimatedScale(
                          duration: AppDurations.normal,
                          scale: facing ? 1.25 : 1,
                          child: const Text('🕋', style: TextStyle(fontSize: 30)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Where the top of the phone points.
            Align(
              alignment: Alignment.topCenter,
              child: Icon(
                Icons.arrow_drop_down_rounded,
                size: 44,
                color: facing ? scheme.primary : scheme.onSurface,
              ),
            ),
            AnimatedSwitcher(
              duration: AppDurations.normal,
              transitionBuilder: (child, a) => ScaleTransition(scale: a, child: child),
              child: facing
                  ? Icon(
                      Icons.check_circle,
                      key: const ValueKey('ok'),
                      size: 48,
                      color: scheme.primary,
                    )
                  : Icon(
                      Icons.navigation_rounded,
                      key: const ValueKey('arrow'),
                      size: 40,
                      color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _DialPainter extends CustomPainter {
  _DialPainter({
    required this.ticks,
    required this.north,
    required this.qibla,
    required this.qiblaColor,
    required this.textStyle,
    required this.textDirection,
    required this.letters,
  });

  /// North, east, south and west, in that order.
  static const latinLetters = ['N', 'E', 'S', 'W'];
  static const arabicLetters = ['ش', 'ق', 'ج', 'غ'];

  final Color ticks;
  final Color north;
  final double qibla;
  final Color qiblaColor;
  final TextStyle textStyle;
  final TextDirection textDirection;
  final List<String> letters;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2 - 22;
    final thin = Paint()
      ..color = ticks.withValues(alpha: 0.5)
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    final thick = Paint()
      ..color = ticks
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;

    for (var d = 0; d < 360; d += 5) {
      final a = d * math.pi / 180;
      final long = d % 30 == 0;
      final inner = r - (long ? 12 : 6);
      final dir = Offset(math.sin(a), -math.cos(a));
      canvas.drawLine(c + dir * inner, c + dir * r, long ? thick : thin);
    }

    // A line from the centre to the Qibla, so the target reads at a glance.
    final qa = qibla * math.pi / 180;
    final qdir = Offset(math.sin(qa), -math.cos(qa));
    canvas.drawLine(
      c,
      c + qdir * (r - 78),
      Paint()
        ..color = qiblaColor.withValues(alpha: 0.6)
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );

    for (var i = 0; i < 4; i++) {
      final a = i * math.pi / 2;
      final dir = Offset(math.sin(a), -math.cos(a));
      final tp = TextPainter(
        text: TextSpan(
          text: letters[i],
          style: textStyle.copyWith(
            color: i == 0 ? north : ticks,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: textDirection,
      )..layout();
      final at = c + dir * (r - 26);
      canvas.save();
      canvas.translate(at.dx, at.dy);
      canvas.rotate(a);
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_DialPainter old) =>
      old.qibla != qibla ||
      old.ticks != ticks ||
      old.north != north ||
      old.qiblaColor != qiblaColor ||
      old.textStyle != textStyle ||
      old.letters != letters;
}
