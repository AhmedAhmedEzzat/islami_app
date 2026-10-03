import 'package:flutter/material.dart';

import '../../../core/constants/assets.dart';
import '../../../core/services/hadeth_favourites.dart';
import '../../../core/services/hadeth_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/arabic_text.dart';
import '../../../core/utils/l10n_ext.dart';
import '../../../core/widgets/app_background.dart';
import '../../../models/hadeth_data_model.dart';
import 'hadeth_details_view.dart';

/// The bundled ahadeth: searchable, with favourites.
class HadethView extends StatefulWidget {
  const HadethView({super.key});

  @override
  State<HadethView> createState() => _HadethViewState();
}

class _HadethViewState extends State<HadethView> {
  List<HadethDataModel> _hadeth = [];
  bool _isLoading = true;
  bool _failed = false;
  String _query = '';
  bool _onlyFavourites = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _failed = false;
    });
    try {
      final hadeth = await HadethService.loadAll();
      if (!mounted) return;
      setState(() {
        _hadeth = hadeth;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _failed = true;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      ornament: Assets.hadethBackground,
      title: context.l10n.hadethTitle,
      child: _buildBody(),
    );
  }

  Widget _buildBody() {
    final l10n = context.l10n;
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_failed) {
      return AppStateMessage(icon: Icons.cloud_off, message: l10n.hadethLoadError, onRetry: _load);
    }
    if (_hadeth.isEmpty) {
      return AppStateMessage(icon: Icons.format_quote_outlined, message: l10n.noHadeth);
    }

    return ValueListenableBuilder<Set<int>>(
      valueListenable: HadethFavourites.notifier,
      builder: (context, favourites, _) {
        final q = ArabicText.normalizeForSearch(_query);
        final shown = _hadeth.where((h) {
          if (_onlyFavourites && !favourites.contains(h.number)) return false;
          if (q.isEmpty) return true;
          return ArabicText.normalizeForSearch(h.fullText).contains(q);
        }).toList();

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.sm),
              child: SearchBar(
                hintText: l10n.searchHadethHint,
                leading: const Icon(Icons.search),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: FilterChip(
                  avatar: const Icon(Icons.favorite, size: 18),
                  label: Text('${l10n.favourites} (${favourites.length})'),
                  selected: _onlyFavourites,
                  onSelected: (v) => setState(() => _onlyFavourites = v),
                ),
              ),
            ),
            Expanded(
              child: shown.isEmpty
                  ? AppStateMessage(
                      icon: _onlyFavourites ? Icons.favorite_border : Icons.search_off,
                      message: _onlyFavourites && q.isEmpty
                          ? l10n.noFavourites
                          : l10n.noHadethMatches,
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.xl),
                      itemCount: shown.length,
                      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
                      itemBuilder: (context, i) => _HadethTile(
                        hadeth: shown[i],
                        isFavourite: favourites.contains(shown[i].number),
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _HadethTile extends StatelessWidget {
  const _HadethTile({required this.hadeth, required this.isFavourite});

  final HadethDataModel hadeth;
  final bool isFavourite;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    return Card(
      color: scheme.surfaceContainerLow,
      child: InkWell(
        borderRadius: AppRadius.cardRadius,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute<void>(builder: (_) => HadethDetailsView(hadeth: hadeth)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: scheme.secondaryContainer,
                child: Text(
                  '${hadeth.number}',
                  style: context.texts.labelMedium?.copyWith(color: scheme.onSecondaryContainer),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      hadeth.title,
                      textDirection: TextDirection.rtl,
                      style: context.texts.titleMedium?.copyWith(color: scheme.primary),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      hadeth.content.join(' '),
                      textDirection: TextDirection.rtl,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: context.texts.bodyMedium?.copyWith(height: 1.7),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: isFavourite ? context.l10n.removeFavourite : context.l10n.addFavourite,
                icon: Icon(
                  isFavourite ? Icons.favorite : Icons.favorite_border,
                  color: isFavourite ? scheme.error : scheme.outline,
                ),
                onPressed: () => HadethFavourites.toggle(hadeth.number),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
