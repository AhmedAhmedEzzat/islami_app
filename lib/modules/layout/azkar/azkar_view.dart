import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/services/azkar_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/l10n_ext.dart';
import '../../../core/widgets/app_background.dart';
import '../../../models/zikr_model.dart';
import 'azkar_labels.dart';

/// Reads one Hisn al-Muslim chapter, counting each dhikr down to zero.
class AzkarView extends StatefulWidget {
  const AzkarView({super.key, required this.chapterId});

  final int chapterId;

  @override
  State<AzkarView> createState() => _AzkarViewState();
}

class _AzkarViewState extends State<AzkarView> {
  AzkarChapter? _chapter;
  final Map<int, int> _remaining = {};
  bool _isLoading = true;
  bool _failed = false;
  final ScrollController _scroll = ScrollController();
  final List<GlobalKey> _keys = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _failed = false;
    });
    try {
      final chapter = await AzkarService.chapter(widget.chapterId);
      if (!mounted) return;
      setState(() {
        _chapter = chapter;
        _failed = chapter == null;
        _isLoading = false;
        _reset();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _failed = true;
        _isLoading = false;
      });
    }
  }

  void _reset() {
    final chapter = _chapter;
    if (chapter == null) return;
    _remaining
      ..clear()
      ..addEntries(chapter.items.map((z) => MapEntry(z.id, z.count)));
    _keys
      ..clear()
      ..addAll(List.generate(chapter.items.length, (_) => GlobalKey()));
  }

  void _tap(int index) {
    final zikr = _chapter!.items[index];
    final left = _remaining[zikr.id] ?? 0;
    if (left == 0) return;
    setState(() => _remaining[zikr.id] = left - 1);
    if (left - 1 > 0) {
      HapticFeedback.selectionClick();
      return;
    }
    HapticFeedback.mediumImpact();
    // Finished this one: bring the next unfinished dhikr into view.
    for (var i = index + 1; i < _chapter!.items.length; i++) {
      if ((_remaining[_chapter!.items[i].id] ?? 0) > 0) {
        final ctx = _keys[i].currentContext;
        if (ctx != null) {
          Scrollable.ensureVisible(
            ctx,
            duration: AppDurations.slow,
            curve: Curves.easeInOut,
            alignment: 0.1,
          );
        }
        break;
      }
    }
  }

  int get _doneCount => _remaining.values.where((r) => r == 0).length;

  @override
  Widget build(BuildContext context) {
    final chapter = _chapter;
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
        title: Text(chapter == null ? l10n.hisnTitle : azkarTitle(context, chapter)),
        actions: [
          IconButton(
            tooltip: l10n.resetCounts,
            icon: const Icon(Icons.refresh),
            onPressed: chapter == null ? null : () => setState(_reset),
          ),
        ],
        bottom: chapter == null
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(4),
                child: LinearProgressIndicator(
                  value: _doneCount / chapter.items.length,
                ),
              ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    final l10n = context.l10n;
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_failed || _chapter == null) {
      return AppStateMessage(
        icon: Icons.error_outline,
        message: l10n.azkarLoadError,
        onRetry: _load,
      );
    }
    final chapter = _chapter!;
    final allDone = _doneCount == chapter.items.length;

    return ListView.separated(
      controller: _scroll,
      padding: const EdgeInsets.all(AppSpacing.lg),
      itemCount: chapter.items.length + 1,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
      itemBuilder: (context, i) {
        if (i == chapter.items.length) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
            child: Column(
              children: [
                if (allDone)
                  Text(
                    l10n.azkarCompleted,
                    textAlign: TextAlign.center,
                    style: context.texts.titleMedium?.copyWith(
                      color: context.colors.primary,
                    ),
                  ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  l10n.azkarSource,
                  textAlign: TextAlign.center,
                  style: context.texts.labelSmall?.copyWith(
                    color: context.colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          );
        }
        final zikr = chapter.items[i];
        return _ZikrCard(
          key: _keys[i],
          zikr: zikr,
          remaining: _remaining[zikr.id] ?? zikr.count,
          onTap: () => _tap(i),
        );
      },
    );
  }
}

class _ZikrCard extends StatelessWidget {
  const _ZikrCard({
    super.key,
    required this.zikr,
    required this.remaining,
    required this.onTap,
  });

  final ZikrModel zikr;
  final int remaining;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final done = remaining == 0;

    return AnimatedOpacity(
      duration: AppDurations.normal,
      opacity: done ? 0.6 : 1,
      child: Card(
        color: done ? scheme.surfaceContainerHighest : scheme.surfaceContainerLow,
        child: InkWell(
          borderRadius: AppRadius.cardRadius,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  zikr.text,
                  textDirection: TextDirection.rtl,
                  textAlign: TextAlign.justify,
                  style: context.texts.bodyLarge?.copyWith(height: 1.9, fontSize: 17),
                ),
                const SizedBox(height: AppSpacing.md),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: AnimatedSwitcher(
                    duration: AppDurations.fast,
                    child: Chip(
                      key: ValueKey(remaining),
                      avatar: Icon(
                        done ? Icons.check_circle : Icons.touch_app_outlined,
                        size: 18,
                      ),
                      label: Text(
                        done
                            ? context.l10n.azkarDone
                            : context.l10n.azkarRemaining(remaining),
                      ),
                      backgroundColor: done
                          ? scheme.primaryContainer
                          : scheme.secondaryContainer,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
