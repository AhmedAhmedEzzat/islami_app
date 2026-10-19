import 'package:flutter/foundation.dart';

/// A recording the user chose from their own phone.
@immutable
class CustomSound {
  const CustomSound(this.uri, this.title);

  /// A content:// URI the system can play as a notification sound.
  final String uri;
  final String title;

  Map<String, String> toJson() => {'uri': uri, 'title': title};

  static CustomSound? fromJson(Object? json) {
    if (json is! Map || json['uri'] is! String || (json['uri'] as String).isEmpty) return null;
    return CustomSound(json['uri'] as String, json['title'] as String? ?? '');
  }

  @override
  bool operator ==(Object other) => other is CustomSound && other.uri == uri && other.title == title;

  @override
  int get hashCode => Object.hash(uri, title);
}

/// An adhan recording the prayer notification can play.
///
/// A bundled muezzin is two raw resources in android/app/src/main/res/raw:
/// [sound] for four prayers and [fajrSound] for Fajr (see README). A missing
/// Fajr file falls back to the muezzin's own adhan and then the default, so a
/// muezzin never loses an alert. The user's own recording ([Muezzins.custom])
/// is a URI instead.
class Muezzin {
  const Muezzin({
    required this.id,
    required this.nameEn,
    required this.nameAr,
    required this.sound,
    this.uri,
    this.fajrUri,
  });

  final String id;
  final String nameEn;
  final String nameAr;

  /// The raw resource name, without its extension.
  final String sound;

  /// For the user's own recording: what to play for four prayers, and for
  /// Fajr if they chose a separate one.
  final String? uri;
  final String? fajrUri;

  bool get isCustom => uri != null;

  String get fajrSound => '${sound}_fajr';

  /// Android fixes a channel's sound when it is created, so each recording
  /// has a channel of its own; a new recording of the user's gets a new one.
  String get channel => isCustom ? '$customChannelPrefix${_fnv(uri!)}' : 'prayer_$sound';
  String get fajrChannel => isCustom
      ? (fajrUri == null ? channel : '$customChannelPrefix${_fnv(fajrUri!)}')
      : 'prayer_${sound}_fajr';

  /// What the user's own recordings' channels start with, so old ones can be
  /// cleared away.
  static const String customChannelPrefix = 'prayer_custom_';

  /// FNV-1a, so a URI always maps to the same channel from one run to the next.
  static String _fnv(String s) {
    var h = 0x811c9dc5;
    for (final c in s.codeUnits) {
      h = ((h ^ c) * 0x01000193) & 0xffffffff;
    }
    return h.toRadixString(16).padLeft(8, '0');
  }
}

abstract final class Muezzins {
  static const Muezzin standard = Muezzin(
    id: 'default',
    nameEn: 'Default adhan',
    nameAr: 'الأذان الافتراضي',
    sound: 'adhan',
  );

  /// The muezzins Settings offers: only those whose recording ships with the
  /// app, so picking one always plays what its name says.
  static const List<Muezzin> all = [
    standard,
    Muezzin(id: 'short', nameEn: 'Short adhan', nameAr: 'أذان قصير', sound: 'adhan_short'),
  ];

  /// Muezzins with no recording bundled yet. Once both files are in res/raw
  /// (see README), move the entry into [all]. A user who chose one of them in
  /// an earlier version now gets the default adhan, which is what they were
  /// already hearing.
  static const List<Muezzin> unbundled = [
    Muezzin(id: 'makkah', nameEn: 'Makkah', nameAr: 'أذان مكة', sound: 'adhan_makkah'),
    Muezzin(id: 'madinah', nameEn: 'Madinah', nameAr: 'أذان المدينة', sound: 'adhan_madinah'),
    Muezzin(id: 'aqsa', nameEn: 'Al-Aqsa', nameAr: 'أذان الأقصى', sound: 'adhan_aqsa'),
    Muezzin(id: 'egypt', nameEn: 'Egypt', nameAr: 'أذان مصر', sound: 'adhan_egypt'),
  ];

  static Muezzin byId(String id) => all.firstWhere((m) => m.id == id, orElse: () => standard);

  /// The id Settings stores when the user's own recording is chosen.
  static const String customId = 'custom';

  /// The user's own recording, with [fajr] for Fajr if they chose one.
  static Muezzin custom(CustomSound adhan, [CustomSound? fajr]) => Muezzin(
    id: customId,
    nameEn: adhan.title,
    nameAr: adhan.title,
    sound: '',
    uri: adhan.uri,
    fajrUri: fajr?.uri,
  );
}
