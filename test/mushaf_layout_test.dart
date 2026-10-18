import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sakina/core/services/mushaf_layout.dart';
import 'package:sakina/core/services/quran_meta.dart';

void main() {
  final layout = MushafLayout.parse(File('assets/quran/mushaf.json').readAsStringSync());
  final meta = QuranMeta.parse(File('assets/quran/meta.json').readAsStringSync());

  // Every verse, split the way the app splits it.
  final words = <VerseRef, List<String>>{};
  for (var s = 1; s <= 114; s++) {
    final lines = File('assets/quran/ar/$s.txt')
        .readAsLinesSync()
        .where((l) => l.trim().isNotEmpty)
        .toList();
    for (var a = 1; a <= lines.length; a++) {
      words[VerseRef(s, a)] = layout.wordsOf(VerseRef(s, a), lines[a - 1].trim());
    }
  }

  WordRef? after(WordRef w) {
    if (w.word < words[w.verse]!.length) return WordRef(w.sura, w.ayah, w.word + 1);
    if (words.containsKey(VerseRef(w.sura, w.ayah + 1))) return WordRef(w.sura, w.ayah + 1, 1);
    if (w.sura < 114) return WordRef(w.sura + 1, 1, 1);
    return null;
  }

  test('604 pages of 15 lines, except the two opening pages of 8', () {
    expect(layout.pages, hasLength(MushafLayout.pageCount));
    for (var p = 1; p <= MushafLayout.pageCount; p++) {
      expect(layout.page(p), hasLength(p <= 2 ? 8 : 15), reason: 'page $p');
    }
  });

  test('the lines hold every word once, in order, as the app splits them', () {
    // Fails if the app's MushafWords.split and the build script's
    // mushaf_words ever disagree about where words begin and end.
    WordRef? expected = const WordRef(1, 1, 1);
    for (var p = 1; p <= MushafLayout.pageCount; p++) {
      for (final line in layout.page(p).where((l) => l.kind == MushafLineKind.text)) {
        expect(line.first, expected, reason: 'page $p');
        expect(line.last!.word, lessThanOrEqualTo(words[line.last!.verse]!.length),
            reason: 'page $p ends past ${line.last!.verse}');
        expected = after(line.last!);
      }
    }
    expect(expected, isNull, reason: 'the last line must end the Quran');
  });

  test('pause marks join their word rather than standing alone', () {
    expect(MushafWords.split('لَا رَيْبَ ۛ فِيهِ ۛ هُدًۭى'), ['لَا', 'رَيْبَ ۛ', 'فِيهِ ۛ', 'هُدًۭى']);
    expect(MushafWords.split('۞ إِنَّ ٱللَّهَ'), ['۞ إِنَّ', 'ٱللَّهَ']);
  });

  test('بَعْدَمَا is two words, as in the mushaf', () {
    final w = words[const VerseRef(13, 37)]!;
    expect(w[7], 'بَعْدَ');
    expect(w[8], 'مَا');
  });

  test('every verse starts on the page the Tanzil metadata gives', () {
    for (final v in words.keys) {
      expect(layout.pageOf(v), meta.pageOf(v), reason: '$v');
    }
  });

  test('each sura has one title, and a basmala except Al-Fatiha and At-Tawbah', () {
    final titles = <int>[], basmalas = <int>[];
    for (final page in layout.pages) {
      for (final l in page) {
        if (l.kind == MushafLineKind.suraTitle) titles.add(l.sura);
        if (l.kind == MushafLineKind.basmala) basmalas.add(l.sura);
      }
    }
    expect(titles, List.generate(114, (i) => i + 1));
    expect(basmalas, [for (var s = 2; s <= 114; s++) if (s != 9) s]);
  });

  test('page 531 matches the printed mushaf', () {
    final page = layout.page(531);
    expect(page.first.first, const WordRef(54, 50, 1));
    expect(page[4].kind, MushafLineKind.suraTitle);
    expect(page[5].kind, MushafLineKind.basmala);
    expect(page.last.last, const WordRef(55, 18, 4));
  });
}
