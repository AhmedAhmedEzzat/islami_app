import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakina/core/services/azkar_service.dart';
import 'package:sakina/core/utils/arabic_text.dart';
import 'package:sakina/models/zikr_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AzkarService.parse', () {
    test('reads chapters and their adhkar', () {
      final chapters = AzkarService.parse(
        '{"chapters":[{"id":28,"title":"أذكار النوم","items":'
        '[{"id":1,"text":"بِاسْمِكَ رَبِّي","repeat":3}]}]}',
      );
      expect(chapters.single.id, 28);
      expect(chapters.single.items.single.count, 3);
    });

    test('a missing or zero repeat count becomes 1, never 0', () {
      // A zero count would leave the card permanently "done" and untappable.
      final chapters = AzkarService.parse(
        '{"chapters":[{"id":1,"title":"t","items":[{"id":1,"text":"a"},{"id":2,"text":"b","repeat":0}]}]}',
      );
      expect(chapters.single.items.map((z) => z.count), [1, 1]);
    });

    test('empty chapters and blank adhkar are dropped', () {
      final chapters = AzkarService.parse(
        '{"chapters":[{"id":1,"title":"t","items":[{"id":1,"text":"  "}]},'
        '{"id":2,"title":"u","items":[{"id":2,"text":"x"}]}]}',
      );
      expect(chapters.map((c) => c.id), [2]);
    });

    test('a malformed file yields nothing rather than throwing', () {
      expect(AzkarService.parse('[1,2]'), isEmpty);
      expect(AzkarService.parse('{"chapters":"x"}'), isEmpty);
    });
  });

  group('bundled Hisn al-Muslim', () {
    late List<AzkarChapter> chapters;
    setUpAll(() async {
      chapters = AzkarService.parse(await rootBundle.loadString('assets/azkar/hisn.json'));
    });

    test('has every chapter of the source', () {
      expect(chapters, hasLength(132));
    });

    test('chapter ids are unique', () {
      final ids = chapters.map((c) => c.id).toList();
      expect(ids.toSet(), hasLength(ids.length));
    });

    test('every featured chapter exists and is not empty', () {
      final byId = {for (final c in chapters) c.id: c};
      for (final id in FeaturedAzkar.all) {
        expect(byId[id]?.items, isNotEmpty, reason: 'featured chapter $id');
      }
    });

    test('the featured ids point at the chapters they claim to', () {
      String title(int id) => chapters.firstWhere((c) => c.id == id).title;
      expect(title(FeaturedAzkar.morningEvening), contains('الصباح'));
      expect(title(FeaturedAzkar.sleep), contains('النوم'));
      expect(title(FeaturedAzkar.afterPrayer), contains('السلام من الصلاة'));
      expect(title(FeaturedAzkar.istikhara), contains('الاستخارة'));
    });

    test('no dhikr is blank or starts with a BOM', () {
      for (final c in chapters) {
        for (final z in c.items) {
          expect(z.text.trim(), isNotEmpty, reason: 'chapter ${c.id}');
          expect(z.text.codeUnitAt(0), isNot(0xFEFF), reason: 'chapter ${c.id}');
          expect(z.count, greaterThan(0));
        }
      }
    });

    test('morning adhkar include Ayat al-Kursi, as the book does', () {
      final morning = chapters.firstWhere((c) => c.id == FeaturedAzkar.morningEvening);
      // Compared normalised: the book's diacritics differ from a typed phrase.
      expect(
        morning.items.any(
          (z) => ArabicText.normalizeForSearch(z.text).contains('الحي القيوم'),
        ),
        isTrue,
      );
    });
  });
}
