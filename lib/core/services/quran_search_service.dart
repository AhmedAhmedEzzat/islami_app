import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../utils/arabic_text.dart';
import 'quran_meta.dart';
import 'quran_service.dart';

@immutable
class QuranSearchHit {
  const QuranSearchHit(this.ref, this.arabic, this.english);

  final VerseRef ref;
  final String arabic;
  final String english;
}

/// Full-text search over the Arabic text and the English translation.
///
/// Arabic is matched against Tanzil's plain-spelling edition, not the
/// Uthmani text that is displayed: Uthmani writes العالمين as ٱلْعَٰلَمِينَ
/// and الصلاة as ٱلصَّلَوٰة, and no folding rule can bridge both without
/// breaking words like السماوات. The hit then shows the Uthmani verse.
///
/// The whole Quran is 6,236 verses, so a plain in-memory scan is fast enough
/// once the text is normalised — no database needed. Normalising is the only
/// costly step, so it runs once, in a background isolate, on first search.
abstract final class QuranSearchService {
  static List<_Entry>? _index;
  static Future<void>? _building;

  static bool get isReady => _index != null;

  static Future<void> ensureIndex() {
    if (_index != null) return Future.value();
    return _building ??= _build();
  }

  static Future<void> _build() async {
    final plainLines = (await rootBundle.loadString('assets/quran/search.txt'))
        .split('\n')
        .where((l) => l.trim().isNotEmpty)
        .toList();

    final refs = <VerseRef>[];
    final plain = <String>[];
    for (final line in plainLines) {
      final tab = line.indexOf('\t');
      final ref = VerseRef.parse(line.substring(0, tab));
      if (ref == null) continue;
      refs.add(ref);
      plain.add(line.substring(tab + 1));
    }

    final arabic = <String>[];
    final english = <String>[];
    for (var sura = 1; sura <= 114; sura++) {
      arabic.addAll(await QuranService.loadSura('$sura'));
      english.addAll(await QuranService.loadTranslation('$sura'));
    }
    // The two editions must line up verse for verse, or a hit would show the
    // wrong verse. Both come from Tanzil with identical verse division.
    assert(arabic.length == plain.length && english.length == plain.length);

    final normalised = await compute(_normaliseAll, plain);
    _index = [
      for (var i = 0; i < refs.length; i++)
        _Entry(refs[i], arabic[i], english[i], normalised[i], english[i].toLowerCase()),
    ];
  }

  static List<String> _normaliseAll(List<String> verses) =>
      verses.map(ArabicText.normalizeForSearch).toList();

  /// Verses whose Arabic or English contains [query]. Arabic queries are
  /// matched against normalised text, so diacritics are optional.
  static Future<List<QuranSearchHit>> search(String query, {int limit = 200}) async {
    final q = query.trim();
    if (q.length < 2) return const [];
    await ensureIndex();

    final isArabic = RegExp(r'[؀-ۿ]').hasMatch(q);
    final needle = isArabic ? ArabicText.normalizeForSearch(q) : q.toLowerCase();
    if (needle.isEmpty) return const [];

    final hits = <QuranSearchHit>[];
    for (final e in _index!) {
      final haystack = isArabic ? e.normalised : e.englishLower;
      if (haystack.contains(needle)) {
        hits.add(QuranSearchHit(e.ref, e.arabic, e.english));
        if (hits.length >= limit) break;
      }
    }
    return hits;
  }
}

class _Entry {
  const _Entry(this.ref, this.arabic, this.english, this.normalised, this.englishLower);

  final VerseRef ref;
  final String arabic;
  final String english;
  final String normalised;
  final String englishLower;
}
