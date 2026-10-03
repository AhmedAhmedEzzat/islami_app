import '../services/quran_meta.dart';

/// A supplication in the Quran: one verse, or a run of consecutive verses
/// when the dua continues past the first (e.g. 10:85–86).
class QuranDua {
  const QuranDua(this.sura, this.from, [int? to]) : to = to ?? from;

  final int sura;
  final int from;
  final int to;

  VerseRef get start => VerseRef(sura, from);

  List<VerseRef> get verses => [for (var a = from; a <= to; a++) VerseRef(sura, a)];

  String get label => from == to ? '$sura:$from' : '$sura:$from–$to';
}

/// Supplications found in the Quran, by verse reference only — the text is
/// read from the bundled Tanzil corpus, so nothing here is typed by hand.
/// test/quran_duas_test.dart checks every reference really is a supplication.
abstract final class QuranDuas {
  /// The duas opening "رَبَّنَا", traditionally gathered as the Rabbana duas.
  static const List<QuranDua> rabbana = [
    QuranDua(2, 127), QuranDua(2, 128), QuranDua(2, 201), QuranDua(2, 250),
    QuranDua(2, 286), QuranDua(3, 8), QuranDua(3, 9), QuranDua(3, 16),
    QuranDua(3, 53), QuranDua(3, 147), QuranDua(3, 191), QuranDua(3, 192),
    QuranDua(3, 193), QuranDua(3, 194), QuranDua(5, 83), QuranDua(5, 114),
    QuranDua(7, 23), QuranDua(7, 47), QuranDua(7, 89), QuranDua(7, 126),
    // "…ربنا لا تجعلنا فتنة…" continues into "ونجنا برحمتك…".
    QuranDua(10, 85, 86),
    QuranDua(14, 38), QuranDua(14, 40, 41), QuranDua(18, 10), QuranDua(20, 45),
    QuranDua(23, 109), QuranDua(25, 65, 66), QuranDua(25, 74), QuranDua(40, 7, 8),
    QuranDua(59, 10), QuranDua(60, 4, 5), QuranDua(66, 8),
  ];

  /// Supplications of the prophets ("رَبِّ ...").
  static const List<QuranDua> prophets = [
    QuranDua(3, 38), // Zakariyya
    QuranDua(7, 151), // Musa
    QuranDua(12, 101), // Yusuf
    QuranDua(17, 24), // for parents
    QuranDua(17, 80),
    QuranDua(20, 25, 28), // Musa: رب اشرح لي صدري… يفقهوا قولي
    QuranDua(20, 114),
    QuranDua(21, 83), // Ayyub
    QuranDua(21, 87), // Yunus — the one that is not a "Rabbi" opening
    QuranDua(21, 89), // Zakariyya
    QuranDua(23, 29), // Nuh
    QuranDua(23, 97, 98),
    QuranDua(23, 118),
    QuranDua(26, 83, 85), // Ibrahim
    QuranDua(27, 19), // Sulayman
    QuranDua(28, 16), // Musa
    QuranDua(28, 24), // Musa
    QuranDua(29, 30), // Lut
    QuranDua(37, 100), // Ibrahim
    QuranDua(46, 15),
    QuranDua(71, 28), // Nuh
  ];
}
