import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// A point in the Quran: sura and verse, both 1-based.
@immutable
class VerseRef {
  const VerseRef(this.sura, this.ayah);

  final int sura;
  final int ayah;

  /// "2:255".
  String get key => '$sura:$ayah';

  static VerseRef? parse(String key) {
    final parts = key.split(':');
    if (parts.length != 2) return null;
    final s = int.tryParse(parts[0]);
    final a = int.tryParse(parts[1]);
    if (s == null || a == null) return null;
    return VerseRef(s, a);
  }

  @override
  bool operator ==(Object other) =>
      other is VerseRef && other.sura == sura && other.ayah == ayah;

  @override
  int get hashCode => Object.hash(sura, ayah);

  @override
  String toString() => key;
}

/// Facts about one sura that the bundled metadata provides.
@immutable
class SuraInfo {
  const SuraInfo({
    required this.number,
    required this.nameAr,
    required this.nameEn,
    required this.meaning,
    required this.isMeccan,
    required this.ayahs,
    required this.startPage,
  });

  final int number;
  final String nameAr;
  final String nameEn;

  /// English meaning of the name, e.g. "The Cow".
  final String meaning;
  final bool isMeccan;
  final int ayahs;

  /// The page of the standard Madinah mushaf the sura starts on.
  final int startPage;
}

/// Juz, hizb, mushaf page and sajda data for every verse, from the same
/// Tanzil source as the text (see tool/build_content_assets.py).
class QuranMeta {
  QuranMeta._(this.suras, this._verses, this.juzStarts, this.hizbStarts);

  final List<SuraInfo> suras;
  final Map<int, _SuraVerses> _verses;

  /// Where each of the 30 juz begins.
  final List<VerseRef> juzStarts;

  /// Where each of the 240 hizb quarters begins.
  final List<VerseRef> hizbStarts;

  static QuranMeta? _instance;

  static Future<QuranMeta> load() async {
    final existing = _instance;
    if (existing != null) return existing;
    final raw = await rootBundle.loadString('assets/quran/meta.json');
    return _instance = parse(raw);
  }

  /// Synchronous access once [load] has completed; null before that.
  static QuranMeta? get instance => _instance;

  @visibleForTesting
  static QuranMeta parse(String raw) {
    final json = jsonDecode(raw) as Map<String, dynamic>;

    final suras = [
      for (final s in json['suras'] as List)
        SuraInfo(
          number: s['n'] as int,
          nameAr: s['ar'] as String,
          nameEn: s['en'] as String,
          meaning: s['meaning'] as String,
          isMeccan: s['type'] == 'Meccan',
          ayahs: s['ayahs'] as int,
          startPage: s['page'] as int,
        ),
    ];

    final verses = <int, _SuraVerses>{};
    (json['verses'] as Map<String, dynamic>).forEach((k, v) {
      verses[int.parse(k)] = _SuraVerses(
        juz: List<int>.from(v['juz'] as List),
        page: List<int>.from(v['page'] as List),
        hizbQuarter: List<int>.from(v['hizb'] as List),
        sajda: Set<int>.from(v['sajda'] as List),
      );
    });

    List<VerseRef> refs(String key) => [
      for (final r in json[key] as List)
        VerseRef(r['sura'] as int, r['ayah'] as int),
    ];

    return QuranMeta._(suras, verses, refs('juz'), refs('hizb'));
  }

  SuraInfo sura(int number) => suras[number - 1];

  int juzOf(VerseRef v) => _verses[v.sura]!.juz[v.ayah - 1];
  int pageOf(VerseRef v) => _verses[v.sura]!.page[v.ayah - 1];

  /// 1..240.
  int hizbQuarterOf(VerseRef v) => _verses[v.sura]!.hizbQuarter[v.ayah - 1];

  /// 1..60. Each hizb is half a juz.
  int hizbOf(VerseRef v) => (hizbQuarterOf(v) - 1) ~/ 4 + 1;

  bool isSajda(VerseRef v) => _verses[v.sura]!.sajda.contains(v.ayah);

  /// The verses that carry a prostration of recitation.
  Iterable<VerseRef> get sajdaVerses sync* {
    for (final entry in _verses.entries) {
      for (final ayah in entry.value.sajda) {
        yield VerseRef(entry.key, ayah);
      }
    }
  }
}

class _SuraVerses {
  const _SuraVerses({
    required this.juz,
    required this.page,
    required this.hizbQuarter,
    required this.sajda,
  });

  final List<int> juz;
  final List<int> page;
  final List<int> hizbQuarter;
  final Set<int> sajda;
}
