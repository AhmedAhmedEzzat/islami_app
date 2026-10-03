import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakina/core/constants/constants.dart';
import 'package:sakina/core/services/quran_meta.dart';
import 'package:sakina/core/services/quran_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<List<String>> arabic(int id) async =>
      QuranService.parseVerses(await rootBundle.loadString('assets/quran/ar/$id.txt'));

  Future<List<String>> english(int id) async => (await rootBundle.loadString(
    'assets/quran/en/$id.txt',
  )).split('\n').where((l) => l.trim().isNotEmpty).toList();

  test('all 114 suras are declared in metadata', () {
    expect(Constants.suraDataLists, hasLength(114));
  });

  test('every sura has exactly its declared number of verses', () async {
    // The previous bundled text had nine suras with verses merged or split.
    // The Tanzil text must match all 114, with no exceptions.
    final wrong = <String>[];
    var total = 0;
    for (var id = 1; id <= 114; id++) {
      final parsed = (await arabic(id)).length;
      total += parsed;
      final declared = int.parse(Constants.suraDataLists[id - 1].suraVersesNumber);
      if (parsed != declared) wrong.add('sura $id: $parsed vs $declared');
    }
    expect(wrong, isEmpty, reason: wrong.join('\n'));
    expect(total, 6236);
  });

  test('the translation is aligned verse-for-verse with the Arabic', () async {
    for (var id = 1; id <= 114; id++) {
      expect((await english(id)).length, (await arabic(id)).length, reason: 'sura $id');
    }
  });

  test('the basmala is a header, not glued onto verse 1', () async {
    // The source prefixes it to verse 1 of 112 suras. Al-Fatiha keeps it as
    // its first verse; At-Tawbah has none.
    expect((await arabic(1)).first, contains('بِسْمِ'));
    for (final id in [2, 3, 18, 36, 95, 97, 114]) {
      expect((await arabic(id)).first, isNot(contains('ٱلرَّحِيمِ')), reason: 'sura $id');
    }
    expect((await arabic(2)).first, 'الٓمٓ');
  });

  test('no verse is blank or starts with an invisible mark', () async {
    for (var id = 1; id <= 114; id++) {
      for (final verse in await arabic(id)) {
        expect(verse.trim(), isNotEmpty, reason: 'blank verse in sura $id');
        expect(verse.codeUnitAt(0), isNot(0xFEFF), reason: 'BOM in sura $id');
      }
    }
  });

  group('metadata agrees with the printed mushaf', () {
    late QuranMeta meta;
    setUpAll(() async => meta = await QuranMeta.load());

    test('30 juz with the standard starting points', () {
      expect(meta.juzStarts, hasLength(30));
      expect(meta.juzStarts.first, const VerseRef(1, 1));
      expect(meta.juzStarts[1], const VerseRef(2, 142));
      expect(meta.juzStarts[2], const VerseRef(2, 253));
      expect(meta.juzStarts.last, const VerseRef(78, 1));
    });

    test('240 hizb quarters', () {
      expect(meta.hizbStarts, hasLength(240));
      expect(meta.hizbOf(const VerseRef(114, 6)), 60);
    });

    test('exactly the 15 verses of prostration', () {
      final sajda = meta.sajdaVerses.map((v) => v.key).toSet();
      expect(sajda, {
        '7:206', '13:15', '16:50', '17:109', '19:58', '22:18', '22:77', '25:60',
        '27:26', '32:15', '38:24', '41:38', '53:62', '84:21', '96:19',
      });
    });

    test('Ayat al-Kursi sits in juz 3', () {
      expect(meta.juzOf(const VerseRef(2, 255)), 3);
    });

    test('the mushaf runs to 604 pages', () {
      expect(meta.pageOf(const VerseRef(1, 1)), 1);
      expect(meta.pageOf(const VerseRef(114, 6)), 604);
    });

    test('revelation place is recorded', () {
      expect(meta.sura(1).isMeccan, isTrue);
      expect(meta.sura(2).isMeccan, isFalse);
      expect(meta.sura(2).meaning, 'The Cow');
    });
  });

  test('verseCountMismatch reports a disagreement and stays quiet otherwise', () {
    final declared = int.parse(Constants.suraDataLists[0].suraVersesNumber);
    expect(QuranService.verseCountMismatch('1', declared), isNull);
    expect(QuranService.verseCountMismatch('1', declared + 1), isNotNull);
    expect(QuranService.verseCountMismatch('999', 1), isNotNull);
  });
}
