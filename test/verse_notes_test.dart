import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakina/core/services/quran_meta.dart';
import 'package:sakina/core/services/shared_prefs_helper.dart';
import 'package:sakina/core/state/verse_notes_cubit.dart';
import 'package:sakina/l10n/gen/app_localizations.dart';
import 'package:sakina/modules/layout/quran/widgets/verse_note_section.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorageServices.init();
  });

  const kursi = VerseRef(2, 255);

  test('a note and a highlight live side by side', () async {
    final cubit = VerseNotesCubit()..load();
    await cubit.setText(kursi, '  The greatest verse ');
    await cubit.setColor(kursi, HighlightColor.green);

    final note = cubit.noteFor(kursi)!;
    expect(note.text, 'The greatest verse');
    expect(note.color, HighlightColor.green);

    // Clearing one keeps the other.
    await cubit.setText(kursi, '');
    expect(cubit.noteFor(kursi)!.color, HighlightColor.green);
    await cubit.setColor(kursi, null);
    expect(cubit.noteFor(kursi), isNull);
    expect(cubit.state, isEmpty);
  });

  test('survives a reload, most recently changed first', () async {
    final first = VerseNotesCubit()..load();
    await first.setText(const VerseRef(1, 1), 'Opening', now: DateTime(2026, 1, 1));
    await first.setColor(const VerseRef(36, 1), HighlightColor.blue, now: DateTime(2026, 1, 2));
    await first.setText(const VerseRef(1, 1), 'Opening, again', now: DateTime(2026, 1, 3));

    final second = VerseNotesCubit()..load();
    expect(second.state.map((n) => n.verse.key), ['1:1', '36:1']);
    expect(second.noteFor(const VerseRef(1, 1))!.text, 'Opening, again');
    expect(second.noteFor(const VerseRef(36, 1))!.color, HighlightColor.blue);
  });

  test('tintsIn gives the highlighted verses of one sura', () async {
    final cubit = VerseNotesCubit()..load();
    await cubit.setColor(const VerseRef(2, 1), HighlightColor.yellow);
    await cubit.setText(const VerseRef(2, 2), 'note only');
    await cubit.setColor(const VerseRef(3, 1), HighlightColor.pink);

    expect(cubit.tintsIn(2), {1: HighlightColor.yellow.color});
  });

  test('an unreadable value is ignored', () async {
    SharedPreferences.setMockInitialValues({'flutter.quran.notes': 'not json'});
    await LocalStorageServices.init();
    final cubit = VerseNotesCubit()..load();
    expect(cubit.state, isEmpty);
  });

  testWidgets('the verse sheet section highlights and saves a note', (tester) async {
    final cubit = VerseNotesCubit()..load();
    await tester.pumpWidget(
      BlocProvider.value(
        value: cubit,
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: VerseNoteSection(verse: kursi, title: Text('Highlight and note'))),
        ),
      ),
    );

    await tester.tap(find.byTooltip('Highlight in green'));
    await tester.pump();
    expect(cubit.noteFor(kursi)!.color, HighlightColor.green);
    expect(find.byIcon(Icons.check), findsOneWidget);

    // Tapping it again takes it off.
    await tester.tap(find.byTooltip('Highlight in green'));
    await tester.pump();
    expect(cubit.noteFor(kursi), isNull);

    await tester.tap(find.text('Add a note'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Read it before sleeping');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(cubit.noteFor(kursi)!.text, 'Read it before sleeping');
    expect(find.text('Read it before sleeping'), findsOneWidget);

    await tester.tap(find.byTooltip('Delete note'));
    await tester.pump();
    expect(cubit.noteFor(kursi), isNull);
    expect(find.text('Add a note'), findsOneWidget);
  });
}
