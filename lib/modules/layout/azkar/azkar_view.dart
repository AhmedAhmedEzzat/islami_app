import 'dart:async';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/constants/prefs_keys.dart';
import '../../../core/services/azkar_favourites.dart';
import '../../../core/services/azkar_progress.dart';
import '../../../core/services/azkar_service.dart';
import '../../../core/services/shared_prefs_helper.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/l10n_ext.dart';
import '../../../core/widgets/app_background.dart';
import '../../../models/zikr_model.dart';
import 'azkar_labels.dart';

/// Reads one Hisn al-Muslim chapter, counting each dhikr down to zero.
///
/// The counts are kept for the sitting, so a chapter left half-way is picked
/// up where it was. Each dhikr can be copied, shared or kept as a favourite,
/// and the text size is the reader's to set.
class AzkarView extends StatefulWidget {
  const AzkarView({super.key, required this.chapterId});

  /// A chapter of the book, or [AzkarService.favouritesId].
  final int chapterId;

  /// The text sizes offered, as multiples of the usual one.
  static const double minTextScale = 0.8;
  static const double maxTextScale = 2.0;
  static const double textScaleStep = 0.2;

  @override
  State<AzkarView> createState() => _AzkarViewState();
}

class _AzkarViewState extends State<AzkarView> {
  AzkarChapter? _chapter;

  /// Counts left, one for each dhikr of the chapter, in order. By position
  /// rather than by id: the same dhikr can appear twice.
  List<int> _remaining = const [];
  bool _isLoading = true;
  bool _failed = false;
  final ScrollController _scroll = ScrollController();
  final List<GlobalKey> _keys = [];
  double _textScale = _savedTextScale();

  static double _savedTextScale() =>
      (LocalStorageServices.getDouble(PrefsKeys.azkarTextScale) ?? 1.0).clamp(
        AzkarView.minTextScale,
        AzkarView.maxTextScale,
      );

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
        if (chapter != null) {
          _remaining =
              AzkarProgress.remaining(chapter) ??
              [for (final z in chapter.items) z.count];
          _keys
            ..clear()
            ..addAll(List.generate(chapter.items.length, (_) => GlobalKey()));
        }
      });
      // Picking a chapter up again: go to where the reader had got to.
      if (chapter != null &&
          _doneCount > 0 &&
          _doneCount < chapter.items.length) {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _showNext(0, animate: false),
        );
      }
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
    setState(() => _remaining = [for (final z in chapter.items) z.count]);
    unawaited(AzkarProgress.clear(chapter));
    if (_scroll.hasClients) {
      _scroll.animateTo(
        0,
        duration: AppDurations.slow,
        curve: Curves.easeInOut,
      );
    }
  }

  void _tap(int index) {
    final left = _remaining[index];
    if (left == 0) return;
    setState(() => _remaining[index] = left - 1);
    unawaited(AzkarProgress.save(_chapter!, _remaining));
    if (left - 1 > 0) {
      HapticFeedback.selectionClick();
      return;
    }
    HapticFeedback.mediumImpact();
    // Finished this one: bring the next unfinished dhikr into view.
    _showNext(index + 1);
  }

  /// Scrolls to the first unfinished dhikr at or after [from].
  void _showNext(int from, {bool animate = true}) {
    for (var i = from; i < _remaining.length; i++) {
      if (_remaining[i] == 0) continue;
      final ctx = _keys[i].currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          duration: animate ? AppDurations.slow : Duration.zero,
          curve: Curves.easeInOut,
          alignment: 0.1,
        );
      }
      return;
    }
  }

  void _setTextScale(double scale) {
    final next = scale.clamp(AzkarView.minTextScale, AzkarView.maxTextScale);
    // Steps of a fifth do not add up exactly; keep one decimal.
    final rounded = (next * 10).round() / 10;
    setState(() => _textScale = rounded);
    unawaited(
      LocalStorageServices.setDouble(PrefsKeys.azkarTextScale, rounded),
    );
  }

  int get _doneCount => _remaining.where((r) => r == 0).length;

  String _shareText(ZikrModel zikr) =>
      '${zikr.text}\n\n${context.l10n.hisnTitle}';

  Future<void> _copy(ZikrModel zikr) async {
    await Clipboard.setData(ClipboardData(text: zikr.text));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(context.l10n.copied)));
  }

  @override
  Widget build(BuildContext context) {
    final chapter = _chapter;
    final l10n = context.l10n;
    final total = chapter?.items.length ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              chapter == null ? l10n.hisnTitle : azkarTitle(context, chapter),
            ),
            if (total > 0)
              Text(
                l10n.azkarProgressOf(_doneCount, total),
                style: context.texts.labelMedium?.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
              ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: l10n.textSmaller,
            icon: const Icon(Icons.text_decrease),
            onPressed: _textScale <= AzkarView.minTextScale
                ? null
                : () => _setTextScale(_textScale - AzkarView.textScaleStep),
          ),
          IconButton(
            tooltip: l10n.textLarger,
            icon: const Icon(Icons.text_increase),
            onPressed: _textScale >= AzkarView.maxTextScale
                ? null
                : () => _setTextScale(_textScale + AzkarView.textScaleStep),
          ),
          IconButton(
            tooltip: l10n.resetCounts,
            icon: const Icon(Icons.refresh),
            onPressed: chapter == null || _untouched ? null : _reset,
          ),
        ],
        bottom: total == 0
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(4),
                child: LinearProgressIndicator(value: _doneCount / total),
              ),
      ),
      body: _buildBody(),
    );
  }

  /// Nothing counted yet, so there is nothing to reset.
  bool get _untouched {
    final chapter = _chapter;
    if (chapter == null) return true;
    for (var i = 0; i < _remaining.length; i++) {
      if (_remaining[i] != chapter.items[i].count) return false;
    }
    return true;
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
    if (chapter.items.isEmpty) {
      // Only the favourites can be empty: the book's chapters never are.
      return AppStateMessage(
        icon: Icons.favorite_border,
        message: l10n.azkarNoFavourites,
      );
    }
    final allDone = _doneCount == chapter.items.length;

    // All of the chapter is laid out, not just what is on screen, so the
    // reader can be taken straight to any dhikr. The longest has 24.
    return ValueListenableBuilder<Set<int>>(
      valueListenable: AzkarFavourites.notifier,
      builder: (context, favourites, _) => SingleChildScrollView(
        controller: _scroll,
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (i, zikr) in chapter.items.indexed) ...[
              _ZikrCard(
                key: _keys[i],
                number: i + 1,
                zikr: zikr,
                remaining: _remaining[i],
                textScale: _textScale,
                favourite: favourites.contains(zikr.id),
                onTap: () => _tap(i),
                onFavourite: () => AzkarFavourites.toggle(zikr.id),
                onCopy: () => _copy(zikr),
                onShare: () => SharePlus.instance.share(
                  ShareParams(text: _shareText(zikr)),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            Padding(
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
            ),
          ],
        ),
      ),
    );
  }
}

class _ZikrCard extends StatelessWidget {
  const _ZikrCard({
    super.key,
    required this.number,
    required this.zikr,
    required this.remaining,
    required this.textScale,
    required this.favourite,
    required this.onTap,
    required this.onFavourite,
    required this.onCopy,
    required this.onShare,
  });

  /// Its place in the chapter, from 1.
  final int number;
  final ZikrModel zikr;
  final int remaining;
  final double textScale;
  final bool favourite;
  final VoidCallback onTap;
  final VoidCallback onFavourite;
  final VoidCallback onCopy;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final l10n = context.l10n;
    final done = remaining == 0;

    return Card(
      color: done ? scheme.surfaceContainerHighest : scheme.surfaceContainerLow,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: done ? null : onTap,
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            AppSpacing.lg,
            AppSpacing.xs,
            AppSpacing.xs,
            AppSpacing.md,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: done
                        ? scheme.primary
                        : scheme.secondaryContainer,
                    foregroundColor: done
                        ? scheme.onPrimary
                        : scheme.onSecondaryContainer,
                    child: done
                        ? const Icon(Icons.check, size: 16)
                        : Text('$number', style: context.texts.labelMedium),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  if (zikr.count > 1)
                    Expanded(
                      child: Text(
                        l10n.azkarTimes(zikr.count),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.texts.labelLarge?.copyWith(
                          color: scheme.primary,
                        ),
                      ),
                    )
                  else
                    const Spacer(),
                  IconButton(
                    tooltip: favourite
                        ? l10n.removeFavourite
                        : l10n.addFavourite,
                    isSelected: favourite,
                    icon: const Icon(Icons.favorite_border),
                    selectedIcon: Icon(Icons.favorite, color: scheme.error),
                    onPressed: onFavourite,
                  ),
                  IconButton(
                    tooltip: l10n.copyVerse,
                    icon: const Icon(Icons.copy_outlined),
                    onPressed: onCopy,
                  ),
                  IconButton(
                    tooltip: l10n.shareVerse,
                    icon: const Icon(Icons.share_outlined),
                    onPressed: onShare,
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsetsDirectional.only(end: AppSpacing.md),
                child: AnimatedOpacity(
                  duration: AppDurations.normal,
                  // Read and done, so it steps back; still legible.
                  opacity: done ? 0.6 : 1,
                  child: Text(
                    zikr.text,
                    textDirection: TextDirection.rtl,
                    textAlign: TextAlign.justify,
                    style: context.texts.bodyLarge?.copyWith(
                      height: 1.9,
                      fontSize: 17 * textScale,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Padding(
                padding: const EdgeInsetsDirectional.only(end: AppSpacing.md),
                child: _Counter(count: zikr.count, remaining: remaining),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// How many are left, as a ring that fills with each tap.
class _Counter extends StatelessWidget {
  const _Counter({required this.count, required this.remaining});

  final int count;
  final int remaining;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final l10n = context.l10n;
    final done = remaining == 0;
    final label = done ? l10n.azkarDone : l10n.azkarRemaining(remaining);

    return Semantics(
      label: label,
      excludeSemantics: true,
      child: Row(
        children: [
          SizedBox.square(
            dimension: 44,
            child: Stack(
              alignment: Alignment.center,
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(end: (count - remaining) / count),
                  duration: AppDurations.normal,
                  builder: (context, value, _) => CircularProgressIndicator(
                    value: value,
                    strokeWidth: 4,
                    backgroundColor: scheme.secondaryContainer,
                  ),
                ),
                done
                    ? Icon(Icons.check, color: scheme.primary)
                    : FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.sm),
                          child: Text(
                            '$remaining',
                            style: context.texts.titleMedium?.copyWith(
                              color: scheme.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              label,
              style: context.texts.labelLarge?.copyWith(
                color: done ? scheme.primary : scheme.onSurfaceVariant,
              ),
            ),
          ),
          if (!done)
            Icon(Icons.touch_app_outlined, color: scheme.onSurfaceVariant),
        ],
      ),
    );
  }
}
