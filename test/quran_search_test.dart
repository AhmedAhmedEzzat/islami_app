import 'package:flutter_test/flutter_test.dart';
import 'package:sakina/core/services/quran_search_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<List<String>> keys(String q) async =>
      (await QuranSearchService.search(q)).map((h) => h.ref.key).toList();

  test('finds a verse typed without any diacritics', () async {
    expect(await keys('الحمد لله رب العالمين'), contains('1:2'));
    expect(await keys('قل هو الله احد'), contains('112:1'));
  });

  test('finds Ayat al-Kursi by a phrase from its middle', () async {
    expect(await keys('لا تاخذه سنه ولا نوم'), contains('2:255'));
  });

  test('searches the English translation too', () async {
    // Saheeh International renders الكرسي as "Kursi".
    expect(await keys('Kursi'), contains('2:255'));
    expect(await keys('drowsiness'), contains('2:255'));
  });

  test('Uthmani-only spellings are found by their everyday spelling', () async {
    // Uthmani: ٱلصَّلَوٰةَ, ٱلسَّمَٰوَٰتِ — typed: الصلاة, السماوات.
    expect(await keys('ويقيمون الصلاة'), contains('2:3'));
    expect(await keys('له ما في السماوات'), contains('2:255'));
  });

  test('a hit shows the Uthmani verse, not the search spelling', () async {
    final hit = (await QuranSearchService.search('الحمد لله رب العالمين')).first;
    expect(hit.ref.key, '1:2');
    expect(hit.arabic, contains('ٱلْعَٰلَمِينَ'));
  });

  test('a one-letter query returns nothing rather than everything', () async {
    expect(await keys('ا'), isEmpty);
  });

  test('results are capped', () async {
    final hits = await QuranSearchService.search('الله', limit: 50);
    expect(hits, hasLength(50));
  });

  test('results come in mushaf order', () async {
    final hits = await QuranSearchService.search('رب العالمين');
    for (var i = 1; i < hits.length; i++) {
      final a = hits[i - 1].ref, b = hits[i].ref;
      expect(a.sura < b.sura || (a.sura == b.sura && a.ayah < b.ayah), isTrue);
    }
  });

  group('finding a sura by name', () {
    List<String> ids(String q) => [for (final s in suraMatches(q)) s.suraID];

    test('Arabic names match however they are typed', () {
      expect(ids('الفاتحة'), ['1']);
      expect(ids('الفاتحه'), ['1']);
      expect(ids('النور'), ['24']);
      expect(ids('الانفطار'), ['82']);
      expect(ids('الإنشقاق'), ['84']);
      expect(ids('ال عمران'), ['3']);
      expect(ids('المزمل'), ['73']);
    });

    test('English names match with or without the hyphen', () {
      expect(ids('al-kahf'), ['18']);
      expect(ids('al kahf'), ['18']);
      expect(ids('Kahf'), ['18']);
      expect(ids('yasin'), ['36']);
      expect(ids('ya sin'), ['36']);
    });

    test('a number is the sura of that number, in either digits', () {
      expect(ids('18'), ['18']);
      expect(ids('١٨'), ['18']);
      expect(ids('115'), isEmpty);
    });

    test('nothing matches nothing', () {
      expect(ids('  '), isEmpty);
      expect(ids('zzzz'), isEmpty);
    });

    test('Arabic sura names are spelt the standard way, without marks', () {
      final names = [for (final s in suraMatches('ا')) s.suraNameAR];
      expect(names, contains('الفاتحة'));
      expect(names, contains('الانفطار'));
      expect(names, contains('الانشقاق'));
      // No shadda or other marks: some names had them and most did not.
      expect(names.where((n) => n.contains(RegExp('[\u064B-\u0652]'))), isEmpty);
    });
  });
}
