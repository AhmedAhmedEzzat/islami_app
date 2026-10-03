import 'quran_duas.dart';

/// Short, well-known verses of hope, remembrance and reliance on Allah, shown
/// one a day on Home together with the Quranic duas.
///
/// Only references live here; the text is read from the bundled corpus.
/// test/daily_verses_test.dart checks each one says what it is meant to.
abstract final class DailyVerses {
  static const List<QuranDua> curated = [
    QuranDua(2, 152), // Remember Me; I will remember you
    QuranDua(2, 153), // Seek help through patience and prayer
    QuranDua(2, 186), // I am near
    QuranDua(2, 255), // Ayat al-Kursi
    QuranDua(3, 139), // Do not weaken and do not grieve
    QuranDua(3, 173), // Allah is sufficient for us
    QuranDua(9, 40), // Do not grieve; Allah is with us
    QuranDua(12, 87), // Do not despair of the mercy of Allah
    QuranDua(13, 28), // In the remembrance of Allah hearts find rest
    QuranDua(14, 7), // If you are grateful, I will increase you
    QuranDua(29, 69), // We will guide them to Our ways
    QuranDua(33, 41), // Remember Allah often
    QuranDua(39, 53), // Do not despair of the mercy of Allah
    QuranDua(40, 60), // Call upon Me; I will respond
    QuranDua(48, 4), // He sent down tranquillity (as-sakina)
    QuranDua(50, 16), // Nearer than the jugular vein
    QuranDua(57, 4), // He is with you wherever you are
    QuranDua(65, 3), // Whoever relies on Allah, He is sufficient for him
    QuranDua(93, 3), // Your Lord has not forsaken you
    QuranDua(94, 5, 6), // With hardship comes ease
  ];

  /// Everything Home rotates through.
  static const List<QuranDua> pool = [
    ...curated,
    ...QuranDuas.rabbana,
    ...QuranDuas.prophets,
  ];

  /// The same verse all day, a different one the next.
  static QuranDua forDay(DateTime day) => pool[dayNumber(day) % pool.length];
}

/// Days since the epoch, counted on the local calendar date.
int dayNumber(DateTime day) =>
    DateTime.utc(day.year, day.month, day.day).millisecondsSinceEpoch ~/
    Duration.millisecondsPerDay;
