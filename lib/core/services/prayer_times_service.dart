import 'package:adhan/adhan.dart';
import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

import '../constants/prefs_keys.dart';
import 'prayer_config.dart';
import 'shared_prefs_helper.dart';

/// The daily prayers, in order. The UI maps these to localized names.
///
/// Named PrayerName rather than Prayer because `adhan` already exports a
/// `Prayer` enum and the two would collide at every call site.
enum PrayerName { fajr, sunrise, dhuhr, asr, maghrib, isha }

/// One prayer row on the Time tab.
class PrayerEntry {
  final PrayerName prayer;
  final DateTime time;

  const PrayerEntry(this.prayer, this.time);
}

/// Where prayer times are being computed for, and how that was decided.
@immutable
class PrayerLocation {
  const PrayerLocation({
    required this.coordinates,
    this.name,
    this.isManual = false,
    this.isFallback = false,
  });

  final Coordinates coordinates;

  /// "Cairo, Egypt", when known.
  final String? name;

  /// Picked by the user rather than read from GPS. Never overwritten by a fix.
  final bool isManual;

  /// Neither GPS nor a manual choice: the built-in default (Cairo).
  final bool isFallback;
}

/// The fully-resolved state of the Time tab.
class PrayerTimesResult {
  final List<PrayerEntry> prayers;
  final PrayerEntry? next;
  final Duration? untilNext;
  final Coordinates coordinates;

  /// True when we fell back to Cairo because location was denied or
  /// unavailable, so the UI can say so instead of silently lying.
  final bool usedFallbackLocation;

  const PrayerTimesResult({
    required this.prayers,
    required this.next,
    required this.untilNext,
    required this.coordinates,
    required this.usedFallbackLocation,
  });

  PrayerEntry entry(PrayerName p) => prayers.firstWhere((e) => e.prayer == p);
}

/// Computes prayer times locally with the `adhan` package.
///
/// No network call is involved: given a date and coordinates the times are
/// derived astronomically, so prayer times work offline.
abstract class PrayerTimesService {
  /// Used when the device will not give us a position.
  static final Coordinates fallbackCoordinates = Coordinates(30.0444, 31.2357);

  // ---------------------------------------------------------------- location

  /// The location to use right now, without touching GPS: a manual choice
  /// wins, then the last GPS fix, then the fallback.
  static PrayerLocation currentLocation() {
    final mLat = LocalStorageServices.getDouble(PrefsKeys.manualLatitude);
    final mLng = LocalStorageServices.getDouble(PrefsKeys.manualLongitude);
    if (mLat != null && mLng != null) {
      return PrayerLocation(
        coordinates: Coordinates(mLat, mLng),
        name: LocalStorageServices.getString(PrefsKeys.manualPlaceName),
        isManual: true,
      );
    }
    final cached = cachedCoordinates();
    if (cached != null) {
      return PrayerLocation(
        coordinates: cached,
        name: LocalStorageServices.getString(PrefsKeys.lastPlaceName),
      );
    }
    return PrayerLocation(coordinates: fallbackCoordinates, isFallback: true);
  }

  /// The last position a real location fix produced, or null if there has
  /// never been one. Lets notifications be scheduled at startup without
  /// asking for location before the user has opened the Time tab.
  static Coordinates? cachedCoordinates() {
    final lat = LocalStorageServices.getDouble(PrefsKeys.lastLatitude);
    final lng = LocalStorageServices.getDouble(PrefsKeys.lastLongitude);
    if (lat == null || lng == null) return null;
    return Coordinates(lat, lng);
  }

  /// Takes a fresh GPS fix unless the user has chosen a city by hand.
  static Future<PrayerLocation>? _refreshing;

  /// Home and the Prayer tab both refresh on open; while one fix is in
  /// flight the other shares it instead of asking the GPS twice.
  static Future<PrayerLocation> refreshLocation() =>
      _refreshing ??= _refreshLocation().whenComplete(() => _refreshing = null);

  static Future<PrayerLocation> _refreshLocation() async {
    final current = currentLocation();
    if (current.isManual) return current;

    final coordinates = await resolveCoordinates();
    if (coordinates == fallbackCoordinates) return current;

    await LocalStorageServices.setDouble(PrefsKeys.lastLatitude, coordinates.latitude);
    await LocalStorageServices.setDouble(PrefsKeys.lastLongitude, coordinates.longitude);
    final name = await placeName(coordinates);
    if (name != null) {
      await LocalStorageServices.setString(PrefsKeys.lastPlaceName, name);
    }
    return PrayerLocation(coordinates: coordinates, name: name ?? current.name);
  }

  static Future<Coordinates> resolveCoordinates() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return fallbackCoordinates;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return fallbackCoordinates;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 10),
        ),
      );
      return Coordinates(position.latitude, position.longitude);
    } catch (e) {
      debugPrint('Falling back to default coordinates: $e');
      return fallbackCoordinates;
    }
  }

  /// "Cairo, Egypt" for a position, via the platform geocoder. Null if the
  /// geocoder is unavailable (no network, no Play services).
  static Future<String?> placeName(Coordinates c) async {
    try {
      final marks = await Geocoding().placemarkFromCoordinates(c.latitude, c.longitude);
      if (marks.isEmpty) return null;
      final m = marks.first;
      final city = <String?>[m.locality, m.subAdministrativeArea, m.administrativeArea]
          .firstWhere((x) => x != null && x.isNotEmpty, orElse: () => null);
      final parts = <String?>[city, m.country].whereType<String>().where((x) => x.isNotEmpty);
      return parts.isEmpty ? null : parts.join(', ');
    } catch (e) {
      debugPrint('Reverse geocoding failed: $e');
      return null;
    }
  }

  /// Looks a city up by name, for people who would rather not share GPS.
  static Future<List<PrayerLocation>> searchCity(String query) async {
    if (query.trim().length < 2) return const [];
    try {
      final hits = await Geocoding().locationFromAddress(query.trim());
      final results = <PrayerLocation>[];
      for (final hit in hits.take(5)) {
        final c = Coordinates(hit.latitude, hit.longitude);
        results.add(
          PrayerLocation(coordinates: c, name: await placeName(c) ?? query.trim(), isManual: true),
        );
      }
      return results;
    } catch (e) {
      debugPrint('City search failed: $e');
      return const [];
    }
  }

  static Future<void> setManualLocation(PrayerLocation location) async {
    await LocalStorageServices.setDouble(PrefsKeys.manualLatitude, location.coordinates.latitude);
    await LocalStorageServices.setDouble(PrefsKeys.manualLongitude, location.coordinates.longitude);
    await LocalStorageServices.setString(PrefsKeys.manualPlaceName, location.name ?? '');
  }

  /// Back to GPS.
  static Future<void> clearManualLocation() => LocalStorageServices.remove([
    PrefsKeys.manualLatitude,
    PrefsKeys.manualLongitude,
    PrefsKeys.manualPlaceName,
  ]);

  // ------------------------------------------------------------------ times

  /// Builds the prayer list for [date]. Pure given its inputs, so it is
  /// directly unit testable.
  static PrayerTimesResult computeFor({
    required Coordinates coordinates,
    required DateTime date,
    PrayerConfig config = const PrayerConfig(),
    bool usedFallbackLocation = false,
  }) {
    final params = config.toParameters();
    final prayers = _entries(PrayerTimes(coordinates, DateComponents.from(date), params));

    PrayerEntry? next;
    for (final prayer in prayers) {
      if (prayer.time.isAfter(date)) {
        next = prayer;
        break;
      }
    }

    // Past Isha, the next prayer is tomorrow's Fajr.
    if (next == null) {
      final tomorrow = PrayerTimes(
        coordinates,
        DateComponents.from(date.add(const Duration(days: 1))),
        params,
      );
      next = PrayerEntry(PrayerName.fajr, tomorrow.fajr);
    }

    return PrayerTimesResult(
      prayers: prayers,
      next: next,
      untilNext: next.time.difference(date),
      coordinates: coordinates,
      usedFallbackLocation: usedFallbackLocation,
    );
  }

  /// Every day of [month] (any date within it), for the monthly timetable.
  static List<(DateTime, List<PrayerEntry>)> computeMonth({
    required Coordinates coordinates,
    required DateTime month,
    PrayerConfig config = const PrayerConfig(),
  }) {
    final params = config.toParameters();
    final days = DateTime(month.year, month.month + 1, 0).day;
    return [
      for (var d = 1; d <= days; d++)
        (
          DateTime(month.year, month.month, d),
          _entries(
            PrayerTimes(
              coordinates,
              DateComponents(month.year, month.month, d),
              params,
            ),
          ),
        ),
    ];
  }

  static List<PrayerEntry> _entries(PrayerTimes t) => [
    PrayerEntry(PrayerName.fajr, t.fajr),
    PrayerEntry(PrayerName.sunrise, t.sunrise),
    PrayerEntry(PrayerName.dhuhr, t.dhuhr),
    PrayerEntry(PrayerName.asr, t.asr),
    PrayerEntry(PrayerName.maghrib, t.maghrib),
    PrayerEntry(PrayerName.isha, t.isha),
  ];

  /// Qibla bearing from [c], degrees clockwise from true north.
  static double qiblaBearing(Coordinates c) => Qibla(c).direction;
}
