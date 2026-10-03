import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/constants/constants.dart';
import '../../../core/services/quran_search_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/l10n_ext.dart';
import '../../../core/widgets/app_background.dart';
import '../../../models/sura_data_model.dart';
import 'quran_view.dart';

enum _Scope { suras, verses }

/// Search across sura names and the text of every verse.
class QuranSearchView extends StatefulWidget {
  const QuranSearchView({super.key, required this.onOpen});

  final Future<void> Function(SuraDataModel sura, {int? ayah}) onOpen;

  @override
  State<QuranSearchView> createState() => _QuranSearchViewState();
}

class _QuranSearchViewState extends State<QuranSearchView> {
  final TextEditingController _controller = TextEditingController();
  _Scope _scope = _Scope.verses;
  String _query = '';
  Timer? _debounce;
  List<QuranSearchHit> _hits = const [];
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    // Start building the index straight away, so the first search is quick.
    QuranSearchService.ensureIndex().then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    setState(() => _query = value);
    _debounce?.cancel();
    if (_scope == _Scope.verses) {
      // Wait for a pause in typing rather than searching on every key.
      _debounce = Timer(const Duration(milliseconds: 250), _runVerseSearch);
    }
  }

  Future<void> _runVerseSearch() async {
    final q = _query.trim();
    if (q.length < 2) {
      setState(() => _hits = const []);
      return;
    }
    setState(() => _searching = true);
    final hits = await QuranSearchService.search(q);
    if (!mounted || q != _query.trim()) return;
    setState(() {
      _hits = hits;
      _searching = false;
    });
  }

  List<SuraDataModel> get _suraMatches {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    return Constants.suraDataLists
        .where(
          (s) =>
              s.suraNameEN.toLowerCase().contains(q) ||
              s.suraNameAR.contains(_query.trim()) ||
              s.suraID == q,
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.searchTitle)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              AppSpacing.sm,
            ),
            child: SearchBar(
              controller: _controller,
              autoFocus: true,
              hintText: l10n.searchQuranHint,
              leading: const Icon(Icons.search),
              onChanged: _onChanged,
              trailing: [
                if (_query.isNotEmpty)
                  IconButton(
                    tooltip: l10n.clearSearch,
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _controller.clear();
                      _onChanged('');
                    },
                  ),
              ],
            ),
          ),
          SegmentedButton<_Scope>(
            segments: [
              ButtonSegment(value: _Scope.verses, label: Text(l10n.searchVerses)),
              ButtonSegment(value: _Scope.suras, label: Text(l10n.searchSuras)),
            ],
            selected: {_scope},
            onSelectionChanged: (s) {
              setState(() => _scope = s.first);
              if (_scope == _Scope.verses) _runVerseSearch();
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: _scope == _Scope.suras ? _buildSuras() : _buildVerses(),
          ),
        ],
      ),
    );
  }

  Widget _buildSuras() {
    final matches = _suraMatches;
    if (_query.trim().isEmpty) return const SizedBox.shrink();
    if (matches.isEmpty) {
      return AppStateMessage(
        icon: Icons.search_off,
        message: context.l10n.noSuraMatches(_query.trim()),
      );
    }
    return ListView.builder(
      itemCount: matches.length,
      itemBuilder: (context, i) {
        final s = matches[i];
        return ListTile(
          leading: CircleAvatar(child: Text(s.suraID)),
          title: Text(context.isArabic ? s.suraNameAR : s.suraNameEN),
          subtitle: Text(context.isArabic ? s.suraNameEN : s.suraNameAR),
          onTap: () => widget.onOpen(s),
        );
      },
    );
  }

  Widget _buildVerses() {
    final l10n = context.l10n;
    final scheme = context.colors;

    if (!QuranSearchService.isReady) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: AppSpacing.md),
            Text(l10n.searchPreparing),
          ],
        ),
      );
    }
    if (_query.trim().length < 2) {
      return AppStateMessage(icon: Icons.manage_search, message: l10n.searchMinChars);
    }
    if (_searching && _hits.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              l10n.searchResultCount(_hits.length),
              style: context.texts.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.only(bottom: AppSpacing.xl),
            itemCount: _hits.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final hit = _hits[i];
              return InkWell(
                onTap: () => widget.onOpen(suraByNumber(hit.ref.sura), ayah: hit.ref.ayah),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        l10n.verseRef(suraName(context, hit.ref.sura), hit.ref.ayah),
                        style: context.texts.labelLarge?.copyWith(color: scheme.primary),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        hit.arabic,
                        textDirection: TextDirection.rtl,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'AmiriQuran',
                          fontSize: 18,
                          height: 1.9,
                          color: scheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        hit.english,
                        textDirection: TextDirection.ltr,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: context.texts.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
