/// An adhan recording the prayer notification can play.
///
/// Recordings are not bundled. Each muezzin is two files the developer drops
/// into android/app/src/main/res/raw: [sound] for four prayers and
/// [fajrSound] for Fajr (see README). A missing file falls back to the next
/// one in line, so choosing a muezzin never loses an alert.
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

  static const List<Muezzin> all = [
    standard,
    Muezzin(id: 'makkah', nameEn: 'Makkah', nameAr: 'أذان مكة', sound: 'adhan_makkah'),
    Muezzin(id: 'madinah', nameEn: 'Madinah', nameAr: 'أذان المدينة', sound: 'adhan_madinah'),
    Muezzin(id: 'aqsa', nameEn: 'Al-Aqsa', nameAr: 'أذان الأقصى', sound: 'adhan_aqsa'),
    Muezzin(id: 'egypt', nameEn: 'Egypt', nameAr: 'أذان مصر', sound: 'adhan_egypt'),
  ];

  static Muezzin byId(String id) => all.firstWhere((m) => m.id == id, orElse: () => standard);
}
