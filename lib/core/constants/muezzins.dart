/// An adhan recording the prayer notification can play.
///
/// Each muezzin is two raw resources in android/app/src/main/res/raw: [sound]
/// for four prayers and [fajrSound] for Fajr (see README). A missing Fajr
/// file falls back to the muezzin's own adhan and then the default, so a
/// muezzin never loses an alert.
class Muezzin {
  const Muezzin({required this.id, required this.nameEn, required this.nameAr, required this.sound});

  final String id;
  final String nameEn;
  final String nameAr;

  /// The raw resource name, without its extension.
  final String sound;

  String get fajrSound => '${sound}_fajr';

  /// Android fixes a channel's sound when it is created, so each recording
  /// has a channel of its own.
  String get channel => 'prayer_$sound';
  String get fajrChannel => 'prayer_${sound}_fajr';
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
}
