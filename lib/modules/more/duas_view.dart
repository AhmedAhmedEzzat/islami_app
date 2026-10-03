import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/constants/quran_duas.dart';
import '../../core/services/quran_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/l10n_ext.dart';
import '../../models/quran_open_request.dart';
import '../layout/quran/quran_details_view.dart';
import '../layout/quran/quran_view.dart' show suraByNumber, suraName;

/// Supplications from the Quran, read straight from the mushaf text.
class DuasView extends StatelessWidget {
  const DuasView({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.duasTitle),
          bottom: TabBar(
            tabs: [
              Tab(text: l10n.rabbanaGroup),
              Tab(text: l10n.prophetsGroup),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _DuaList(duas: QuranDuas.rabbana),
            _DuaList(duas: QuranDuas.prophets),
          ],
        ),
      ),
    );
  }
}

class _DuaList extends StatelessWidget {
  const _DuaList({required this.duas});

  final List<QuranDua> duas;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.lg),
      itemCount: duas.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
      itemBuilder: (context, i) => _DuaCard(dua: duas[i]),
    );
  }
}

class _DuaCard extends StatelessWidget {
  const _DuaCard({required this.dua});

  final QuranDua dua;

  Future<(String, String)> _load() async {
    final ar = await QuranService.loadSura('${dua.sura}');
    final en = await QuranService.loadTranslation('${dua.sura}');
    return (
      [for (var a = dua.from; a <= dua.to; a++) '${ar[a - 1]} ﴿$a﴾'].join(' '),
      [for (var a = dua.from; a <= dua.to; a++) en[a - 1]].join(' '),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final citation = '${suraName(context, dua.sura)} ${dua.label}';

    return Card(
      color: scheme.surfaceContainerLow,
      child: FutureBuilder<(String, String)>(
        future: _load(),
        builder: (context, snap) {
          final data = snap.data;
          if (data == null) {
            return const Padding(
              padding: EdgeInsets.all(AppSpacing.xl),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final (arabic, english) = data;
          return Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  arabic,
                  textDirection: TextDirection.rtl,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'AmiriQuran',
                    fontSize: 20,
                    height: 2.0,
                    color: context.sakina.verseText,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  english,
                  textDirection: TextDirection.ltr,
                  style: context.texts.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        citation,
                        style: context.texts.labelMedium?.copyWith(
                          color: scheme.primary,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: context.l10n.shareVerse,
                      icon: const Icon(Icons.share_outlined),
                      onPressed: () => SharePlus.instance.share(
                        ShareParams(text: '$arabic\n\n$english\n\n— $citation'),
                      ),
                    ),
                    IconButton(
                      tooltip: context.l10n.openSura,
                      icon: const Icon(Icons.menu_book_outlined),
                      onPressed: () => Navigator.pushNamed(
                        context,
                        QuranDetailsView.routeName,
                        arguments: QuranOpenRequest(
                          suraByNumber(dua.sura),
                          ayah: dua.from,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
