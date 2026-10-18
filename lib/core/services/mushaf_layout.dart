import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'quran_meta.dart';

/// One word of the Quran: verse plus its 1-based place in [MushafWords.split].
@immutable
class WordRef implements Comparable<WordRef> {
  const WordRef(this.sura, this.ayah, this.word);

  final int sura;
  final int ayah;
  final int word;

  VerseRef get verse => VerseRef(sura, ayah);

  @override
  int compareTo(WordRef other) {
    if (sura != other.sura) return sura.compareTo(other.sura);
    if (ayah != other.ayah) return ayah.compareTo(other.ayah);
    return word.compareTo(other.word);
  }

  @override
  bool operator ==(Object other) =>
      other is WordRef && other.sura == sura && other.ayah == ayah && other.word == word;

  @override
  int get hashCode => Object.hash(sura, ayah, word);

  @override
  String toString() => '$sura:$ayah:$word';
}

enum MushafLineKind { text, suraTitle, basmala }

/// One of the fifteen lines of a page.
@immutable
class MushafLine {
  MushafLine.text(WordRef this.first, WordRef this.last)
    : kind = MushafLineKind.text,
      sura = first.sura;

  const MushafLine.title(this.sura) : kind = MushafLineKind.suraTitle, first = null, last = null;

  const MushafLine.basmala(this.sura) : kind = MushafLineKind.basmala, first = null, last = null;

  final MushafLineKind kind;
  final int sura;

  /// First and last word on a text line, inclusive. Null on the others.
  final WordRef? first;
  final WordRef? last;

  bool holds(WordRef w) =>
      kind == MushafLineKind.text && w.compareTo(first!) >= 0 && w.compareTo(last!) <= 0;
}

/// Splits verses into the words a mushaf line breaks between.
///
/// Tanzil writes pause marks (ۖ ۚ ۛ), the hizb mark ۞ and the sajda mark ۩ as
/// tokens of their own; each joins the word it belongs to: the one before it
/// or, at the start of a verse, the one after. A few words the text joins but
/// the mushaf writes as two (بَعْدَمَا) are split as [splits] records.
/// tool/build_content_assets.py applies the same rules when it builds the
/// layout, and a test holds the two together.
abstract final class MushafWords {
  // Unicode category Lo, the build script's unicodedata test.
  static final RegExp _letter = RegExp(r'\p{Lo}', unicode: true);

  static List<String> split(String verse, [List<(int word, int cut)> splits = const []]) {
    final out = <String>[];
    for (final token in verse.split(' ')) {
      if (token.isEmpty) continue;
      final isWord = _letter.hasMatch(token);
      if (out.isNotEmpty && (!isWord || !_letter.hasMatch(out.last))) {
        out[out.length - 1] = '${out.last} $token';
      } else {
        out.add(token);
      }
    }
    // Later words first, so earlier indices stay valid.
    for (final (word, cut) in splits.reversed) {
      final w = out[word - 1];
      out.replaceRange(word - 1, word, [w.substring(0, cut), w.substring(cut)]);
    }
    return out;
  }
}

/// The page and line of every word in the 604-page Madinah mushaf, from
/// assets/quran/mushaf.json (built by tool/build_content_assets.py).
class MushafLayout {
  MushafLayout._(this.pages, this._splits);

  static const int pageCount = 604;

  /// 1-based page number to its lines: index 0 is page 1.
  final List<List<MushafLine>> pages;

  final Map<VerseRef, List<(int, int)>> _splits;

  static MushafLayout? _instance;

  static MushafLayout? get instance => _instance;

  static Future<MushafLayout> load() async {
    final existing = _instance;
    if (existing != null) return existing;
    final raw = await rootBundle.loadString('assets/quran/mushaf.json');
    return _instance = parse(raw);
  }

  @visibleForTesting
  static MushafLayout parse(String raw) {
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final splits = <VerseRef, List<(int, int)>>{};
    for (final s in json['splits'] as List) {
      final v = List<int>.from(s as List);
      (splits[VerseRef(v[0], v[1])] ??= []).add((v[2], v[3]));
    }
    final pages = [
      for (final page in json['pages'] as List)
        [
          for (final line in page as List)
            switch (List<int>.from(line as List)) {
              [0, final s, final a, final w, final s2, final a2, final w2] =>
                MushafLine.text(WordRef(s, a, w), WordRef(s2, a2, w2)),
              [1, final s] => MushafLine.title(s),
              [2, final s] => MushafLine.basmala(s),
              final other => throw FormatException('Bad mushaf line $other'),
            },
        ],
    ];
    return MushafLayout._(pages, splits);
  }

  List<MushafLine> page(int number) => pages[number - 1];

  /// The words of [verse], split as the mushaf splits them.
  List<String> wordsOf(VerseRef verse, String text) =>
      MushafWords.split(text, _splits[verse] ?? const []);

  /// The page a word is on: the last page whose first word is at or before it.
  int pageOfWord(WordRef w) {
    var lo = 1, hi = pageCount;
    while (lo < hi) {
      final mid = (lo + hi + 1) ~/ 2;
      final first = firstWord(mid);
      if (first.compareTo(w) <= 0) {
        lo = mid;
      } else {
        hi = mid - 1;
      }
    }
    return lo;
  }

  /// The page [verse] starts on.
  int pageOf(VerseRef verse) => pageOfWord(WordRef(verse.sura, verse.ayah, 1));

  WordRef firstWord(int page) =>
      this.page(page).firstWhere((l) => l.kind == MushafLineKind.text).first!;

  WordRef lastWord(int page) =>
      this.page(page).lastWhere((l) => l.kind == MushafLineKind.text).last!;

  /// The suras with words on [page], in order.
  List<int> surasOn(int page) => {
    for (final l in this.page(page)) l.sura,
  }.toList();
}
