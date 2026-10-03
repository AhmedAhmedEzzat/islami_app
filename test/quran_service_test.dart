import 'package:flutter_test/flutter_test.dart';
import 'package:sakina/core/services/quran_service.dart';

void main() {
  group('QuranService.parseVerses', () {
    test('strips the UTF-8 BOM that every sura file starts with', () {
      final verses = QuranService.parseVerses('﻿الْحَمْدُ لِلَّهِ');
      expect(verses.single.startsWith('﻿'), isFalse);
      expect(verses.single, 'الْحَمْدُ لِلَّهِ');
    });

    test('does not emit a phantom verse for a trailing newline', () {
      // This is the original bug: a naive split('\n') turned a 3-verse sura
      // into 4, the last one blank and numbered [4].
      expect(QuranService.parseVerses('one\ntwo\nthree\n'), hasLength(3));
    });

    test('drops blank and whitespace-only lines', () {
      expect(QuranService.parseVerses('one\n\n   \ntwo'), ['one', 'two']);
    });

    test('trims the leading spaces present in several files', () {
      expect(QuranService.parseVerses(' one \n  two'), ['one', 'two']);
    });

    test('normalises CRLF and bare CR line endings', () {
      expect(QuranService.parseVerses('one\r\ntwo\rthree'), hasLength(3));
    });

    test('returns an empty list for empty or whitespace-only input', () {
      expect(QuranService.parseVerses(''), isEmpty);
      expect(QuranService.parseVerses('﻿\n  \n'), isEmpty);
    });
  });
}
