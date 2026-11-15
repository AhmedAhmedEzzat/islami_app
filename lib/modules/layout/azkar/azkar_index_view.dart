import 'package:material_ui/material_ui.dart';

import '../../../core/services/azkar_favourites.dart';
import '../../../core/services/azkar_progress.dart';
import '../../../core/services/azkar_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/arabic_text.dart';
import '../../../core/utils/l10n_ext.dart';
import '../../../models/zikr_model.dart';
import 'azkar_labels.dart';
import 'azkar_view.dart';

/// Every chapter of Hisn al-Muslim: the daily ones up front, the rest
/// searchable below.
class AzkarIndexView extends StatefulWidget {
  const AzkarIndexView({super.key, this.embedded = false});

  /// True when shown inside a tab, where the tab supplies the page chrome.
  final bool embedded;

  @override
  State<AzkarIndexView> createState() => _AzkarIndexViewState();
}

class _AzkarIndexViewState extends State<AzkarIndexView> {
  late final Future<List<AzkarChapter>> _chapters = AzkarService.loadAll();
  String _query = '';

  void _open(AzkarChapter c) => _openId(c.id);

  void _openId(int id) => Navigator.push(
    context,
    MaterialPageRoute<void>(builder: (_) => AzkarView(chapterId: id)),
  );

  @override
  Widget build(BuildContext context) {
    final body = FutureBuilder<List<AzkarChapter>>(
      future: _chapters,
      builder: (context, snap) {
        final all = snap.data;
        if (all == null) {
          return const Center(child: CircularProgressIndicator());
        }
        // Redrawn when a chapter is counted through or a favourite changes,
        // which happens on the chapter's own screen, over this one.
        return ListenableBuilder(
          listenable: Listenable.merge([
            AzkarProgress.changes,
            AzkarFavourites.notifier,
          ]),
          builder: (context, _) => _content(all),
        );
      },
    );
    if (widget.embedded) return body;
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.hisnTitle)),
      body: body,
    );
  }

  Widget _content(List<AzkarChapter> all) {
    final l10n = context.l10n;
    final scheme = context.colors;
    final byId = {for (final c in all) c.id: c};
    final featured = [for (final id in FeaturedAzkar.all) ?byId[id]];

    final q = ArabicText.normalizeForSearch(_query);
    final filtered = q.isEmpty
        ? all
        : all.where((c) {
            return ArabicText.normalizeForSearch(c.title).contains(q) ||
                azkarTitle(
                  context,
                  c,
                ).toLowerCase().contains(_query.toLowerCase()) ||
                c.items.any(
                  (z) => ArabicText.normalizeForSearch(z.text).contains(q),
                );
          }).toList();

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          sliver: SliverToBoxAdapter(
            child: SearchBar(
              hintText: l10n.searchAzkarHint,
              leading: const Icon(Icons.search),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
        ),
        if (q.isEmpty) ...[
          if (AzkarFavourites.notifier.value.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                0,
                AppSpacing.lg,
                AppSpacing.lg,
              ),
              sliver: SliverToBoxAdapter(
                child: Card(
                  color: scheme.surfaceContainer,
                  child: ListTile(
                    leading: Icon(Icons.favorite, color: scheme.error),
                    title: Text(l10n.favourites),
                    trailing: Text(
                      '${AzkarService.favourites(all, AzkarFavourites.notifier.value).items.length}',
                      style: context.texts.labelLarge?.copyWith(
                        color: scheme.primary,
                      ),
                    ),
                    onTap: () => _openId(AzkarService.favouritesId),
                  ),
                ),
              ),
            ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            sliver: SliverToBoxAdapter(
              child: Text(l10n.featuredAzkar, style: context.texts.titleMedium),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            sliver: SliverGrid(
              // Two lines of label: as tall as the phone's font size needs.
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: AppSpacing.sm,
                crossAxisSpacing: AppSpacing.sm,
                mainAxisExtent: 24 + MediaQuery.textScalerOf(context).scale(44),
              ),
              delegate: SliverChildListDelegate([
                for (final c in featured)
                  Card(
                    color: scheme.secondaryContainer,
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => _open(c),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                        ),
                        child: Row(
                          children: [
                            // A tick once it has been read through in this
                            // sitting; a ring while it is part-way.
                            _ChapterMark(
                              chapter: c,
                              color: scheme.onSecondaryContainer,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text(
                                azkarTitle(context, c),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: context.texts.labelLarge?.copyWith(
                                  color: scheme.onSecondaryContainer,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ]),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            sliver: SliverToBoxAdapter(
              child: Text(l10n.allChapters, style: context.texts.titleMedium),
            ),
          ),
        ],
        SliverList.separated(
          itemCount: filtered.length,
          separatorBuilder: (_, _) =>
              const Divider(height: 1, indent: 16, endIndent: 16),
          itemBuilder: (context, i) {
            final c = filtered[i];
            final title = azkarTitle(context, c);
            final done = AzkarProgress.fraction(c) == 1;
            return ListTile(
              title: Text(title),
              // In English the book's own Arabic title stays in view.
              subtitle: title == c.title
                  ? null
                  : Text(c.title, textDirection: TextDirection.rtl),
              trailing: done
                  ? Icon(
                      Icons.check_circle,
                      color: scheme.primary,
                      semanticLabel: l10n.azkarDone,
                    )
                  : Text(
                      '${c.items.length}',
                      style: context.texts.labelMedium?.copyWith(
                        color: scheme.primary,
                      ),
                    ),
              onTap: () => _open(c),
            );
          },
        ),
        const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xl)),
      ],
    );
  }
}

/// A featured chapter's icon, which becomes a tick once the chapter has been
/// read through in this sitting and wears a ring while it is part-way.
class _ChapterMark extends StatelessWidget {
  const _ChapterMark({required this.chapter, required this.color});

  final AzkarChapter chapter;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final fraction = AzkarProgress.fraction(chapter);
    if (fraction == 1) {
      return Icon(
        Icons.check_circle,
        color: color,
        semanticLabel: context.l10n.azkarDone,
      );
    }
    final icon = Icon(azkarIcon(chapter.id), color: color);
    if (fraction == 0) return icon;
    return Stack(
      alignment: Alignment.center,
      children: [
        SizedBox.square(
          dimension: 32,
          child: CircularProgressIndicator(
            value: fraction,
            strokeWidth: 2,
            color: color,
          ),
        ),
        Icon(azkarIcon(chapter.id), color: color, size: 18),
      ],
    );
  }
}
