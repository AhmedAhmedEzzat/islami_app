import 'package:flutter/widgets.dart';

/// A sura flattened into words, which is the unit pages break on.
///
/// Printed mushafs break mid-verse to fill each page, so pagination works on
/// words rather than whole verses.
@immutable
class MushafText {
  MushafText(List<String> verses) {
    final words = <String>[];
    final verseOfWord = <int>[];
    final verseStart = <int>[];
    final verseEnd = <int>[];
    for (var v = 0; v < verses.length; v++) {
      verseStart.add(words.length);
      for (final word in verses[v].split(' ')) {
        if (word.trim().isEmpty) continue;
        words.add(word);
        verseOfWord.add(v);
      }
      // A verse with no words still owns an (empty) span so its rosette shows.
      verseEnd.add(words.length);
    }
    this.words = List.unmodifiable(words);
    this.verseOfWord = List.unmodifiable(verseOfWord);
    this.verseStart = List.unmodifiable(verseStart);
    this.verseEnd = List.unmodifiable(verseEnd);
  }

  late final List<String> words;

  /// For each word, the index of the verse it belongs to.
  late final List<int> verseOfWord;

  /// For each verse, the index of its first word and one past its last.
  late final List<int> verseStart;
  late final List<int> verseEnd;

  int get length => words.length;
  int get verseCount => verseStart.length;

  /// Number of verses that finish inside words [start, end).
  int versesEndingIn(int start, int end) {
    var count = 0;
    for (final e in verseEnd) {
      if (e > start && e <= end) count++;
    }
    return count;
  }
}

/// A run of words shown on one mushaf page, as half-open [start, end).
@immutable
class MushafPageRange {
  const MushafPageRange(this.start, this.end);

  final int start;
  final int end;

  bool contains(int wordIndex) => wordIndex >= start && wordIndex < end;

  @override
  bool operator ==(Object other) =>
      other is MushafPageRange && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => 'MushafPageRange($start, $end)';
}

/// Splits a sura into pages that fill the screen.
///
/// There is no page-mapping data bundled with the app, so pages are measured
/// rather than looked up. Each page takes as many whole verses as fit, then
/// continues into the next verse word by word until it is full. Measuring is
/// done by binary search, so a long sura costs a handful of layouts per page
/// rather than one per word.
abstract final class MushafPaginator {
  static List<MushafPageRange> paginate({
    required MushafText text,
    required InlineSpan Function(int start, int end) buildSpan,
    required Size markerSize,
    required double width,
    required double pageHeight,
    required double firstPageHeight,
    // Must match the scaler the page is rendered with. The phone's font-size
    // setting enlarges rendered Text, and a measurement that ignores it
    // overfills every page.
    TextScaler textScaler = TextScaler.noScaling,
  }) {
    final n = text.length;
    if (n == 0 || width <= 0) return const [];

    bool fits(int start, int end, double available) =>
        _heightOf(
          buildSpan(start, end),
          text.versesEndingIn(start, end),
          markerSize,
          width,
          textScaler,
        ) <=
        available;

    // Largest e in [lo, hi] with fits(start, e), given lo already fits.
    int maxFit(int start, int lo, int hi, double available) {
      while (lo < hi) {
        final mid = (lo + hi + 1) ~/ 2;
        if (fits(start, mid, available)) {
          lo = mid;
        } else {
          hi = mid - 1;
        }
      }
      return lo;
    }

    int nextVerseEnd(int after) {
      for (final e in text.verseEnd) {
        if (e > after) return e;
      }
      return n;
    }

    final pages = <MushafPageRange>[];
    var start = 0;

    while (start < n) {
      final available = pages.isEmpty ? firstPageHeight : pageHeight;
      var end = start;

      // Take whole verses while they fit — cheap, one layout per verse.
      while (end < n) {
        final candidate = nextVerseEnd(end);
        if (!fits(start, candidate, available)) break;
        end = candidate;
      }

      // Then fill the rest of the page from the next verse, word by word.
      if (end < n) {
        end = maxFit(start, end, nextVerseEnd(end), available);
      }

      // Always make progress, even if a single word somehow overflows.
      if (end <= start) end = start + 1;

      pages.add(MushafPageRange(start, end));
      start = end;
    }

    return pages;
  }

  /// Index of the page that shows [wordIndex], or 0 if none does.
  static int pageOf(List<MushafPageRange> pages, int wordIndex) {
    for (var i = 0; i < pages.length; i++) {
      if (pages[i].contains(wordIndex)) return i;
    }
    return 0;
  }

  /// Height of a single line of [text] in [style], as it will actually render.
  static double lineHeight(
    String text,
    TextStyle? style,
    double width,
    TextScaler textScaler, {
    TextDirection direction = TextDirection.ltr,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: direction,
      textScaler: textScaler,
    )..layout(maxWidth: width);
    final height = painter.height;
    painter.dispose();
    return height;
  }

  static double _heightOf(
    InlineSpan span,
    int markers,
    Size markerSize,
    double width,
    TextScaler textScaler,
  ) {
    final painter = TextPainter(
      text: span,
      textDirection: TextDirection.rtl,
      textAlign: TextAlign.justify,
      textScaler: textScaler,
    );
    // The verse rosettes are WidgetSpans; TextPainter needs their size up
    // front or it refuses to lay the paragraph out.
    painter.setPlaceholderDimensions(
      List.filled(
        markers,
        PlaceholderDimensions(
          size: markerSize,
          alignment: PlaceholderAlignment.middle,
        ),
      ),
    );
    painter.layout(maxWidth: width);
    final height = painter.height;
    painter.dispose();
    return height;
  }
}
