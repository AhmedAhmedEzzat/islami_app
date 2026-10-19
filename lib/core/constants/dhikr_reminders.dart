/// The short adhkar the dhikr reminders take turns with, each with its
/// meaning for the English notification. All are from authentic hadith.
abstract final class DhikrReminders {
  static const List<(String, String)> all = [
    ('سُبْحَانَ اللَّهِ وَبِحَمْدِهِ، سُبْحَانَ اللَّهِ الْعَظِيمِ', 'Glory be to Allah and praise Him; glory be to Allah the Almighty.'),
    ('أَسْتَغْفِرُ اللَّهَ وَأَتُوبُ إِلَيْهِ', 'I seek Allah\'s forgiveness and turn to Him in repentance.'),
    ('اللَّهُمَّ صَلِّ وَسَلِّمْ عَلَى نَبِيِّنَا مُحَمَّدٍ', 'O Allah, send prayers and peace upon our Prophet Muhammad.'),
    ('لَا حَوْلَ وَلَا قُوَّةَ إِلَّا بِاللَّهِ', 'There is no might nor power except with Allah.'),
    ('سُبْحَانَ اللَّهِ، وَالْحَمْدُ لِلَّهِ، وَلَا إِلَهَ إِلَّا اللَّهُ، وَاللَّهُ أَكْبَرُ', 'Glory be to Allah, praise be to Allah, there is no god but Allah, and Allah is the Greatest.'),
    ('لَا إِلَهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ', 'There is no god but Allah alone, with no partner; His is the dominion and His the praise, and He has power over all things.'),
    (
      'حَسْبِيَ اللَّهُ لَا إِلَهَ إِلَّا هُوَ، عَلَيْهِ تَوَكَّلْتُ، وَهُوَ رَبُّ الْعَرْشِ الْعَظِيمِ',
      'Allah is enough for me; there is no god but Him. In Him I put my trust, and He is the Lord of the Mighty Throne.',
    ),
  ];

  /// The choices of how often, in hours; 0 is off.
  static const List<int> intervals = [0, 2, 3, 4];
}
