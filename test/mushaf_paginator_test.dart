import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakina/modules/layout/quran/widgets/mushaf_paginator.dart';

const _style = TextStyle(fontSize: 20, height: 2);
const _marker = Size.square(26);

/// Mirrors the real page builder closely enough to exercise the paginator:
/// words of one verse in a run, a marker placeholder where a verse finishes.
InlineSpan _span(MushafText text, int start, int end) {
  final children = <InlineSpan>[];
  var i = start;
  while (i < end) {
    final v = text.verseOfWord[i];
    final segEnd = end < text.verseEnd[v] ? end : text.verseEnd[v];
    children.add(TextSpan(text: '${text.words.sublist(i, segEnd).join(' ')} '));
    if (segEnd == text.verseEnd[v]) {
      children.add(const WidgetSpan(child: SizedBox(width: 26, height: 26)));
    }
    i = segEnd;
  }
  return TextSpan(style: _style, children: children);
}

double _height(MushafText text, int start, int end, double width) {
  final painter = TextPainter(
    text: _span(text, start, end),
    textDirection: TextDirection.rtl,
    textAlign: TextAlign.justify,
  );
  painter.setPlaceholderDimensions(
    List.filled(
      text.versesEndingIn(start, end),
      const PlaceholderDimensions(
        size: _marker,
        alignment: PlaceholderAlignment.middle,
      ),
    ),
  );
  painter.layout(maxWidth: width);
  final h = painter.height;
  painter.dispose();
  return h;
}

List<MushafPageRange> _paginate(
  MushafText text, {
  double width = 300,
  double pageHeight = 400,
  double? firstPageHeight,
  double scale = 1,
}) {
  return MushafPaginator.paginate(
    text: text,
    buildSpan: (s, e) => _span(text, s, e),
    markerSize: _marker,
    width: width,
    pageHeight: pageHeight,
    firstPageHeight: firstPageHeight ?? pageHeight,
    textScaler: TextScaler.linear(scale),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Verses of varied length, some long enough to straddle a page break.
  final text = MushafText(
    List.generate(60, (i) => List.filled(4 + (i * 7) % 23, 'word').join(' ')),
  );

  group('MushafText', () {
    test('flattens verses into words and remembers their boundaries', () {
      final t = MushafText(['a b', 'c', 'd e f']);
      expect(t.words, ['a', 'b', 'c', 'd', 'e', 'f']);
      expect(t.verseOfWord, [0, 0, 1, 2, 2, 2]);
      expect(t.verseStart, [0, 2, 3]);
      expect(t.verseEnd, [2, 3, 6]);
    });

    test('counts only verses that finish inside a range', () {
      final t = MushafText(['a b', 'c', 'd e f']);
      expect(t.versesEndingIn(0, 6), 3);
      expect(t.versesEndingIn(1, 4), 2); // verses 0 and 1 end at 2 and 3
      expect(t.versesEndingIn(3, 5), 0); // stops mid-verse
    });

    test('ignores doubled spaces rather than inventing empty words', () {
      expect(MushafText(['a  b']).words, ['a', 'b']);
    });
  });

  group('MushafPaginator', () {
    test('every word lands on exactly one page, in order', () {
      final pages = _paginate(text);
      expect(pages.first.start, 0);
      expect(pages.last.end, text.length);
      for (var i = 1; i < pages.length; i++) {
        expect(pages[i].start, pages[i - 1].end, reason: 'gap/overlap at $i');
      }
      for (final page in pages) {
        expect(page.end, greaterThan(page.start));
      }
    });

    test('no page overflows its height', () {
      for (final page in _paginate(text)) {
        expect(
          _height(text, page.start, page.end, 300),
          lessThanOrEqualTo(400),
          reason: '$page overflows',
        );
      }
    });

    test('every page but the last is full: one more word would overflow', () {
      // This is what makes it look like a printed mushaf rather than pages
      // that end early whenever the next verse is long.
      final pages = _paginate(text);
      for (final page in pages.take(pages.length - 1)) {
        expect(
          _height(text, page.start, page.end + 1, 300),
          greaterThan(400),
          reason: '$page could have held another word',
        );
      }
    });

    test('pages break mid-verse when that fills the page', () {
      final pages = _paginate(text);
      final midVerseBreaks = pages
          .take(pages.length - 1)
          .where((p) => !text.verseEnd.contains(p.end));
      expect(midVerseBreaks, isNotEmpty);
    });

    test('a short sura fits on one page', () {
      expect(_paginate(MushafText(['one', 'two', 'three'])).length, 1);
    });

    test('a smaller first page (for the sura header) holds fewer words', () {
      final normal = _paginate(text);
      final withHeader = _paginate(text, firstPageHeight: 150);
      expect(withHeader.first.end, lessThan(normal.first.end));
    });

    test('the phone font-size setting is honoured', () {
      // Regression: measuring at 1.0x while the phone rendered at 1.1x made
      // every page overflow by its last line.
      expect(
        _paginate(text, scale: 1.3).length,
        greaterThan(_paginate(text).length),
      );
    });

    test('pageOf finds the page holding a word', () {
      final pages = _paginate(text);
      final mid = pages.length ~/ 2;
      expect(MushafPaginator.pageOf(pages, pages[mid].start), mid);
      expect(MushafPaginator.pageOf(pages, pages[mid].end - 1), mid);
    });

    test('pageOf falls back to the first page for an unknown word', () {
      expect(MushafPaginator.pageOf(_paginate(text), 999999), 0);
    });

    test('no words means no pages', () {
      expect(_paginate(MushafText(const [])), isEmpty);
    });
  });
}
