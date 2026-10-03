import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/constants/assets.dart';
import '../../../core/constants/constants.dart';
import '../../../core/services/quran_meta.dart';
import '../../../core/services/recent_suras.dart';
import '../../../core/state/bookmarks_cubit.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/l10n_ext.dart';
import '../../../core/widgets/app_background.dart';
import '../../../models/quran_open_request.dart';
import '../../../models/sura_data_model.dart';
import '../../settings/settings_view.dart';
import 'quran_details_view.dart';
import 'quran_search_view.dart';
import 'widgets/recentily_sura_widget.dart';
import 'widgets/sura_list_widget.dart';

/// Opens [sura] in the Quran tab's own navigator, optionally at [ayah].
Future<void> openSura(BuildContext context, SuraDataModel sura, {int? ayah}) {
  RecentSuras.remember(sura);
  return Navigator.pushNamed(
    context,
    QuranDetailsView.routeName,
    arguments: QuranOpenRequest(sura, ayah: ayah),
  );
}

SuraDataModel suraByNumber(int n) => Constants.suraDataLists[n - 1];

String suraName(BuildContext context, int n) {
  final s = suraByNumber(n);
  return context.isArabic ? s.suraNameAR : s.suraNameEN;
}

class QuranView extends StatefulWidget {
  const QuranView({super.key});

  @override
  State<QuranView> createState() => _QuranViewState();
}

class _QuranViewState extends State<QuranView> {
  Future<void> _open(SuraDataModel sura, {int? ayah}) =>
      openSura(context, sura, ayah: ayah);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return AppBackground(
      ornament: Assets.quranBackground,
      title: l10n.quranTitle,
      actions: [
        IconButton(
          tooltip: l10n.searchTitle,
          icon: const Icon(Icons.search),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => QuranSearchView(onOpen: _open),
            ),
          ),
        ),
        IconButton(
          tooltip: l10n.settings,
          icon: const Icon(Icons.settings_outlined),
          // Root navigator: Settings is reachable from several tabs, so
          // nesting it would leave a copy in several back stacks.
          onPressed: () => Navigator.of(context, rootNavigator: true).push(
            MaterialPageRoute<void>(builder: (_) => const SettingsView()),
          ),
        ),
      ],
      child: DefaultTabController(
        length: 3,
        child: Column(
          children: [
            TabBar(
              tabs: [
                Tab(text: l10n.surasTab),
                Tab(text: l10n.juzTab),
                Tab(text: l10n.bookmarksTab),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  ValueListenableBuilder<List<SuraDataModel>>(
                    valueListenable: RecentSuras.notifier,
                    builder: (_, recent, _) =>
                        _SurasTab(recent: recent, onOpen: _open),
                  ),
                  _JuzTab(onOpen: _open),
                  _BookmarksTab(onOpen: _open),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

typedef _Open = Future<void> Function(SuraDataModel sura, {int? ayah});

class _SurasTab extends StatelessWidget {
  const _SurasTab({required this.recent, required this.onOpen});

  final List<SuraDataModel> recent;
  final _Open onOpen;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        if (recent.isNotEmpty) ...[
          const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.lg)),
          SliverToBoxAdapter(
            child: RecentlySuraWidget(
              suraDataModel: recent,
              onOpen: (s) => onOpen(s),
            ),
          ),
        ],
        const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.md)),
        SliverPadding(
          padding: const EdgeInsets.only(
            left: AppSpacing.sm,
            right: AppSpacing.sm,
            bottom: AppSpacing.xl,
          ),
          sliver: SuraListSliver(
            onSurahTap: (i) => onOpen(Constants.suraDataLists[i]),
            suraDataModels: Constants.suraDataLists,
          ),
        ),
      ],
    );
  }
}

/// The 30 juz, each opening onto its eight hizb quarters.
class _JuzTab extends StatelessWidget {
  const _JuzTab({required this.onOpen});

  final _Open onOpen;

  @override
  Widget build(BuildContext context) {
    final meta = QuranMeta.instance;
    if (meta == null) return const SizedBox.shrink();
    final l10n = context.l10n;
    final scheme = context.colors;

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      itemCount: meta.juzStarts.length,
      itemBuilder: (context, j) {
        final start = meta.juzStarts[j];
        final quarters = meta.hizbStarts.sublist(j * 8, j * 8 + 8);
        return ExpansionTile(
          leading: CircleAvatar(
            backgroundColor: scheme.secondaryContainer,
            foregroundColor: scheme.onSecondaryContainer,
            child: Text('${j + 1}'),
          ),
          title: Text(l10n.juzLabel(j + 1)),
          subtitle: Text(l10n.startsAt(suraName(context, start.sura), start.ayah)),
          trailing: IconButton(
            tooltip: l10n.openSura,
            icon: const Icon(Icons.menu_book_outlined),
            onPressed: () => onOpen(suraByNumber(start.sura), ayah: start.ayah),
          ),
          children: [
            for (var q = 0; q < quarters.length; q++)
              ListTile(
                dense: true,
                contentPadding: const EdgeInsetsDirectional.only(
                  start: 72,
                  end: AppSpacing.lg,
                ),
                title: Text(_quarterLabel(context, j * 8 + q)),
                subtitle: Text(
                  l10n.startsAt(suraName(context, quarters[q].sura), quarters[q].ayah),
                ),
                onTap: () => onOpen(
                  suraByNumber(quarters[q].sura),
                  ayah: quarters[q].ayah,
                ),
              ),
          ],
        );
      },
    );
  }

  /// Quarter index 0..239 → "Hizb 3", "¼ Hizb 3", "½ Hizb 3", "¾ Hizb 3".
  static String _quarterLabel(BuildContext context, int quarter) {
    final l10n = context.l10n;
    final hizb = quarter ~/ 4 + 1;
    return switch (quarter % 4) {
      0 => l10n.hizbStart(hizb),
      1 => l10n.hizbQuarter(hizb),
      2 => l10n.hizbHalf(hizb),
      _ => l10n.hizbThreeQuarters(hizb),
    };
  }
}

class _BookmarksTab extends StatelessWidget {
  const _BookmarksTab({required this.onOpen});

  final _Open onOpen;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<BookmarksCubit, List<Bookmark>>(
      builder: (context, bookmarks) {
        if (bookmarks.isEmpty) {
          return AppStateMessage(
            icon: Icons.bookmark_border,
            message: context.l10n.noBookmarks,
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.only(bottom: AppSpacing.xl),
          itemCount: bookmarks.length,
          separatorBuilder: (_, _) => const Divider(indent: 72),
          itemBuilder: (context, i) {
            final b = bookmarks[i];
            return Dismissible(
              key: ValueKey(b.verse.key),
              direction: DismissDirection.endToStart,
              background: Container(
                color: context.colors.errorContainer,
                alignment: AlignmentDirectional.centerEnd,
                padding: const EdgeInsetsDirectional.only(end: AppSpacing.xl),
                child: Icon(Icons.delete_outline, color: context.colors.onErrorContainer),
              ),
              onDismissed: (_) => context.read<BookmarksCubit>().toggle(b.verse),
              child: ListTile(
                leading: Icon(Icons.bookmark, color: context.colors.primary),
                title: Text(
                  context.l10n.verseRef(suraName(context, b.verse.sura), b.verse.ayah),
                ),
                subtitle: Text(
                  MaterialLocalizations.of(context).formatMediumDate(b.savedAt),
                ),
                onTap: () => onOpen(suraByNumber(b.verse.sura), ayah: b.verse.ayah),
              ),
            );
          },
        );
      },
    );
  }
}
