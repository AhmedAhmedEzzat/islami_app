import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakina/core/constants/daily_verses.dart';
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

  // The phrase each reference is chosen for, so a mistyped number fails.
  const expected = {
    '2:152': 'فاذكروني اذكركم',
    '2:153': 'استعينوا بالصبر والصلاه',
    '2:186': 'فاني قريب',
    '2:255': 'الله لا اله الا هو الحي القيوم',
    '3:139': 'ولا تهنوا ولا تحزنوا',
    '3:173': 'حسبنا الله ونعم الوكيل',
    '9:40': 'لا تحزن ان الله معنا',
    '12:87': 'ولا تياسوا من روح الله',
    '13:28': 'بذكر الله تطمين القلوب',
    '14:7': 'لين شكرتم لازيدنكم',
    '29:69': 'لنهدينهم سبلنا',
    '33:41': 'اذكروا الله ذكرا كثيرا',
    '39:53': 'لا تقنطوا من رحمه الله',
    '40:60': 'ادعوني استجب لكم',
    '48:4': 'انزل السكينه في قلوب المومنين',
    '50:16': 'اقرب اليه من حبل الوريد',
    '57:4': 'وهو معكم اين ما كنتم',
    '65:3': 'ومن يتوكل علي الله فهو حسبه',
    '93:3': 'ما ودعك ربك وما قلي',
    '94:5–6': 'فان مع العسر يسرا',
  };

  test('every curated verse says what it was chosen for', () {
    expect(DailyVerses.curated.map((d) => d.label), unorderedEquals(expected.keys));
    for (final d in DailyVerses.curated) {
      final text = d.verses.map((v) => plain[v.key] ?? fail('${v.key} missing')).join(' ');
      expect(text, contains(expected[d.label]), reason: d.label);
    }
  });

  test('the verse is stable for a day and changes the next', () {
    final morning = DailyVerses.forDay(DateTime(2026, 3, 1, 6));
    expect(DailyVerses.forDay(DateTime(2026, 3, 1, 23, 59)), same(morning));
    expect(DailyVerses.forDay(DateTime(2026, 3, 2)), isNot(same(morning)));
  });

  test('the whole pool is reached and repeats only after a full cycle', () {
    final start = DateTime(2026, 1, 1);
    final seen = {
      for (var i = 0; i < DailyVerses.pool.length; i++)
        DailyVerses.forDay(start.add(Duration(days: i))).label,
    };
    expect(seen, hasLength(DailyVerses.pool.length));
  });
}
