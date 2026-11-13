import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/services/azkar_progress.dart';
import '../../../core/services/azkar_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/l10n_ext.dart';
import '../../../core/widgets/app_background.dart';
import '../../../core/widgets/fitted_sheet.dart';
import '../../../models/zikr_model.dart';
import 'azkar_labels.dart';

/// Reads one Hisn al-Muslim chapter, counting each dhikr down to zero.
///
/// Counts are kept until the chapter is due again (see [AzkarProgress]), so
/// leaving the page midway does not lose them.
class AzkarView extends StatefulWidget {
  const AzkarView({super.key, required this.chapterId, this.clock = DateTime.now});

  final int chapterId;

  /// Injectable for tests.
  final DateTime Function() clock;

  static Key cardKey(int zikrId) => ValueKey('zikr-card-$zikrId');
  static Key counterKey(int zikrId) => ValueKey('zikr-counter-$zikrId');

  @override
  State<AzkarView> createState() => _AzkarViewState();
}

class _AzkarViewState extends State<AzkarView> {
  AzkarChapter? _chapter;
  final Map<int, int> _remaining = {};
  bool _isLoading = true;
  bool _failed = false;
  double _fontScale = 1;

  /// When the reading started: its counts belong to that session even if it
  /// runs past noon or midnight.
  late DateTime _openedAt = widget.clock();
  final ScrollController _scroll = ScrollController();
  final List<GlobalKey> _keys = [];

  @override
  void initState() {
    super.initState();
    _fontScale = AzkarProgress.fontScale();
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
        _openedAt = widget.clock();
        if (chapter != null) {
          _remaining
            ..clear()
            ..addAll(AzkarProgress.remaining(chapter, _openedAt));
          _keys
            ..clear()
            ..addAll(List.generate(chapter.items.length, (_) => GlobalKey()));
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _failed = true;
        _isLoading = false;
      });
    }
  }

  bool get _started {
    final chapter = _chapter;
    if (chapter == null) return false;
    return chapter.items.any((z) => (_remaining[z.id] ?? z.count) < z.count);
  }

  Future<void> _confirmReset() async {
    final chapter = _chapter;
    if (chapter == null || !_started) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(context.l10n.azkarResetConfirm),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(context.l10n.cancel)),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(context.l10n.reset)),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() {
      _remaining
        ..clear()
        ..addEntries(chapter.items.map((z) => MapEntry(z.id, z.count)));
    });
    AzkarProgress.clear(chapter.id);
  }

  void _persist() => AzkarProgress.save(_chapter!.id, _openedAt, Map.of(_remaining));

  void _tap(int index) {
    final chapter = _chapter!;
    final zikr = chapter.items[index];
    final left = _remaining[zikr.id] ?? 0;
    if (left == 0) return;
    setState(() => _remaining[zikr.id] = left - 1);
    _persist();
    if (left - 1 > 0) {
      HapticFeedback.selectionClick();
      return;
    }
    HapticFeedback.mediumImpact();
    if (_doneCount == chapter.items.length) {
      AzkarProgress.recordFinished(chapter.id, _openedAt);
      return;
    }
    // Finished this one: bring the next unfinished dhikr into view.
    for (var i = index + 1; i < chapter.items.length; i++) {
      if ((_remaining[chapter.items[i].id] ?? 0) > 0) {
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

  void _undo(ZikrModel zikr) {
    final left = _remaining[zikr.id] ?? zikr.count;
    if (left >= zikr.count) return;
    setState(() => _remaining[zikr.id] = left + 1);
    HapticFeedback.selectionClick();
    _persist();
  }

  Future<void> _showActions(ZikrModel zikr) async {
    final l10n = context.l10n;
    final canUndo = (_remaining[zikr.id] ?? zikr.count) < zikr.count;
    final picked = await showFittedSheet<String>(
      context,
      builder: (context) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.undo),
              title: Text(l10n.azkarUndoOne),
              enabled: canUndo,
              onTap: () => Navigator.pop(context, 'undo'),
            ),
            ListTile(
              leading: const Icon(Icons.copy),
              title: Text(l10n.copyVerse),
              onTap: () => Navigator.pop(context, 'copy'),
            ),
            ListTile(
              leading: const Icon(Icons.share_outlined),
              title: Text(l10n.azkarShare),
              onTap: () => Navigator.pop(context, 'share'),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    final text = _shareText(zikr);
    switch (picked) {
      case 'undo':
        _undo(zikr);
      case 'copy':
        await Clipboard.setData(ClipboardData(text: text));
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.copied)));
      case 'share':
        await SharePlus.instance.share(ShareParams(text: text));
    }
  }

  String _shareText(ZikrModel zikr) => '${zikr.text}\n\n${_chapter!.title} · ${context.l10n.hisnTitle}';

  Future<void> _pickFontScale() async {
    await showFittedSheet<void>(
      context,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheet) => SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(context.l10n.azkarTextSize, style: context.texts.titleMedium),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'سُبْحَانَ اللَّهِ وَبِحَمْدِهِ',
                  textDirection: TextDirection.rtl,
                  textAlign: TextAlign.center,
                  style: _zikrStyle(context, _fontScale),
                ),
                Row(
                  children: [
                    const Icon(Icons.text_decrease, size: 18),
                    Expanded(
                      child: Slider(
                        value: _fontScale,
                        min: AzkarProgress.minFontScale,
                        max: AzkarProgress.maxFontScale,
                        divisions: 10,
                        label: '${(_fontScale * 100).round()}%',
                        onChanged: (v) {
                          setSheet(() {});
                          setState(() => _fontScale = v);
                        },
                        onChangeEnd: AzkarProgress.setFontScale,
                      ),
                    ),
                    const Icon(Icons.text_increase, size: 22),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
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
            tooltip: l10n.azkarTextSize,
            icon: const Icon(Icons.format_size),
            onPressed: chapter == null ? null : _pickFontScale,
          ),
          IconButton(
            tooltip: l10n.resetCounts,
            icon: const Icon(Icons.refresh),
            onPressed: chapter == null || !_started ? null : _confirmReset,
          ),
        ],
        bottom: chapter == null
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(4),
                child: Semantics(
                  label: l10n.azkarChapterProgress(_doneCount, chapter.items.length),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(end: _doneCount / chapter.items.length),
                    duration: AppDurations.normal,
                    builder: (context, v, _) => LinearProgressIndicator(value: v),
                  ),
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
    final twiceDaily = chapter.id == FeaturedAzkar.morningEvening;

    return ListView.separated(
      controller: _scroll,
      padding: const EdgeInsets.all(AppSpacing.lg),
      itemCount: chapter.items.length + (twiceDaily ? 2 : 1),
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
      itemBuilder: (context, i) {
        if (twiceDaily) {
          if (i == 0) {
            final morning = AzkarProgress.isMorning(_openedAt);
            return _SessionBanner(
              icon: morning ? Icons.wb_sunny_outlined : Icons.nights_stay_outlined,
              text: morning ? l10n.azkarMorningNow : l10n.azkarEveningNow,
            );
          }
          i--;
        }
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
        return KeyedSubtree(
          key: _keys[i],
          child: _ZikrCard(
            key: AzkarView.cardKey(zikr.id),
            zikr: zikr,
            remaining: _remaining[zikr.id] ?? zikr.count,
            fontScale: _fontScale,
            onTap: () => _tap(i),
            onMore: () => _showActions(zikr),
          ),
        );
      },
    );
  }
}

TextStyle? _zikrStyle(BuildContext context, double scale) =>
    context.texts.bodyLarge?.copyWith(height: 1.9, fontSize: 17 * scale);

class _SessionBanner extends StatelessWidget {
  const _SessionBanner({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    return Row(
      children: [
        Icon(icon, size: 18, color: scheme.primary),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(text, style: context.texts.labelLarge?.copyWith(color: scheme.primary)),
        ),
      ],
    );
  }
}

class _ZikrCard extends StatelessWidget {
  const _ZikrCard({
    super.key,
    required this.zikr,
    required this.remaining,
    required this.fontScale,
    required this.onTap,
    required this.onMore,
  });

  final ZikrModel zikr;
  final int remaining;
  final double fontScale;
  final VoidCallback onTap;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final l10n = context.l10n;
    final done = remaining == 0;

    return AnimatedOpacity(
      duration: AppDurations.normal,
      opacity: done ? 0.6 : 1,
      child: Card(
        color: done ? scheme.surfaceContainerHighest : scheme.surfaceContainerLow,
        child: Semantics(
          hint: l10n.azkarCardHint,
          child: InkWell(
            borderRadius: AppRadius.cardRadius,
            onTap: onTap,
            onLongPress: onMore,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    zikr.text,
                    textDirection: TextDirection.rtl,
                    textAlign: TextAlign.justify,
                    style: _zikrStyle(context, fontScale),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      IconButton(
                        tooltip: l10n.azkarCardActions,
                        icon: const Icon(Icons.more_horiz),
                        onPressed: onMore,
                      ),
                      const Spacer(),
                      // Wraps rather than overflows with a large font.
                      Flexible(
                        flex: 8,
                        child: Align(
                          alignment: AlignmentDirectional.centerEnd,
                          child: AnimatedSwitcher(
                            duration: AppDurations.fast,
                            transitionBuilder: (child, a) => ScaleTransition(scale: a, child: child),
                            child: _Counter(
                              key: ValueKey(remaining),
                              zikr: zikr,
                              remaining: remaining,
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
        ),
      ),
    );
  }
}

/// How many are left, with a ring that fills as the count goes down.
class _Counter extends StatelessWidget {
  const _Counter({super.key, required this.zikr, required this.remaining});

  final ZikrModel zikr;
  final int remaining;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final l10n = context.l10n;
    final done = remaining == 0;
    final total = zikr.count;
    return Chip(
      key: AzkarView.counterKey(zikr.id),
      avatar: done
          ? Icon(Icons.check_circle, size: 18, color: scheme.primary)
          : total > 1
              ? SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(
                    value: (total - remaining) / total,
                    strokeWidth: 2.5,
                    backgroundColor: scheme.onSecondaryContainer.withValues(alpha: 0.15),
                  ),
                )
              : const Icon(Icons.touch_app_outlined, size: 18),
      label: Text(done ? l10n.azkarDone : l10n.azkarRemaining(remaining)),
      backgroundColor: done ? scheme.primaryContainer : scheme.secondaryContainer,
    );
  }
}
