import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakina/core/services/hifz.dart';
import 'package:sakina/core/state/bookmarks_cubit.dart';
import 'package:sakina/core/state/settings_cubit.dart';
import 'package:sakina/core/state/verse_notes_cubit.dart';
import 'package:sakina/l10n/gen/app_localizations.dart';
import 'package:sakina/core/widgets/app_restart.dart';
import 'package:sakina/modules/settings/backup_tiles.dart';
import 'package:sakina/core/services/backup.dart';
import 'package:sakina/core/services/shared_prefs_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> start(Map<String, Object> values) async {
    SharedPreferences.setMockInitialValues(values);
    await LocalStorageServices.init();
  }

  test('a backup carries every kind of value across to another phone', () async {
    await start({
      'quran.bookmarks': '[{"v":"2:255","t":1}]',
      'settings.quranFontScale': 1.0,
      'qada.fajr': 3,
      'settings.fridayKahf': false,
      'tasbeh.list': ['a', 'b'],
      // This phone's alone:
      'settings.customAdhan': '{"uri":"content://x","title":"x"}',
      'recitation.downloads.alafasy': '[1,2]',
      'review.asks': 2,
      'widget.prayers': '{}',
    });
    final text = Backup.encode(now: DateTime(2026, 10, 19));

    await start({'quran.bookmarks': '[]', 'recitation.downloads.minshawi': '[3]', 'qada.isha': 9});
    final file = Backup.decode(text)!;
    expect(file.created, DateTime(2026, 10, 19));
    await Backup.restore(file);

    expect(LocalStorageServices.getString('quran.bookmarks'), '[{"v":"2:255","t":1}]');
    expect(LocalStorageServices.getDouble('settings.quranFontScale'), 1.0);
    expect(LocalStorageServices.getInt('qada.fajr'), 3);
    expect(LocalStorageServices.getBool('settings.fridayKahf'), false);
    expect(LocalStorageServices.getStringList('tasbeh.list'), ['a', 'b']);
    // Replaced, not merged.
    expect(LocalStorageServices.getInt('qada.isha'), isNull);
    // Nothing tied to the old phone came across, and this phone's own stayed.
    expect(LocalStorageServices.getString('settings.customAdhan'), isNull);
    expect(LocalStorageServices.getString('recitation.downloads.alafasy'), isNull);
    expect(LocalStorageServices.getInt('review.asks'), isNull);
    expect(LocalStorageServices.getString('recitation.downloads.minshawi'), '[3]');
  });

  test('the old phone\'s GPS fix stays behind; a city chosen by hand comes across', () async {
    await start({'location.latitude': 21.4, 'location.manual.name': 'Makkah'});
    final text = Backup.encode();
    await start({'location.latitude': 30.0});
    await Backup.restore(Backup.decode(text)!);
    expect(LocalStorageServices.getDouble('location.latitude'), 30.0);
    expect(LocalStorageServices.getString('location.manual.name'), 'Makkah');
  });

  test('a byte-order mark is allowed, a malformed date is not fatal', () async {
    await start({});
    expect(Backup.decode('\uFEFF{"app":"sakina","version":1,"data":{"x":{"s":"y"}}}')!.entries, {'x': 'y'});
    expect(Backup.decode('{"app":"sakina","version":1,"created":5,"data":{}}')!.created, isNull);
    expect(Backup.decode('{"app":"sakina","version":1,"data":{"x":5}}')!.entries, isEmpty);
  });

  test('a value of the wrong type for a key is left out, and could not crash a read', () async {
    await start({'settings.locale': 'ar'});
    final file = Backup.decode('{"app":"sakina","version":1,"data":{"settings.locale":{"i":5}}}')!;
    expect(file.entries, isEmpty);
    // Even stored wrongly, reading it gives null instead of throwing.
    await start({'settings.locale': 5});
    expect(LocalStorageServices.getString('settings.locale'), isNull);
  });

  test('anything but a Sakina backup is refused', () {
    expect(Backup.decode('not json'), isNull);
    expect(Backup.decode('{"app":"other","version":1,"data":{}}'), isNull);
    expect(Backup.decode('{"app":"sakina","version":99,"data":{}}'), isNull);
    expect(Backup.decode('{"app":"sakina","version":1}'), isNull);
    expect(Backup.decode('{"app":"sakina","version":1,"data":{"x":{"s":"y"},"bad":{"q":1},"settings.customAdhan":{"s":"z"}}}')!.entries,
        {'x': 'y'});
  });

  testWidgets('restoring a picked file replaces the data and refreshes what is on screen', (tester) async {
    await start({'quran.bookmarks': '[{"v":"1:1","t":1}]', 'settings.reciterId': 'minshawi'});
    final backup = Backup.encode();
    await start({'quran.bookmarks': '[]'});
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    const files = MethodChannel('sakina/files');
    messenger.setMockMethodCallHandler(files, (call) async => backup);
    addTearDown(() => messenger.setMockMethodCallHandler(files, null));

    final settings = SettingsCubit()..load();
    final bookmarks = BookmarksCubit()..load();
    final hifzBefore = Hifz.changes.value;
    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider.value(value: settings),
          BlocProvider.value(value: bookmarks),
          BlocProvider(create: (_) => VerseNotesCubit()..load()),
        ],
        // Rebuilt by AppRestart, as the real app is.
        child: ValueListenableBuilder<int>(
          valueListenable: AppRestart.generation,
          builder: (context, generation, _) => MaterialApp(
            key: ValueKey(generation),
            navigatorKey: AppRestart.navigatorKey,
            locale: const Locale('en'),
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(body: BackupTiles()),
          ),
        ),
      ),
    );
    expect(bookmarks.state, isEmpty);

    await tester.tap(find.text('Restore from a backup'));
    await tester.pumpAndSettle();
    expect(find.text('Restore this backup?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Restore from a backup'));
    await tester.pumpAndSettle();

    expect(bookmarks.state.single.verse.key, '1:1');
    expect(settings.state.reciterId, 'minshawi');
    expect(Hifz.changes.value, greaterThan(hifzBefore));
    expect(find.text('Backup restored.'), findsOneWidget);
  });

  testWidgets('a file that is not a backup is refused', (tester) async {
    await start({});
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    const files = MethodChannel('sakina/files');
    messenger.setMockMethodCallHandler(files, (call) async => '{"hello":1}');
    addTearDown(() => messenger.setMockMethodCallHandler(files, null));
    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider(create: (_) => SettingsCubit()..load()),
          BlocProvider(create: (_) => BookmarksCubit()..load()),
          BlocProvider(create: (_) => VerseNotesCubit()..load()),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: BackupTiles()),
        ),
      ),
    );
    await tester.tap(find.text('Restore from a backup'));
    await tester.pumpAndSettle();
    expect(find.text('That is not a Sakina backup file.'), findsOneWidget);
  });
}
