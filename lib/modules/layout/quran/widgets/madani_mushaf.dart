import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/services/mushaf_layout.dart';
import '../../../../core/services/quran_meta.dart';
import '../../../../core/services/quran_service.dart';
import '../../../../core/state/settings_cubit.dart';
import '../../../../core/state/settings_state.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/utils/arabic_text.dart';

/// The 604-page Madinah mushaf, turned page by page like the printed copy.
///
/// Every page holds exactly the lines of the print, so each one starts and
/// ends on the same word as the mushaf on the reader's shelf. Text cannot be
/// enlarged here, since that would break the lines; the flowing view in
/// MushafPage is for that.
class MadaniMushaf extends StatefulWidget {
  const MadaniMushaf({
    super.key,
    required this.layout,
    required this.initialPage,
    this.onPageChanged,
    this.onVerseTap,
    this.highlight,
    this.isBookmarked,
    this.verseTint,
    this.onTapPage,
  });

  final MushafLayout layout;

  /// 1-based.
  final int initialPage;

  /// The page now on screen and, in a two-page spread, the page facing it.
  final void Function(int page, int? facing)? onPageChanged;
  final ValueChanged<VerseRef>? onVerseTap;

  /// The verse being recited. Highlighted, and followed onto its page.
  final VerseRef? highlight;
  final bool Function(VerseRef verse)? isBookmarked;

  /// The highlighter colour the reader gave a verse, if any.
  final Color? Function(VerseRef verse)? verseTint;

  /// A tap on the page outside any word, e.g. to hide the app's bars.
  final VoidCallback? onTapPage;

  @override
  State<MadaniMushaf> createState() => MadaniMushafState();
}

class MadaniMushafState extends State<MadaniMushaf> {
  /// Two facing pages, like an open book, when the screen is wide enough.
  static bool showsSpread(Size size) =>
      size.width > size.height && size.width >= 640;

  /// The page on screen (the right-hand one of a spread), 1-based.
  late int _current = widget.initialPage.clamp(1, MushafLayout.pageCount);

  PageController? _controller;
  bool? _spread;

  /// Words of each verse, per sura, once the sura's text has loaded.
  final Map<int, List<List<String>>> _words = {};
  final Set<int> _loading = {};

  /// The PageView index of [page]: spreads pair 1-2, 3-4 and so on, with the
  /// odd page on the right as in the print.
  int _indexOf(int page) => _spread! ? (page - 1) ~/ 2 : page - 1;

  @override
  void didUpdateWidget(MadaniMushaf oldWidget) {
    super.didUpdateWidget(oldWidget);
    final verse = widget.highlight;
    if (verse != null && verse != oldWidget.highlight) _follow(verse);
  }

  void _follow(VerseRef verse) {
    final controller = _controller;
    if (controller == null || !controller.hasClients) return;
    final target = _indexOf(widget.layout.pageOf(verse));
    if ((controller.page ?? 0).round() == target) return;
    controller.animateToPage(
      target,
      duration: AppDurations.slow,
      curve: Curves.easeInOut,
    );
  }

  /// Turns straight to [page] (1-based).
  void goTo(int page) {
    final controller = _controller;
    if (controller != null && controller.hasClients) {
      controller.jumpToPage(_indexOf(page.clamp(1, MushafLayout.pageCount)));
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _onIndexChanged(int index) {
    final page = _spread! ? index * 2 + 1 : index + 1;
    _current = page;
    widget.onPageChanged?.call(
      page,
      _spread! && page < MushafLayout.pageCount ? page + 1 : null,
    );
  }

  /// The words of every sura on [page], or null while any is still loading.
  Map<int, List<List<String>>>? _textFor(int page) {
    final suras = widget.layout.surasOn(page);
    final missing = suras.where((s) => !_words.containsKey(s)).toList();
    for (final s in missing) {
      _load(s);
    }
    // The neighbours too, so turning the page never shows a blank sheet.
    for (final p in [page - 1, page + 1]) {
      if (p < 1 || p > MushafLayout.pageCount) continue;
      for (final s in widget.layout.surasOn(p)) {
        if (!_words.containsKey(s)) _load(s);
      }
    }
    return missing.isEmpty ? _words : null;
  }

  Future<void> _load(int sura) async {
    if (!_loading.add(sura)) return;
    final verses = await QuranService.loadSura('$sura');
    if (!mounted) return;
    setState(() {
      _words[sura] = [
        for (var a = 0; a < verses.length; a++)
          widget.layout.wordsOf(VerseRef(sura, a + 1), verses[a]),
      ];
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final spread = showsSpread(box.biggest);
        if (spread != _spread) {
          // Turning the phone keeps the same page in view.
          final old = _controller;
          _spread = spread;
          _controller = PageController(initialPage: _indexOf(_current));
          if (old != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
          }
        }

        // A mushaf opens right-to-left whatever language the app is in: the
        // next page lies to the left.
        return Directionality(
          textDirection: TextDirection.rtl,
          child: PageView.builder(
            key: ValueKey(spread),
            controller: _controller,
            itemCount: spread
                ? (MushafLayout.pageCount + 1) ~/ 2
                : MushafLayout.pageCount,
            onPageChanged: _onIndexChanged,
            itemBuilder: (context, i) => GestureDetector(
              onTap: widget.onTapPage,
              child: spread
                  ? Row(
                      children: [
                        Expanded(child: _sheet(i * 2 + 1)),
                        // The binding between the two pages.
                        Container(
                          width: 2,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.black.withValues(alpha: 0.18),
                                Colors.black.withValues(alpha: 0.02),
                              ],
                            ),
                          ),
                        ),
                        Expanded(child: _sheet(i * 2 + 2)),
                      ],
                    )
                  : _sheet(i + 1),
            ),
          ),
        );
      },
    );
  }

  Widget _sheet(int page) {
    if (page > MushafLayout.pageCount) return const SizedBox.shrink();
    return MushafSheet(
      layout: widget.layout,
      page: page,
      words: _textFor(page),
      highlight: widget.highlight,
      isBookmarked: widget.isBookmarked,
      verseTint: widget.verseTint,
      onVerseTap: widget.onVerseTap,
    );
  }
}

/// The colours of the printed page, for day and night.
@immutable
class _Paper {
  const _Paper({
    required this.paper,
    required this.ink,
    required this.frame,
    required this.accent,
  });

  final Color paper;
  final Color ink;

  /// The ruled frame round the text and the sura title boxes.
  final Color frame;

  /// Verse rosettes and margin marks.
  final Color accent;

  static const _cream = _Paper(
    paper: Color(0xFFFFFBF0),
    ink: Color(0xFF1F1B14),
    frame: Color(0xFF2E6B4A),
    accent: Color(0xFF9A6B1F),
  );
  static const _white = _Paper(
    paper: Color(0xFFFFFFFF),
    ink: Color(0xFF141414),
    frame: Color(0xFF2E6B4A),
    accent: Color(0xFF9A6B1F),
  );
  static const _sepia = _Paper(
    paper: Color(0xFFF3E7CF),
    ink: Color(0xFF3A2E1F),
    frame: Color(0xFF7A5A30),
    accent: Color(0xFF8A561B),
  );
  static const _night = _Paper(
    paper: Color(0xFF1C1B17),
    ink: Color(0xFFEDE6D3),
    frame: Color(0xFF7FA88A),
    accent: Color(0xFFD9B26A),
  );

  /// The reader's chosen paper; "auto" is cream by day and dark at night,
  /// following the app's theme.
  static _Paper of(BuildContext context) {
    final choice = context.select<SettingsCubit, MushafPaper>((c) => c.state.mushafPaper);
    return switch (choice) {
      MushafPaper.white => _white,
      MushafPaper.sepia => _sepia,
      MushafPaper.night => _night,
      MushafPaper.auto => Theme.of(context).brightness == Brightness.dark ? _night : _cream,
    };
  }
}

/// One printed page: running heads, a ruled frame holding its fifteen lines,
/// margin marks where a hizb quarter begins, and the page number at the foot.
class MushafSheet extends StatelessWidget {
  const MushafSheet({
    super.key,
    required this.layout,
    required this.page,
    required this.words,
    this.highlight,
    this.isBookmarked,
    this.verseTint,
    this.onVerseTap,
  });

  final MushafLayout layout;
  final int page;

  /// Null while the text is loading.
  final Map<int, List<List<String>>>? words;
  final VerseRef? highlight;
  final bool Function(VerseRef verse)? isBookmarked;

  /// The highlighter colour the reader gave a verse, if any.
  final Color? Function(VerseRef verse)? verseTint;
  final ValueChanged<VerseRef>? onVerseTap;

  /// Width of a typical full line in em of Amiri Quran: wide enough for 98% of
  /// the 8,807 lines of pages 3-604 at the gap used here, measured with
  /// HarfBuzz (the shaper Flutter uses). Wider lines shrink to fit; narrower
  /// ones are spread out, as the print stretches them.
  static const double lineEm = 21;

  static const String basmala = 'بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ';

  static const List<String> _juzNames = [
    'الأول',
    'الثاني',
    'الثالث',
    'الرابع',
    'الخامس',
    'السادس',
    'السابع',
    'الثامن',
    'التاسع',
    'العاشر',
    'الحادي عشر',
    'الثاني عشر',
    'الثالث عشر',
    'الرابع عشر',
    'الخامس عشر',
    'السادس عشر',
    'السابع عشر',
    'الثامن عشر',
    'التاسع عشر',
    'العشرون',
    'الحادي والعشرون',
    'الثاني والعشرون',
    'الثالث والعشرون',
    'الرابع والعشرون',
    'الخامس والعشرون',
    'السادس والعشرون',
    'السابع والعشرون',
    'الثامن والعشرون',
    'التاسع والعشرون',
    'الثلاثون',
  ];

  /// "الجزء السابع والعشرون".
  static String juzName(int juz) => 'الجزء ${_juzNames[juz - 1]}';

  /// For each line of [page] on which a hizb quarter begins, the quarter.
  static Map<int, int> quarterMarks(
    MushafLayout layout,
    QuranMeta meta,
    int page,
  ) {
    final lines = layout.page(page);
    final marks = <int, int>{};
    for (var q = 0; q < meta.hizbStarts.length; q++) {
      final v = meta.hizbStarts[q];
      // The first quarter of every juz is marked by the juz itself.
      if (q == 0 || layout.pageOf(v) != page) continue;
      final first = WordRef(v.sura, v.ayah, 1);
      final line = lines.indexWhere((l) => l.holds(first));
      if (line >= 0) marks[line] = q + 1;
    }
    return marks;
  }

  @override
  Widget build(BuildContext context) {
    final paper = _Paper.of(context);
    final meta = QuranMeta.instance;
    final lines = layout.page(page);
    final lastText = lines.lastWhere((l) => l.kind == MushafLineKind.text);
    final firstWord = layout.firstWord(page);
    final head = TextStyle(
      fontFamily: 'Janna',
      fontSize: 12,
      color: paper.frame,
      height: 1.2,
    );
    final marks = meta == null
        ? const <int, int>{}
        : quarterMarks(layout, meta, page);
    // Odd pages are right-hand pages; their outer margin is on the left.
    final outerIsLeft = page.isOdd;

    return ColoredBox(
      color: paper.paper,
      child: SafeArea(
        top: false,
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            6,
            AppSpacing.sm,
            6,
            AppSpacing.xs,
          ),
          child: Column(
            children: [
              // Running heads: juz on the right, sura on the left.
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Row(
                  textDirection: TextDirection.rtl,
                  children: [
                    if (meta != null)
                      Text(juzName(meta.juzOf(firstWord.verse)), style: head),
                    const Spacer(),
                    if (meta != null)
                      Text(
                        'سورة ${_plainName(meta.sura(lastText.sura).nameAr)}',
                        style: head,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Expanded(
                child: Row(
                  textDirection: TextDirection.ltr,
                  children: [
                    _Margin(
                      show: outerIsLeft,
                      marks: marks,
                      lineCount: lines.length,
                      paper: paper,
                    ),
                    Expanded(
                      child: _Frame(
                        color: paper.frame,
                        child: words == null
                            ? Center(
                                child: CircularProgressIndicator(
                                  color: paper.frame,
                                ),
                              )
                            : _Lines(
                                layout: layout,
                                page: page,
                                lines: lines,
                                words: words!,
                                paper: paper,
                                highlight: highlight,
                                isBookmarked: isBookmarked,
                                verseTint: verseTint,
                                onVerseTap: onVerseTap,
                              ),
                      ),
                    ),
                    _Margin(
                      show: !outerIsLeft,
                      marks: marks,
                      lineCount: lines.length,
                      paper: paper,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              _PageNumber(page: page, paper: paper),
            ],
          ),
        ),
      ),
    );
  }

  /// "ٱلرَّحْمَٰنِ" to "الرحمن" for the running head, which the print sets
  /// without vowels.
  static String _plainName(String name) => String.fromCharCodes([
    for (final c in name.runes)
      if (!(c >= 0x064B && c <= 0x065F) &&
          c != 0x0670 &&
          !(c >= 0x06D6 && c <= 0x06ED))
        c == 0x0671 ? 0x0627 : c,
  ]);
}

/// The double rule round the text block.
class _Frame extends StatelessWidget {
  const _Frame({required this.color, required this.child});

  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(border: Border.all(color: color, width: 1.6)),
      padding: const EdgeInsets.all(2),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: color.withValues(alpha: 0.55), width: 0.8),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: child,
      ),
    );
  }
}

/// The outer margin, where the start of each hizb quarter is marked.
class _Margin extends StatelessWidget {
  const _Margin({
    required this.show,
    required this.marks,
    required this.lineCount,
    required this.paper,
  });

  final bool show;
  final Map<int, int> marks;
  final int lineCount;
  final _Paper paper;

  static const double width = 22;

  @override
  Widget build(BuildContext context) {
    if (!show || marks.isEmpty) return const SizedBox(width: width);
    return SizedBox(
      width: width,
      child: Padding(
        // Matches the frame's rules and padding, so marks sit level with lines.
        padding: const EdgeInsets.symmetric(vertical: 1.6 + 2 + 0.8 + 6),
        child: Column(
          children: [
            for (var i = 0; i < lineCount; i++)
              Expanded(
                child: marks[i] == null
                    ? const SizedBox()
                    : _QuarterMark(quarter: marks[i]!, paper: paper),
              ),
          ],
        ),
      ),
    );
  }
}

class _QuarterMark extends StatelessWidget {
  const _QuarterMark({required this.quarter, required this.paper});

  /// 1..240.
  final int quarter;
  final _Paper paper;

  @override
  Widget build(BuildContext context) {
    final hizb = (quarter - 1) ~/ 4 + 1;
    final part = const ['', '¼', '½', '¾'][(quarter - 1) % 4];
    final style = TextStyle(
      fontFamily: 'Janna',
      fontSize: 8,
      height: 1.1,
      color: paper.accent,
      fontWeight: FontWeight.w700,
    );
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: paper.accent, width: 0.8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              part.isEmpty ? 'الحزب' : part,
              style: style,
              textDirection: TextDirection.rtl,
            ),
            Text(
              ArabicText.digits(hizb),
              style: style,
              textDirection: TextDirection.rtl,
            ),
          ],
        ),
      ),
    );
  }
}

class _PageNumber extends StatelessWidget {
  const _PageNumber({required this.page, required this.paper});

  final int page;
  final _Paper paper;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 1,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(
          color: paper.frame.withValues(alpha: 0.7),
          width: 0.8,
        ),
      ),
      child: Text(
        ArabicText.digits(page),
        textDirection: TextDirection.rtl,
        style: TextStyle(
          fontFamily: 'Janna',
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: paper.frame,
          height: 1.3,
        ),
      ),
    );
  }
}

/// The lines of a page, sized so a typical line exactly fills the width.
class _Lines extends StatelessWidget {
  const _Lines({
    required this.layout,
    required this.page,
    required this.lines,
    required this.words,
    required this.paper,
    this.highlight,
    this.isBookmarked,
    this.verseTint,
    this.onVerseTap,
  });

  final MushafLayout layout;
  final int page;
  final List<MushafLine> lines;
  final Map<int, List<List<String>>> words;
  final _Paper paper;
  final VerseRef? highlight;
  final bool Function(VerseRef verse)? isBookmarked;

  /// The highlighter colour the reader gave a verse, if any.
  final Color? Function(VerseRef verse)? verseTint;
  final ValueChanged<VerseRef>? onVerseTap;

  /// Al-Fatiha and the opening of Al-Baqarah are set as short centred lines.
  bool get _opening => page <= 2;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        // The opening pages' 8 lines are spaced as if there were 15, in the
        // middle of the frame, as printed.
        const slots = 15;
        final lineHeight = box.maxHeight / slots;
        final fontSize = [
          box.maxWidth / MushafSheet.lineEm,
          lineHeight / 1.95,
        ].reduce((a, b) => a < b ? a : b);
        final style = TextStyle(
          fontFamily: 'AmiriQuran',
          fontSize: fontSize,
          height: 1.0,
          color: paper.ink,
        );

        final children = [
          for (final line in lines)
            SizedBox(
              height: lineHeight,
              child: switch (line.kind) {
                MushafLineKind.suraTitle => _SuraTitle(
                  sura: line.sura,
                  style: style,
                  paper: paper,
                ),
                MushafLineKind.basmala => Center(
                  child: Text(
                    MushafSheet.basmala,
                    style: style,
                    textDirection: TextDirection.rtl,
                  ),
                ),
                MushafLineKind.text => _TextLine(
                  items: _items(line),
                  style: style,
                  width: box.maxWidth,
                  center: _opening,
                  paper: paper,
                  highlight: highlight,
                  onVerseTap: onVerseTap,
                ),
              },
            ),
        ];

        return Column(
          mainAxisAlignment: _opening
              ? MainAxisAlignment.center
              : MainAxisAlignment.start,
          children: children,
        );
      },
    );
  }

  /// The words of [line], each verse closed by its numbered rosette.
  List<_Item> _items(MushafLine line) {
    final items = <_Item>[];
    var w = line.first!;
    while (true) {
      final verseWords = words[w.sura]![w.ayah - 1];
      final tint = verseTint?.call(w.verse);
      items.add(_Item(verseWords[w.word - 1], w.verse, tint: tint));
      final endsVerse = w.word == verseWords.length;
      if (endsVerse) {
        items.add(
          _Item(
            // U+06DD ARABIC END OF AYAH: Amiri Quran draws it round the digits.
            '۝${ArabicText.digits(w.ayah)}',
            w.verse,
            rosette: true,
            bookmarked: isBookmarked?.call(w.verse) ?? false,
            tint: tint,
          ),
        );
      }
      if (w == line.last) break;
      w = endsVerse
          ? (w.ayah < words[w.sura]!.length
                ? WordRef(w.sura, w.ayah + 1, 1)
                : WordRef(w.sura + 1, 1, 1))
          : WordRef(w.sura, w.ayah, w.word + 1);
    }
    return items;
  }
}

@immutable
class _Item {
  const _Item(
    this.text,
    this.verse, {
    this.rosette = false,
    this.bookmarked = false,
    this.tint,
  });

  final String text;
  final VerseRef verse;
  final bool rosette;
  final bool bookmarked;
  final Color? tint;
}

/// One line of words, justified edge to edge like the print.
class _TextLine extends StatelessWidget {
  const _TextLine({
    required this.items,
    required this.style,
    required this.width,
    required this.center,
    required this.paper,
    this.highlight,
    this.onVerseTap,
  });

  final List<_Item> items;
  final TextStyle style;
  final double width;
  final bool center;
  final _Paper paper;
  final VerseRef? highlight;
  final ValueChanged<VerseRef>? onVerseTap;

  /// A line shorter than this share of the width is centred rather than
  /// stretched, which would leave words stranded far apart.
  static const double _stretchFrom = 0.5;

  @override
  Widget build(BuildContext context) {
    final gap = style.fontSize! * 0.25;
    final natural = (TextPainter(
      text: TextSpan(text: items.map((i) => i.text).join(' '), style: style),
      textDirection: TextDirection.rtl,
      textScaler: TextScaler.noScaling,
    )..layout()).width;

    final cells = [for (final item in items) _cell(context, item)];
    Widget spaced(MainAxisSize size) => Row(
      textDirection: TextDirection.rtl,
      mainAxisSize: size,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < cells.length; i++) ...[
          if (i > 0) SizedBox(width: gap),
          cells[i],
        ],
      ],
    );

    if (natural > width) {
      return FittedBox(fit: BoxFit.scaleDown, child: spaced(MainAxisSize.min));
    }
    if (center || natural < width * _stretchFrom) {
      return spaced(MainAxisSize.max);
    }
    return Row(
      textDirection: TextDirection.rtl,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: cells,
    );
  }

  Widget _cell(BuildContext context, _Item item) {
    final lit = item.verse == highlight;
    final text = Text(
      item.text,
      textDirection: TextDirection.rtl,
      textScaler: TextScaler.noScaling,
      maxLines: 1,
      softWrap: false,
      style: item.rosette
          ? style.copyWith(
              color: item.bookmarked ? context.colors.primary : paper.accent,
            )
          : style,
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onVerseTap == null ? null : () => onVerseTap!(item.verse),
      // The verse being recited outshines the reader's own highlight.
      child: lit || item.tint != null
          ? DecoratedBox(
              decoration: BoxDecoration(
                color: lit
                    ? context.colors.primary.withValues(alpha: 0.18)
                    : item.tint!.withValues(alpha: paper.paper.computeLuminance() < 0.3 ? 0.32 : 0.38),
                borderRadius: BorderRadius.circular(4),
              ),
              child: text,
            )
          : text,
    );
  }
}

/// The framed title that opens a sura.
class _SuraTitle extends StatelessWidget {
  const _SuraTitle({
    required this.sura,
    required this.style,
    required this.paper,
  });

  final int sura;
  final TextStyle style;
  final _Paper paper;

  @override
  Widget build(BuildContext context) {
    final meta = QuranMeta.instance;
    final name = meta == null ? '' : meta.sura(sura).nameAr;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: CustomPaint(
        painter: _TitleFramePainter(paper.frame, paper.accent),
        child: Center(
          child: Text(
            'سُورَةُ $name',
            textDirection: TextDirection.rtl,
            textScaler: TextScaler.noScaling,
            style: style.copyWith(
              color: paper.frame,
              fontSize: style.fontSize! * 0.95,
            ),
          ),
        ),
      ),
    );
  }
}

class _TitleFramePainter extends CustomPainter {
  _TitleFramePainter(this.frame, this.accent);

  final Color frame;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final outer = Paint()
      ..color = frame
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    final inner = Paint()
      ..color = frame.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7;
    final fill = Paint()..color = frame.withValues(alpha: 0.07);

    final r = Offset.zero & size;
    final h = size.height;
    // A long cartouche whose ends come to points, as on the printed page.
    Path cartouche(Rect b, double point) => Path()
      ..moveTo(b.left + point, b.top)
      ..lineTo(b.right - point, b.top)
      ..lineTo(b.right, b.center.dy)
      ..lineTo(b.right - point, b.bottom)
      ..lineTo(b.left + point, b.bottom)
      ..lineTo(b.left, b.center.dy)
      ..close();

    final body = r.deflate(1);
    canvas.drawPath(cartouche(body, h * 0.45), fill);
    canvas.drawPath(cartouche(body, h * 0.45), outer);
    canvas.drawPath(cartouche(body.deflate(3), h * 0.38), inner);

    // A rosette at each end.
    final dot = Paint()..color = accent;
    for (final x in [body.left + h * 0.9, body.right - h * 0.9]) {
      canvas.drawCircle(Offset(x, body.center.dy), h * 0.12, dot);
      canvas.drawCircle(
        Offset(x, body.center.dy),
        h * 0.22,
        Paint()
          ..color = accent
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8,
      );
    }
  }

  @override
  bool shouldRepaint(_TitleFramePainter oldDelegate) =>
      oldDelegate.frame != frame || oldDelegate.accent != accent;
}
