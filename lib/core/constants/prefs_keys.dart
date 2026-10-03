/// Every SharedPreferences key in one place.
///
/// These used to be string literals scattered through the views, which made it
/// impossible to see what the app persists.
abstract final class PrefsKeys {
  static const String firstTime = 'firstTime';
  static const String recentSuraIndex = 'recent-sura-index';
  static const String themeMode = 'settings.themeMode';
  static const String quranFontScale = 'settings.quranFontScale';
  static const String reciterId = 'settings.reciterId';
  static const String calculationMethod = 'settings.calculationMethod';
  static const String locale = 'settings.locale';
  static const String prayerNotifications = 'settings.prayerNotifications';
  static const String lastLatitude = 'location.latitude';
  static const String lastLongitude = 'location.longitude';
  static const String lastPlaceName = 'location.placeName';
  static const String manualLatitude = 'location.manual.latitude';
  static const String manualLongitude = 'location.manual.longitude';
  static const String manualPlaceName = 'location.manual.name';
  static const String madhab = 'settings.madhab';
  static const String highLatitude = 'settings.highLatitude';
  static const String prayerAdjustments = 'settings.prayerAdjustments';
  static const String reminderMinutes = 'settings.reminderMinutes';
  static const String notifiedPrayers = 'settings.notifiedPrayers';
  static const String fridayKahf = 'settings.fridayKahf';
  static const String hijriOffset = 'settings.hijriOffset';
  static const String hadethFavourites = 'hadeth.favourites';
  static const String zakatInputs = 'zakat.inputs';

  /// Prayer tracker: a bitmask of the five prayers logged for one day.
  static String prayerLog(DateTime day) =>
      'tracker.${day.year}-${day.month.toString().padLeft(2, '0')}-'
      '${day.day.toString().padLeft(2, '0')}';
  static const String tasbehCount = 'tasbeh.count';
  static const String tasbehZikrIndex = 'tasbeh.zikrIndex';
  static const String tasbehRounds = 'tasbeh.rounds';
  static const String bookmarks = 'quran.bookmarks';
  static const String lastRead = 'quran.lastRead';

  /// Per-sura reading position, stored as the index of the first verse on the
  /// page the reader left off. A verse rather than a page number, because the
  /// number of pages changes with screen size and text size.
  static String suraPosition(String suraId) => 'quran.position.$suraId';

  /// The exact word the reader's page starts on. Word indices depend only on
  /// the text, not on the screen, so this survives a change of text size.
  static String suraWord(String suraId) => 'quran.word.$suraId';
}
