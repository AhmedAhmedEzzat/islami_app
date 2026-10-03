import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/services/quran_meta.dart';
import '../../../../core/services/quran_service.dart';
import '../../../../core/services/tafsir_service.dart';
import '../../../../core/state/bookmarks_cubit.dart';
import '../../../../core/state/quran_player_cubit.dart';
import '../../../../core/state/settings_cubit.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/utils/l10n_ext.dart';
import '../../../../models/sura_data_model.dart';
import 'verse_image_share.dart';

/// Everything you can do with one verse: read its translation and tafsir,
/// play from it, bookmark, copy or share it.
class VerseSheet extends StatefulWidget {
  const VerseSheet({
    super.key,
    required this.sura,
    required this.ayah,
    required this.text,
    this.scrollController,
  });

  final SuraDataModel sura;
  final ScrollController? scrollController;

  /// 1-based.
  final int ayah;
  final String text;

  static Future<void> show(
    BuildContext context, {
    required SuraDataModel sura,
    required int ayah,
    required String text,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        minChildSize: 0.35,
        maxChildSize: 0.95,
        builder: (context, controller) => VerseSheet(
          sura: sura,
          ayah: ayah,
          text: text,
          scrollController: controller,
        ),
      ),
    );
  }

  @override
  State<VerseSheet> createState() => _VerseSheetState();
}

class _VerseSheetState extends State<VerseSheet> {
  Tafsir _tafsir = Tafsir.muyassar;
  late Future<List<String>?> _tafsirFuture;
  late Future<List<String>> _translation;

  int get _suraNumber => int.parse(widget.sura.suraID);
  VerseRef get _ref => VerseRef(_suraNumber, widget.ayah);

  @override
  void initState() {
    super.initState();
    _translation = QuranService.loadTranslation(widget.sura.suraID);
    _tafsirFuture = TafsirService.forSura(_tafsir, _suraNumber);
  }

  void _selectTafsir(Tafsir t) {
    setState(() {
      _tafsir = t;
      _tafsirFuture = TafsirService.forSura(t, _suraNumber);
    });
  }

  String get _citation =>
      '${widget.sura.suraNameAR} (${widget.sura.suraNameEN}) ${widget.ayah}';

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final l10n = context.l10n;
    final meta = QuranMeta.instance;
    final isSajda = meta?.isSajda(_ref) ?? false;

    return ListView(
      controller: widget.scrollController,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.xxl,
      ),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.verseRef(
                  context.isArabic ? widget.sura.suraNameAR : widget.sura.suraNameEN,
                  widget.ayah,
                ),
                style: context.texts.titleMedium?.copyWith(color: scheme.primary),
              ),
            ),
            if (meta != null)
              Text(
                '${l10n.juzLabel(meta.juzOf(_ref))} · ${l10n.hizbLabel(meta.hizbOf(_ref))}',
                style: context.texts.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
        if (isSajda) ...[
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Chip(
              avatar: const Text('۩'),
              label: Text(l10n.sajdaVerse),
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: context.sakina.versePanel,
            borderRadius: AppRadius.cardRadius,
          ),
          child: Text(
            widget.text,
            textAlign: TextAlign.center,
            textDirection: TextDirection.rtl,
            style: TextStyle(
              fontFamily: 'AmiriQuran',
              fontSize: 22,
              height: 2.0,
              color: context.sakina.verseText,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        _Actions(
          onPlay: () {
            final total = int.tryParse(widget.sura.suraVersesNumber) ?? 0;
            context.read<QuranPlayerCubit>().playFrom(
              suraId: widget.sura.suraID,
              fromAyah: widget.ayah,
              totalAyahs: total,
              reciterId: context.read<SettingsCubit>().state.reciterId,
            );
            Navigator.pop(context);
          },
          isBookmarked: context.watch<BookmarksCubit>().isBookmarked(_ref),
          onBookmark: () async {
            final added = await context.read<BookmarksCubit>().toggle(_ref);
            if (!context.mounted || !added) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n.bookmarkAdded)),
            );
          },
          onCopy: () async {
            await Clipboard.setData(ClipboardData(text: '${widget.text}\n\n— $_citation'));
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n.copied)),
            );
          },
          onShare: () => SharePlus.instance.share(
            ShareParams(text: '${widget.text}\n\n— $_citation'),
          ),
          onShareImage: () => VerseImageShare.share(
            context,
            text: widget.text,
            citation: _citation,
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        _SectionTitle(l10n.translationTitle, subtitle: l10n.translationSource),
        FutureBuilder<List<String>>(
          future: _translation,
          builder: (context, snap) {
            final list = snap.data;
            if (list == null || widget.ayah > list.length) {
              return const _Loading();
            }
            return Text(
              list[widget.ayah - 1],
              textDirection: TextDirection.ltr,
              style: context.texts.bodyLarge?.copyWith(height: 1.6),
            );
          },
        ),
        const SizedBox(height: AppSpacing.xl),
        _SectionTitle(l10n.tafsirTitle),
        SegmentedButton<Tafsir>(
          segments: [
            ButtonSegment(value: Tafsir.muyassar, label: Text(l10n.tafsirMuyassar)),
            ButtonSegment(value: Tafsir.jalalayn, label: Text(l10n.tafsirJalalayn)),
          ],
          selected: {_tafsir},
          onSelectionChanged: (s) => _selectTafsir(s.first),
        ),
        const SizedBox(height: AppSpacing.md),
        FutureBuilder<List<String>?>(
          future: _tafsirFuture,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const _Loading();
            }
            final list = snap.data;
            if (list == null || widget.ayah > list.length) {
              return Text(
                l10n.tafsirUnavailable,
                style: context.texts.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              );
            }
            return Text(
              list[widget.ayah - 1],
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.justify,
              style: context.texts.bodyLarge?.copyWith(height: 1.9),
            );
          },
        ),
      ],
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({
    required this.onPlay,
    required this.isBookmarked,
    required this.onBookmark,
    required this.onCopy,
    required this.onShare,
    required this.onShareImage,
  });

  final VoidCallback onPlay;
  final bool isBookmarked;
  final VoidCallback onBookmark;
  final VoidCallback onCopy;
  final VoidCallback onShare;
  final VoidCallback onShareImage;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        FilledButton.icon(
          onPressed: onPlay,
          icon: const Icon(Icons.play_arrow),
          label: Text(l10n.playFromHere),
        ),
        OutlinedButton.icon(
          onPressed: onBookmark,
          icon: Icon(isBookmarked ? Icons.bookmark : Icons.bookmark_border),
          label: Text(isBookmarked ? l10n.removeBookmark : l10n.addBookmark),
        ),
        OutlinedButton.icon(
          onPressed: onCopy,
          icon: const Icon(Icons.copy),
          label: Text(l10n.copyVerse),
        ),
        OutlinedButton.icon(
          onPressed: onShare,
          icon: const Icon(Icons.share_outlined),
          label: Text(l10n.shareVerse),
        ),
        OutlinedButton.icon(
          onPressed: onShareImage,
          icon: const Icon(Icons.image_outlined),
          label: Text(l10n.shareAsImage),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title, {this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Text(
            title,
            style: context.texts.titleSmall?.copyWith(
              color: context.colors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(width: AppSpacing.sm),
            Flexible(
              child: Text(
                subtitle!,
                overflow: TextOverflow.ellipsis,
                style: context.texts.labelSmall?.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.all(AppSpacing.lg),
    child: Center(child: CircularProgressIndicator()),
  );
}
