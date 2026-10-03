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
}
