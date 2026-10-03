import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../../core/constants/assets.dart';
import '../../../../core/constants/prefs_keys.dart';
import '../../../../core/services/quran_meta.dart';
import '../../../../core/services/shared_prefs_helper.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/utils/arabic_text.dart';
import '../../../../core/utils/l10n_ext.dart';
import '../../../../models/sura_data_model.dart';
import 'mushaf_paginator.dart';

/// Renders a sura the way a printed mushaf does: framed pages you turn one at
/// a time, each a justified block of Arabic whose verses end in numbered
/// rosettes. The page you leave on is remembered and reopened next time.
class MushafPage extends StatefulWidget {
  const MushafPage({
    super.key,
    required this.sura,
    required this.verses,
    required this.fontScale,
    this.onVerseTap,
    this.highlightVerse,
    this.bookmarkedVerses = const {},
    this.initialAyah,
  });

  final SuraDataModel sura;
  final List<String> verses;
  final double fontScale;

  /// Called with the zero-based verse index when a verse is tapped.
  final void Function(int index)? onVerseTap;

  /// Zero-based verse being recited right now, if this sura is playing. It is
  /// highlighted, and the page turns by itself to keep it in view.
  final int? highlightVerse;

  /// 1-based verses the reader has bookmarked; their rosettes are filled.
  final Set<int> bookmarkedVerses;

  /// Open at this 1-based verse instead of the saved reading position, e.g.
  /// when arriving from a juz, a bookmark or a search result.
  final int? initialAyah;

  /// The basmala as written in the Uthmani text the verses come from.
  static const String basmala = 'بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ';

  /// At-Tawbah is the only sura that does not open with the basmala, and
  /// Al-Fatiha already carries it as its first verse.
  static bool showsBasmala(String suraId) {
    final id = int.tryParse(suraId);
    return id != 9 && id != 1;
  }

  /// Where the reader left this sura, as a verse index. 0 if never opened.
  static int savedPosition(String suraId) =>
      LocalStorageServices.getInt(PrefsKeys.suraPosition(suraId)) ?? 0;

  @override
  State<MushafPage> createState() => _MushafPageState();
}

class _MushafPageState extends State<MushafPage> {
  // Layout constants, shared by the measuring pass and the painting pass so
  // the two cannot disagree about how much room a page has.
  static const double _outerH = AppSpacing.md;
  static const double _outerV = AppSpacing.sm;
  static const double _frameInset = 8; // border + gap + inner border
  static const double _contentPad = AppSpacing.lg;
  static const double _footerHeight = 36;

  /// The "Page 3 of 12" row under the page. Fixed so it can be subtracted.
  static const double _labelHeight = 28;

  /// The juz / hizb strip across the top of every page.
  static const double _stripHeight = 22;

  /// Measuring is not pixel-exact against the real render (fonts, rounding),
  /// so pages are filled to slightly less than their true capacity.
  static const double _safety = 0.97;

  final Map<int, TapGestureRecognizer> _recognizers = {};

  PageController? _controller;
  List<MushafPageRange> _pages = const [];
  _PaginationKey? _paginatedFor;

  late MushafText _text;

  /// The word at the top of the page on screen. Pagination changes with text
  /// size, so this — not a page number — is what survives a repaginate.
  late int _anchorWord;
  bool _announcedResume = false;
  ScaffoldMessengerState? _messenger;

  @override
  void initState() {
    super.initState();
    _text = MushafText(widget.verses);
    final saved =
        LocalStorageServices.getInt(PrefsKeys.suraWord(widget.sura.suraID)) ??
        0;
    _anchorWord = _text.length == 0 ? 0 : saved.clamp(0, _text.length - 1);

    final requested = widget.initialAyah;
    if (requested != null && requested >= 1 && requested <= _text.verseCount) {
      _anchorWord = _text.verseStart[requested - 1];
      // The reader asked for this place; "continuing from page N" would be
      // wrong here.
      _announcedResume = true;
    }
  }

  @override
  void didUpdateWidget(MushafPage old) {
    super.didUpdateWidget(old);
    if (!identical(old.verses, widget.verses)) {
      _text = MushafText(widget.verses);
      _paginatedFor = null;
    }
    final verse = widget.highlightVerse;
    if (verse != null && verse != old.highlightVerse) _follow(verse);
  }

  /// Turns to the page holding [verse] (0-based) if it is not already showing.
  void _follow(int verse) {
    if (verse < 0 || verse >= _text.verseCount) return;
    final target = MushafPaginator.pageOf(_pages, _text.verseStart[verse]);
    final controller = _controller;
    if (controller == null || !controller.hasClients) return;
    if ((controller.page ?? controller.initialPage).round() == target) return;
    controller.animateToPage(
      target,
      duration: AppDurations.slow,
      curve: Curves.easeInOut,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _messenger = ScaffoldMessenger.maybeOf(context);
  }

  @override
  void dispose() {
    // The resume message belongs to this sura; do not leave it hanging over
    // whatever screen the reader goes to next.
    _messenger?.hideCurrentSnackBar();
    for (final recognizer in _recognizers.values) {
      recognizer.dispose();
    }
    _controller?.dispose();
    super.dispose();
  }

  TapGestureRecognizer _recognizerFor(int verse) {
    return _recognizers.putIfAbsent(
      verse,
      () =>
          TapGestureRecognizer()
            ..onTap = () => widget.onVerseTap?.call(verse),
    );
  }

  // Amiri Quran: a mushaf typeface that carries every Uthmani mark.
  TextStyle _bodyStyle(BuildContext context) => TextStyle(
    fontFamily: 'AmiriQuran',
    fontSize: 21 * widget.fontScale,
    height: 2.0,
    fontWeight: FontWeight.w500,
    color: context.sakina.verseText,
  );

  Size get _rosetteSize => Size.square(26 * widget.fontScale);

  bool _isSajda(int verse) {
    final meta = QuranMeta.instance;
    final sura = int.tryParse(widget.sura.suraID);
    if (meta == null || sura == null) return false;
    return meta.isSajda(VerseRef(sura, verse + 1));
  }

  /// "Juz 1 · Hizb 2" for the verse a page starts with.
  String? _pageStrip(BuildContext context, int page) {
    final meta = QuranMeta.instance;
    final sura = int.tryParse(widget.sura.suraID);
    if (meta == null || sura == null || page >= _pages.length) return null;
    final ref = VerseRef(sura, _text.verseOfWord[_pages[page].start] + 1);
    return '${context.l10n.juzLabel(meta.juzOf(ref))} · '
        '${context.l10n.hizbLabel(meta.hizbOf(ref))}';
  }

  static String _arabicDigits(int value) => ArabicText.digits(value);

  /// Builds the paragraph for words [start, end). A page may begin or end in
  /// the middle of a verse; the rosette is only drawn where a verse actually
  /// finishes. Used both to measure and to paint, so what was measured is
  /// exactly what is drawn.
  InlineSpan _span(
    BuildContext context,
    int start,
    int end, {
    bool live = false,
  }) {
    final children = <InlineSpan>[];
    var i = start;
    while (i < end) {
      final verse = _text.verseOfWord[i];
      final segmentEnd = end < _text.verseEnd[verse]
          ? end
          : _text.verseEnd[verse];
      final highlighted = live && verse == widget.highlightVerse;
      children.add(
        TextSpan(
          text: '${_text.words.sublist(i, segmentEnd).join(' ')} ',
          recognizer: live ? _recognizerFor(verse) : null,
          // Background only: it must not change the layout that was measured.
          style: highlighted
              ? TextStyle(
                  backgroundColor: context.colors.primary.withValues(
                    alpha: 0.22,
                  ),
                )
              : null,
        ),
      );
      if (segmentEnd == _text.verseEnd[verse]) {
        children.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: _VerseRosette(
              label: _arabicDigits(verse + 1),
              size: _rosetteSize.width,
              filled: live && widget.bookmarkedVerses.contains(verse + 1),
            ),
          ),
        );
        if (_isSajda(verse)) {
          // Part of the measured span too, so the page still fits.
          children.add(
            TextSpan(
              text: ' ۩',
              style: TextStyle(color: context.colors.primary),
            ),
          );
        }
        children.add(const TextSpan(text: '  '));
      }
      i = segmentEnd;
    }
    return TextSpan(style: _bodyStyle(context), children: children);
  }

  /// Height the first page loses to the sura banner and the basmala,
  /// measured with the same styles and scaler the header renders with.
  double _headerHeight(BuildContext context, double width, TextScaler scaler) {
    final title = MushafPaginator.lineHeight(
      'سُورَةُ ${widget.sura.suraNameAR}',
      context.texts.titleLarge,
      width,
      scaler,
      direction: TextDirection.rtl,
    );
    final subtitle = MushafPaginator.lineHeight(
      widget.sura.suraNameEN,
      context.texts.labelSmall,
      width,
      scaler,
    );
    // banner: vertical padding + border + title + gap + subtitle
    final banner = AppSpacing.sm * 2 + 2 + title + 2 + subtitle;
    final basmala = MushafPage.showsBasmala(widget.sura.suraID)
        ? AppSpacing.lg +
              MushafPaginator.lineHeight(
                MushafPage.basmala,
                _bodyStyle(
                  context,
                ).copyWith(fontWeight: FontWeight.w700, height: 1.8),
                width,
                scaler,
                direction: TextDirection.rtl,
              )
        : 0;
    return banner + basmala + AppSpacing.lg;
  }

  void _paginate(BuildContext context, BoxConstraints constraints) {
    final key = _PaginationKey(
      constraints.maxWidth,
      constraints.maxHeight,
      widget.fontScale,
      widget.verses.length,
    );
    if (key == _paginatedFor) return;
    _paginatedFor = key;

    final width =
        constraints.maxWidth - 2 * (_outerH + _frameInset + _contentPad);
    final pageHeight =
        (constraints.maxHeight -
            _labelHeight -
            _stripHeight -
            2 * (_outerV + _frameInset + _contentPad) -
            _footerHeight) *
        _safety;
    final scaler = MediaQuery.textScalerOf(context);

    _pages = MushafPaginator.paginate(
      text: _text,
      buildSpan: (s, e) => _span(context, s, e),
      markerSize: _rosetteSize,
      width: width,
      pageHeight: pageHeight,
      firstPageHeight: pageHeight - _headerHeight(context, width, scaler),
      textScaler: scaler,
    );

    final target = MushafPaginator.pageOf(_pages, _anchorWord);
    final old = _controller;
    _controller = PageController(initialPage: target);
    if (old != null) {
      // Disposing mid-build would tear down a controller still attached to
      // the PageView being replaced.
      WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
    }

    if (!_announcedResume && target > 0) {
      _announcedResume = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            // A snackbar with an action otherwise stays until dismissed.
            persist: false,
            duration: const Duration(seconds: 5),
            content: Text(context.l10n.resumedAtPage(target + 1)),
            action: SnackBarAction(
              label: context.l10n.startFromBeginning,
              onPressed: () => _controller?.jumpToPage(0),
            ),
          ),
        );
      });
    }
  }

  void _onPageChanged(int page) {
    if (page < 0 || page >= _pages.length) return;
    _anchorWord = _pages[page].start;
    LocalStorageServices.setInt(
      PrefsKeys.suraWord(widget.sura.suraID),
      _anchorWord,
    );
    // The verse is kept too, for the "Continue reading" card.
    LocalStorageServices.setInt(
      PrefsKeys.suraPosition(widget.sura.suraID),
      _text.verseOfWord[_anchorWord],
    );
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (widget.verses.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        _paginate(context, constraints);
        final current = MushafPaginator.pageOf(_pages, _anchorWord);

        return Column(
          children: [
            Expanded(
              // A mushaf opens right-to-left: the next page lies to the left,
              // whatever language the app is in. PageView flips its axis with
              // the ambient direction, so pinning RTL here (rather than
              // `reverse: true`, which the Arabic UI's RTL cancelled back out)
              // gives the same direction in both languages.
              child: Directionality(
                textDirection: TextDirection.rtl,
                child: PageView.builder(
                  controller: _controller,
                  itemCount: _pages.length,
                  onPageChanged: _onPageChanged,
                  itemBuilder: (context, index) => _PageFrame(
                    pageNumber: index + 1,
                    topLabel: _pageStrip(context, index),
                    isSavedPage: index == current,
                    pageLabel: _arabicDigits(index + 1),
                    header: index == 0
                        ? _SuraHeader(
                            sura: widget.sura,
                            body: _bodyStyle(context),
                          )
                        : null,
                    child: Text.rich(
                      _span(
                        context,
                        _pages[index].start,
                        _pages[index].end,
                        live: true,
                      ),
                      textAlign: TextAlign.justify,
                      textDirection: TextDirection.rtl,
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(
              height: _labelHeight,
              child: Center(
                child: Text(
                  context.l10n.pageOf(current + 1, _pages.length),
                  style: context.texts.labelMedium?.copyWith(
                    color: context.colors.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

@immutable
class _PaginationKey {
  const _PaginationKey(this.width, this.height, this.scale, this.count);

  final double width;
  final double height;
  final double scale;
  final int count;

  @override
  bool operator ==(Object other) =>
      other is _PaginationKey &&
      other.width == width &&
      other.height == height &&
      other.scale == scale &&
      other.count == count;

  @override
  int get hashCode => Object.hash(width, height, scale, count);
}

/// One framed page: double border, corner flourishes, page number at the foot.
class _PageFrame extends StatelessWidget {
  const _PageFrame({
    required this.pageNumber,
    this.topLabel,
    required this.pageLabel,
    required this.isSavedPage,
    required this.child,
    this.header,
  });

  final int pageNumber;
  final String? topLabel;
  final String pageLabel;
  final bool isSavedPage;
  final Widget? header;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final extras = context.sakina;
    final scheme = context.colors;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: _MushafPageStateConsts.outerH,
        vertical: _MushafPageStateConsts.outerV,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: extras.versePanel,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: scheme.primary, width: 2),
        ),
        padding: const EdgeInsets.all(5),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(color: scheme.primary.withValues(alpha: 0.45)),
          ),
          child: Stack(
            children: [
              const PositionedDirectional(
                top: 0,
                start: 0,
                child: _Corner(asset: Assets.vectorLeft),
              ),
              const PositionedDirectional(
                top: 0,
                end: 0,
                child: _Corner(asset: Assets.vectorRight),
              ),
              if (isSavedPage)
                PositionedDirectional(
                  top: 0,
                  end: 28,
                  child: Tooltip(
                    message: context.l10n.bookmarkedPage,
                    child: Icon(
                      Icons.bookmark,
                      color: scheme.primary,
                      size: 28,
                    ),
                  ),
                ),
              Column(
                children: [
                  SizedBox(
                    height: _MushafPageStateConsts.stripHeight,
                    child: Center(
                      child: Text(
                        topLabel ?? '',
                        style: context.texts.labelSmall?.copyWith(
                          color: scheme.primary.withValues(alpha: 0.8),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      // Only scrolls if a single verse is taller than a page;
                      // otherwise the content already fits.
                      physics: const ClampingScrollPhysics(),
                      padding: const EdgeInsets.all(
                        _MushafPageStateConsts.contentPad,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [?header, child],
                      ),
                    ),
                  ),
                  SizedBox(
                    height: _MushafPageStateConsts.footerHeight,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                          border: Border.all(
                            color: scheme.primary.withValues(alpha: 0.5),
                          ),
                        ),
                        child: Text(
                          pageLabel,
                          style: context.texts.labelLarge?.copyWith(
                            color: scheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Mirrors the private layout constants so the frame widget can use them.
abstract final class _MushafPageStateConsts {
  static const double outerH = _MushafPageState._outerH;
  static const double outerV = _MushafPageState._outerV;
  static const double contentPad = _MushafPageState._contentPad;
  static const double footerHeight = _MushafPageState._footerHeight;
  static const double stripHeight = _MushafPageState._stripHeight;
}

class _SuraHeader extends StatelessWidget {
  const _SuraHeader({required this.sura, required this.body});

  final SuraDataModel sura;
  final TextStyle body;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.sm,
            horizontal: AppSpacing.lg,
          ),
          decoration: BoxDecoration(
            color: scheme.primary.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(color: scheme.primary.withValues(alpha: 0.5)),
          ),
          child: Column(
            children: [
              Text(
                'سُورَةُ ${sura.suraNameAR}',
                textDirection: TextDirection.rtl,
                style: context.texts.titleLarge?.copyWith(
                  color: scheme.primary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${sura.suraNameEN} · ${sura.suraVersesNumber}',
                style: context.texts.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        if (MushafPage.showsBasmala(sura.suraID)) ...[
          const SizedBox(height: AppSpacing.lg),
          Text(
            MushafPage.basmala,
            textAlign: TextAlign.center,
            textDirection: TextDirection.rtl,
            style: body.copyWith(
              color: scheme.primary,
              fontWeight: FontWeight.w700,
              height: 1.8,
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }
}

class _Corner extends StatelessWidget {
  const _Corner({required this.asset});

  final String asset;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.35,
      child: ColorFiltered(
        colorFilter: ColorFilter.mode(context.colors.primary, BlendMode.srcIn),
        child: Image.asset(asset, width: 56, excludeFromSemantics: true),
      ),
    );
  }
}

/// The numbered rosette that closes each verse.
class _VerseRosette extends StatelessWidget {
  const _VerseRosette({
    required this.label,
    required this.size,
    this.filled = false,
  });

  final String label;
  final double size;

  /// Filled for a bookmarked verse.
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: filled ? scheme.primary : scheme.primary.withValues(alpha: 0.12),
        border: Border.all(color: scheme.primary, width: 1.2),
      ),
      child: Text(
        label,
        textDirection: TextDirection.rtl,
        style: TextStyle(
          fontFamily: 'Janna',
          fontSize: size * 0.42,
          fontWeight: FontWeight.w700,
          color: filled ? scheme.onPrimary : scheme.primary,
          height: 1,
        ),
      ),
    );
  }
}
