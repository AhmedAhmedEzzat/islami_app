import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/services/quran_service.dart';
import '../../../core/state/bookmarks_cubit.dart';
import '../../../core/state/quran_player_cubit.dart';
import '../../../core/state/quran_player_state.dart';
import '../../../core/state/settings_cubit.dart';
import '../../../core/state/settings_state.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_background.dart';
import '../../../models/quran_open_request.dart';
import '../../../models/sura_data_model.dart';
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
  SuraDataModel? _sura;
  int? _initialAyah;

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
    _load(sura.suraID);
  }

  Future<void> _load(String suraId) async {
    try {
      final verses = await QuranService.loadSura(suraId);
      if (!mounted) return;
      setState(() {
        _verses = verses;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _Err.loadFailed;
        _isLoading = false;
      });
    }
  }

  void _openVerse(int index) {
    final sura = _sura;
    if (sura == null || index < 0 || index >= _verses.length) return;
    VerseSheet.show(context, sura: sura, ayah: index + 1, text: _verses[index]);
  }

  @override
  Widget build(BuildContext context) {
    final sura = _sura;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          sura == null
              ? context.l10n.quranTitle
              : (context.isArabic ? sura.suraNameAR : sura.suraNameEN),
        ),
        actions: [
          if (sura != null && !_isLoading && _error == null)
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
          Expanded(child: _buildBody()),
          if (sura != null && _error == null)
            QuranPlayerBar(sura: sura),
        ],
      ),
    );
  }

  Widget _buildBody() {
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
                sura: sura,
                verses: _verses,
                fontScale: settings.quranFontScale,
                onVerseTap: _openVerse,
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
