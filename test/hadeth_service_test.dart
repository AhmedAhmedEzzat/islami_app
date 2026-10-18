import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakina/core/services/hadeth_service.dart';
import 'package:sakina/core/utils/arabic_text.dart';
import 'package:sakina/models/hadeth_data_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('parse reads one entry per hadeth, with an optional translation', () {
    final all = HadethService.parse(
      '{"hadeth":[{"n":1,"c":"nawawi","title":"t","ar":["a","b"],"en":"e"},'
      '{"n":43,"c":"ibn_rajab","title":"u","ar":["c"],"en":null}]}',
    );
    expect(all.map((h) => h.number), [1, 43]);
    expect(all.first.content, ['a', 'b']);
    expect(all.first.english, 'e');
    expect(all.last.english, isNull);
    expect(all.last.collection, HadethCollection.ibnRajab);
  });

  group('the bundled asset', () {
    late List<HadethDataModel> all;
    setUpAll(
      () async => all = HadethService.parse(
        await rootBundle.loadString(HadethService.asset),
      ),
    );

    test(
      'numbers 1..50: 42 of An-Nawawi with English, then 8 of Ibn Rajab',
      () {
        expect(
          all.take(HadethService.hadethCount).map((h) => h.number),
          List.generate(HadethService.hadethCount, (i) => i + 1),
        );
        final nawawi = all
            .where((h) => h.collection == HadethCollection.nawawi)
            .toList();
        expect(nawawi.map((h) => h.number), List.generate(42, (i) => i + 1));
        for (final h in nawawi) {
          expect(
            h.english,
            isNotEmpty,
            reason: 'hadith ${h.number} has no translation',
          );
        }
        expect(
          all.skip(42).take(8).every((h) => h.collection == HadethCollection.ibnRajab),
          isTrue,
        );
      },
    );

    test('then the forty Qudsi, numbered 101..140, each with English', () {
      final qudsi = all.where((h) => h.collection == HadethCollection.qudsi).toList();
      expect(
        qudsi.map((h) => h.number),
        List.generate(HadethService.qudsiCount, (i) => HadethService.qudsiFirst + i),
      );
      for (final h in qudsi) {
        expect(h.title, startsWith('الحديث القدسي '));
        expect(h.english, isNotEmpty, reason: 'qudsi ${h.number}');
      }
      expect(ArabicText.normalizeForSearch(qudsi.first.content.join(' ')), contains('ان رحمتي تغلب غضبي'));
      // Favourites are kept by number, so numbers must be unique.
      expect(all.map((h) => h.number).toSet().length, all.length);
    });

    test('every hadeth has a title and text, with no markup left in it', () {
      for (final h in all) {
        expect(h.title, startsWith('الحديث '));
        expect(h.content, isNotEmpty, reason: 'hadith ${h.number}');
        for (final p in h.content) {
          expect(p, isNot(contains('<')), reason: 'hadith ${h.number}');
          expect(
            p,
            isNot(contains('ـ')),
            reason: 'tatweel in hadith ${h.number}',
          );
        }
      }
    });

    test('the text is what each number should be', () {
      String plain(int n) =>
          ArabicText.normalizeForSearch(all[n - 1].content.join(' '));
      expect(plain(1), contains('انما الاعمال بالنيات'));
      expect(plain(40), contains('كن في الدنيا كانك غريب'));
      expect(plain(42), contains('يا ابن ادم'));
      expect(all[0].english, contains('Actions are'));
    });
  });
}
