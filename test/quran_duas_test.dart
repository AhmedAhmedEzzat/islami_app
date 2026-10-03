import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakina/core/constants/quran_duas.dart';
import 'package:sakina/core/services/quran_meta.dart';
import 'package:sakina/core/utils/arabic_text.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Map<String, String> plain;
  setUpAll(() async {
    final raw = await rootBundle.loadString('assets/quran/search.txt');
    plain = {
      for (final line in raw.split('\n').where((l) => l.contains('\t')))
        line.split('\t')[0]: ArabicText.normalizeForSearch(line.split('\t')[1]),
    };
  });

  String text(VerseRef v) => plain[v.key] ?? fail('${v.key} does not exist');

  test('every Rabbana dua opens on a verse that says ربنا', () {
    for (final d in QuranDuas.rabbana) {
      expect(text(d.start), contains('ربنا'), reason: d.label);
    }
  });

  test('every verse of every dua exists', () {
    for (final d in [...QuranDuas.rabbana, ...QuranDuas.prophets]) {
      expect(d.to, greaterThanOrEqualTo(d.from), reason: d.label);
      for (final v in d.verses) {
        text(v);
      }
    }
  });

  test("every prophets' reference addresses the Lord", () {
    for (final d in QuranDuas.prophets) {
      if (d.label == '21:87') {
        // Yunus's supplication is the tahlil, not a "Rabbi" opening.
        expect(text(d.start), contains('لا اله الا انت سبحانك'));
      } else {
        expect(text(d.start), contains('رب'), reason: d.label);
      }
    }
  });

  test('no reference is listed twice', () {
    final all = [
      for (final d in [...QuranDuas.rabbana, ...QuranDuas.prophets]) ...d.verses.map((v) => v.key),
    ];
    expect(all.toSet(), hasLength(all.length));
  });
}
