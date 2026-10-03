import 'package:flutter_test/flutter_test.dart';
import 'package:sakina/core/services/quran_meta.dart';
import 'package:sakina/core/services/shared_prefs_helper.dart';
import 'package:sakina/core/services/tafsir_service.dart';
import 'package:sakina/core/state/bookmarks_cubit.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BookmarksCubit', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await LocalStorageServices.init();
    });

    test('toggle adds, then removes', () async {
      final cubit = BookmarksCubit()..load();
      const v = VerseRef(2, 255);

      expect(await cubit.toggle(v), isTrue);
      expect(cubit.isBookmarked(v), isTrue);

      expect(await cubit.toggle(v), isFalse);
      expect(cubit.isBookmarked(v), isFalse);
    });

    test('bookmarks survive a reload, newest first', () async {
      final first = BookmarksCubit()..load();
      await first.toggle(const VerseRef(1, 1), now: DateTime(2026, 1, 1));
      await first.toggle(const VerseRef(36, 1), now: DateTime(2026, 1, 2));

      final second = BookmarksCubit()..load();
      expect(second.state.map((b) => b.verse.key), ['36:1', '1:1']);
    });

    test('versesIn lists the bookmarked verses of one sura', () async {
      final cubit = BookmarksCubit()..load();
      await cubit.toggle(const VerseRef(2, 1));
      await cubit.toggle(const VerseRef(2, 255));
      await cubit.toggle(const VerseRef(3, 1));
      expect(cubit.versesIn(2), {1, 255});
    });

    test('a corrupt stored value is ignored rather than crashing', () async {
      SharedPreferences.setMockInitialValues({'flutter.quran.bookmarks': '{not json'});
      await LocalStorageServices.init();
      final cubit = BookmarksCubit()..load();
      expect(cubit.state, isEmpty);
    });
  });

  group('VerseRef', () {
    test('round-trips through its key', () {
      expect(VerseRef.parse('2:255'), const VerseRef(2, 255));
      expect(const VerseRef(2, 255).key, '2:255');
    });

    test('rejects malformed keys', () {
      expect(VerseRef.parse('2'), isNull);
      expect(VerseRef.parse('a:b'), isNull);
      expect(VerseRef.parse(''), isNull);
    });
  });

  group('TafsirService.parseResponse', () {
    test('reads one text per verse', () {
      const body =
          '{"code":200,"data":{"ayahs":[{"text":" first "},{"text":"second"}]}}';
      expect(TafsirService.parseResponse(body), ['first', 'second']);
    });

    test('an error response yields null, not an empty tafsir', () {
      expect(TafsirService.parseResponse('{"code":404,"data":"x"}'), isNull);
    });

    test('malformed JSON yields null', () {
      expect(TafsirService.parseResponse('<html>'), isNull);
    });
  });
}
