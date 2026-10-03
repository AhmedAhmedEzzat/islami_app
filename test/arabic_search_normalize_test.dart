import 'package:flutter_test/flutter_test.dart';
import 'package:sakina/core/utils/arabic_text.dart';

String n(String s) => ArabicText.normalizeForSearch(s);

void main() {
  test('a typed word matches its Uthmani spelling', () {
    // Alef wasla, shadda, dagger alef and kasra all fall away.
    expect(n('ٱلرَّحْمَٰنِ'), n('الرحمن'));
    expect(n('ٱلرَّحْمَٰنِ'), 'الرحمن');
  });

  test('every alef form folds to bare alef', () {
    expect(n('أإآٱ'), 'اااا');
  });

  test('ta marbuta, alef maqsura and hamza carriers fold', () {
    expect(n('رحمة'), n('رحمه'));
    expect(n('على'), n('علي'));
    expect(n('مؤمن'), n('مومن'));
  });

  test('Quranic annotation marks are removed', () {
    // U+06DA (small jeem) and U+06E5 (small waw) appear in the Uthmani text.
    expect(n('ٱلْقَيُّومُۚ'), 'القيوم');
    expect(n('بِهِۦ'), 'به');
  });

  test('tatweel and doubled spaces are cleaned up', () {
    expect(n('الـــحمد   لله'), 'الحمد لله');
  });

  test('a real verse can be found by a phrase typed without diacritics', () {
    const ayatAlKursi = 'ٱللَّهُ لَآ إِلَٰهَ إِلَّا هُوَ ٱلْحَىُّ ٱلْقَيُّومُۚ';
    expect(n(ayatAlKursi).contains(n('الحي القيوم')), isTrue);
    expect(n(ayatAlKursi).contains(n('لا اله الا هو')), isTrue);
  });
}
