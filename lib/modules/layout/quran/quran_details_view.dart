import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/constants/constants.dart';
import '../../../core/constants/prefs_keys.dart';
import '../../../core/services/khatma.dart';
import '../../../core/services/mushaf_layout.dart';
import '../../../core/services/quran_meta.dart';
import '../../../core/services/quran_service.dart';
import '../../../core/services/recent_suras.dart';
import '../../../core/services/shared_prefs_helper.dart';
import '../../../core/state/bookmarks_cubit.dart';
import '../../../core/state/quran_player_cubit.dart';
import '../../../core/state/quran_player_state.dart';
import '../../../core/state/settings_cubit.dart';
import '../../../core/state/settings_state.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_background.dart';
import '../../../models/quran_open_request.dart';
import '../../../models/sura_data_model.dart';
import 'widgets/madani_mushaf.dart';
import 'widgets/verse_sheet.dart';
import 'widgets/quran_player_bar.dart';
import 'widgets/mushaf_page.dart';
import '../../../core/utils/l10n_ext.dart';

/// Which failure occurred, so the message can be localized at render time
/// rather than baked into state as English.
enum _Err { noSura, loadFailed }

class QuranDetailsView extends StatefulWidget {
  static const String routeName = '/quran-details';

  const QuranDetailsView({super.key});

  @override
  State<QuranDetailsView> createState() => _QuranDetailsViewState();
}

class _QuranDetailsViewState extends State<QuranDetailsView> {
  List<String> _verses = [];
  bool _isLoading = true;
  _Err? _error;

  /// The sura on screen. In the mushaf it follows the pages as they turn.
  SuraDataModel? _sura;
  int? _initialAyah;
  int? _initialPage;

  final GlobalKey<MadaniMushafState> _mushafKey = GlobalKey();
  MushafLayout? _layout;

  /// The mushaf page on screen, 1-based.
  int _page = 1;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The sura arrives as a route argument, so this is the earliest point we
    // can read it. It used to be loaded from build(), which fired a setState
    // during a build pass on every rebuild.
    if (_sura != null) return;

    final args = ModalRoute.of(context)?.settings.arguments;
    final sura = QuranOpenRequest.suraOf(args);
    if (sura == null) {
      setState(() {
        _error = _Err.noSura;
        _isLoading = false;
      });
      return;
    }
    _sura = sura;
    _initialAyah = QuranOpenRequest.ayahOf(args);
    _initialPage = QuranOpenRequest.pageOf(args);
    _load(sura.suraID);
  }

  Future<void> _load(String suraId) async {
    try {
      final (verses, layout, _) = await (
        QuranService.loadSura(suraId),
        MushafLayout.load(),
        QuranMeta.load(),
      ).wait;
      if (!mounted) return;
      setState(() {
        _verses = verses;
        _layout = layout;
        final ayah = (_initialAyah ?? MushafPage.savedPosition(suraId) + 1).clamp(1, verses.length);
        _page = _initialPage ?? layout.pageOf(VerseRef(int.parse(suraId), ayah));
        // The flowing view has no pages; it opens at the page's first verse.
        if (_initialPage != null && _initialAyah == null) {
          final first = layout.firstWord(_page);
          if ('${first.sura}' == suraId) _initialAyah = first.ayah;
        }
        _isLoading = false;
      });
      // The opening page is read as much as any page turned to.
      if (context.read<SettingsCubit>().state.mushafView) Khatma.notePage(_page);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _Err.loadFailed;
        _isLoading = false;
      });
    }
  }

  static SuraDataModel _model(int sura) => Constants.suraDataLists[sura - 1];

  void _onPageChanged(int page) {
    final layout = _layout;
    if (layout == null) return;
    final suras = layout.surasOn(page);
    final current = int.parse(_sura!.suraID);
    // Stay with the sura being read while it is still on the page, so a page
    // shared by two suras does not flip the title back and forth.
    final shown = suras.contains(current) ? current : suras.first;

    LocalStorageServices.setInt(PrefsKeys.lastMushafPage, page);
    if (Khatma.notePage(page)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${context.l10n.khatmaComplete}. ${context.l10n.khatmaCompleteBody}')),
      );
    }
    // Each sura on the page remembers its first verse here, for "continue
    // reading" and for reopening the sura at this page. A sura always starts
    // on a fresh line, so no line holds two.
    final seen = <int>{};
    for (final line in layout.page(page)) {
      final first = line.first;
      if (first == null || !seen.add(first.sura)) continue;
      LocalStorageServices.setInt(PrefsKeys.suraPosition('${first.sura}'), first.ayah - 1);
    }

    if (shown != current) {
      final model = _model(shown);
      RecentSuras.remember(model);
      QuranService.loadSura('$shown').then((v) {
        if (mounted) setState(() => _verses = v);
      });
      setState(() {
        _page = page;
        _sura = model;
      });
    } else {
      setState(() => _page = page);
    }
  }

  Future<void> _openVerse(VerseRef verse) async {
    final verses = await QuranService.loadSura('${verse.sura}');
    if (!mounted || verse.ayah > verses.length) return;
    VerseSheet.show(context, sura: _model(verse.sura), ayah: verse.ayah, text: verses[verse.ayah - 1]);
  }

  void _openFlowingVerse(int index) {
    final sura = _sura;
    if (sura == null || index < 0 || index >= _verses.length) return;
    VerseSheet.show(context, sura: sura, ayah: index + 1, text: _verses[index]);
  }

  Future<void> _switchView(bool mushaf) async {
    final layout = _layout;
    final sura = _sura;
    if (layout == null || sura == null) return;
    if (mushaf) {
      // Open the mushaf where the flowing text was left.
      final ayah = (MushafPage.savedPosition(sura.suraID) + 1).clamp(1, _verses.length);
      _page = layout.pageOf(VerseRef(int.parse(sura.suraID), ayah));
    } else {
      // And the flowing text at the top of the page that was showing.
      final first = layout.page(_page).firstWhere((l) => l.sura == int.parse(sura.suraID) && l.first != null).first!;
      _initialAyah = first.ayah;
    }
    context.read<SettingsCubit>().setMushafView(mushaf);
  }

  Future<void> _askForPage() async {
    final controller = TextEditingController();
    final page = await showDialog<int>(
      context: context,
      builder: (context) {
        void submit() => Navigator.pop(context, int.tryParse(controller.text));
        return AlertDialog(
          title: Text(context.l10n.goToPage),
          content: TextField(
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(hintText: context.l10n.goToPageHint),
            onSubmitted: (_) => submit(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
            ),
            FilledButton(onPressed: submit, child: Text(context.l10n.go)),
          ],
        );
      },
    );
    controller.dispose();
    if (page == null || page < 1 || page > MushafLayout.pageCount) return;
    _mushafKey.currentState?.goTo(page);
  }

  @override
  Widget build(BuildContext context) {
    final sura = _sura;
    final mushaf = context.select<SettingsCubit, bool>((c) => c.state.mushafView);
    final ready = sura != null && !_isLoading && _error == null;

    return Scaffold(
      appBar: AppBar(
        title: sura == null
            ? Text(context.l10n.quranTitle)
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(context.isArabic ? sura.suraNameAR : sura.suraNameEN),
                  if (ready && mushaf)
                    Text(
                      context.l10n.mushafPageTitle(_page),
                      style: context.texts.labelMedium?.copyWith(color: context.colors.onSurfaceVariant),
                    ),
                ],
              ),
        actions: [
          if (ready && mushaf)
            IconButton(
              tooltip: context.l10n.goToPage,
              icon: const Icon(Icons.find_in_page_outlined),
              onPressed: _askForPage,
            ),
          if (ready)
            IconButton(
              tooltip: mushaf ? context.l10n.flowingViewTooltip : context.l10n.mushafViewTooltip,
              icon: Icon(mushaf ? Icons.text_fields : Icons.auto_stories_outlined),
              onPressed: () => _switchView(!mushaf),
            ),
          if (ready)
            IconButton(
              tooltip: context.l10n.shareSura,
              icon: const Icon(Icons.share_outlined),
              onPressed: () => SharePlus.instance.share(
                ShareParams(
                  text:
                      '${sura.suraNameAR} (${sura.suraNameEN})\n\n'
                      '${_verses.join('\n')}',
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(child: _buildBody(mushaf)),
          if (sura != null && _error == null)
            QuranPlayerBar(sura: sura),
        ],
      ),
    );
  }

  Widget _buildBody(bool mushaf) {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(color: context.colors.primary),
      );
    }

    if (_error != null) {
      return AppStateMessage(
        icon: Icons.error_outline,
        message: _error == _Err.noSura
            ? context.l10n.noSuraSelected
            : context.l10n.suraLoadError,
        onRetry: _sura == null
            ? null
            : () {
                setState(() {
                  _isLoading = true;
                  _error = null;
                });
                _load(_sura!.suraID);
              },
      );
    }

    if (_verses.isEmpty) {
      return AppStateMessage(
        icon: Icons.menu_book_outlined,
        message: context.l10n.noSuraText,
      );
    }

    return mushaf ? _buildMushaf() : _buildFlowing();
  }

  Widget _buildMushaf() {
    return BlocBuilder<QuranPlayerCubit, QuranPlayerState>(
      // Only the verse matters here; position ticks would rebuild the whole
      // page several times a second.
      buildWhen: (a, b) => a.suraId != b.suraId || a.ayah != b.ayah,
      builder: (context, player) {
        final sura = int.tryParse(player.suraId ?? '');
        final ayah = player.ayah ?? 0;
        return BlocBuilder<BookmarksCubit, List<Bookmark>>(
          builder: (context, _) {
            final bookmarks = context.read<BookmarksCubit>();
            return MadaniMushaf(
              key: _mushafKey,
              layout: _layout!,
              initialPage: _page,
              onPageChanged: _onPageChanged,
              onVerseTap: _openVerse,
              highlight: sura != null && ayah > 0 ? VerseRef(sura, ayah) : null,
              isBookmarked: bookmarks.isBookmarked,
            );
          },
        );
      },
    );
  }

  Widget _buildFlowing() {
    final sura = _sura!;
    final suraNumber = int.parse(sura.suraID);

    return BlocBuilder<SettingsCubit, SettingsState>(
      buildWhen: (a, b) => a.quranFontScale != b.quranFontScale,
      builder: (context, settings) {
        return BlocBuilder<QuranPlayerCubit, QuranPlayerState>(
          // Only the verse matters here; position ticks would rebuild the
          // whole page several times a second.
          buildWhen: (a, b) => a.suraId != b.suraId || a.ayah != b.ayah,
          builder: (context, player) {
            final playingAyah = player.isLoaded(sura.suraID) ? player.ayah : null;
            return BlocBuilder<BookmarksCubit, List<Bookmark>>(
              builder: (context, _) => MushafPage(
                key: ValueKey(sura.suraID),
                sura: sura,
                verses: _verses,
                fontScale: settings.quranFontScale,
                onVerseTap: _openFlowingVerse,
                highlightVerse: (playingAyah ?? 0) > 0 ? playingAyah! - 1 : null,
                bookmarkedVerses: context.read<BookmarksCubit>().versesIn(suraNumber),
                initialAyah: _initialAyah,
              ),
            );
          },
        );
      },
    );
  }
}
