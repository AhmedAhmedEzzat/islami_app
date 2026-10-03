import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/assets.dart';
import '../../../core/constants/prefs_keys.dart';
import '../../../core/services/shared_prefs_helper.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_background.dart';
import '../../../core/utils/l10n_ext.dart';

class TasbehView extends StatefulWidget {
  const TasbehView({super.key, this.embedded = false});

  /// True inside another screen's tab, which supplies the page header.
  final bool embedded;

  /// Keys used by the widget tests, so they do not depend on layout or copy.
  static const counterKey = Key('tasbeh-counter');
  static const countValueKey = Key('tasbeh-count-value');
  static const roundsKey = Key('tasbeh-rounds');
  static const undoKey = Key('tasbeh-undo');
  static const resetKey = Key('tasbeh-reset');
  static const resetConfirmKey = Key('tasbeh-reset-confirm');

  @override
  State<TasbehView> createState() => _TasbehViewState();
}

class _TasbehViewState extends State<TasbehView> {
  /// A full round of tasbeh is 33 counts.
  static const int countsPerZikr = 33;

  static const List<String> azkar = [
    'سُبْحَانَ اللَّه',
    'الْـحَمْدُ لِلَّه',
    'اللَّهُ أَكْبَر',
  ];

  int counter = 0;
  int index = 0;
  int rounds = 0;

  @override
  void initState() {
    super.initState();
    // The count used to be lost on every tab switch and every restart.
    counter = LocalStorageServices.getInt(PrefsKeys.tasbehCount) ?? 0;
    index = LocalStorageServices.getInt(PrefsKeys.tasbehZikrIndex) ?? 0;
    rounds = LocalStorageServices.getInt(PrefsKeys.tasbehRounds) ?? 0;
  }

  void _persist() {
    LocalStorageServices.setInt(PrefsKeys.tasbehCount, counter);
    LocalStorageServices.setInt(PrefsKeys.tasbehZikrIndex, index);
    LocalStorageServices.setInt(PrefsKeys.tasbehRounds, rounds);
  }

  void _increment() {
    setState(() {
      counter++;
      if (counter >= countsPerZikr) {
        counter = 0;
        rounds++;
        index = (index + 1) % azkar.length;
        HapticFeedback.mediumImpact();
      } else {
        HapticFeedback.selectionClick();
      }
    });
    _persist();
  }

  /// Steps back one count, rolling back across a completed round if needed.
  void _undo() {
    if (counter == 0 && rounds == 0) return;
    setState(() {
      if (counter > 0) {
        counter--;
      } else {
        rounds--;
        index = (index - 1 + azkar.length) % azkar.length;
        counter = countsPerZikr - 1;
      }
    });
    _persist();
  }

  Future<void> _confirmReset() async {
    final shouldReset = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.resetTasbehTitle),
        content: Text(context.l10n.resetTasbehBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            key: TasbehView.resetConfirmKey,
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.reset),
          ),
        ],
      ),
    );

    if (shouldReset != true) return;
    setState(() {
      counter = 0;
      index = 0;
      rounds = 0;
    });
    _persist();
  }

  void _selectZikr(int value) {
    setState(() {
      index = value;
      counter = 0;
    });
    _persist();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;

    final body = SingleChildScrollView(
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.xl,
      ),
      child: Column(
        children: [
          Wrap(
            alignment: WrapAlignment.center,
            spacing: AppSpacing.sm,
            children: [
              for (var i = 0; i < azkar.length; i++)
                ChoiceChip(
                  selected: i == index,
                  onSelected: (_) => _selectZikr(i),
                  label: Text(azkar[i], textDirection: TextDirection.rtl),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          _CounterRing(
            key: TasbehView.counterKey,
            counter: counter,
            total: countsPerZikr,
            zikr: azkar[index],
            onTap: _increment,
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            key: TasbehView.roundsKey,
            context.l10n.roundsCompleted(rounds),
            style: context.texts.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton.icon(
                key: TasbehView.undoKey,
                onPressed: (counter == 0 && rounds == 0) ? null : _undo,
                icon: const Icon(Icons.undo),
                label: Text(context.l10n.undo),
              ),
              const SizedBox(width: AppSpacing.md),
              TextButton.icon(
                key: TasbehView.resetKey,
                onPressed: _confirmReset,
                icon: const Icon(Icons.refresh),
                label: Text(context.l10n.reset),
              ),
            ],
          ),
        ],
      ),
    );
    if (widget.embedded) return body;
    return AppBackground(
      ornament: Assets.tasbehBackground,
      title: context.l10n.tasbehTitle,
      child: body,
    );
  }
}

/// The tap target. Deliberately bounded rather than full-screen, so the chips
/// and the undo/reset buttons are not swallowed by the counter's gesture.
class _CounterRing extends StatelessWidget {
  const _CounterRing({
    super.key,
    required this.counter,
    required this.total,
    required this.zikr,
    required this.onTap,
  });

  final int counter;
  final int total;
  final String zikr;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;

    return Semantics(
      button: true,
      label: context.l10n.countOf(counter, total),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: 260,
          height: 260,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox.expand(
                child: TweenAnimationBuilder<double>(
                  duration: AppDurations.fast,
                  curve: Curves.easeOut,
                  tween: Tween(begin: 0, end: counter / total),
                  builder: (context, value, _) => CircularProgressIndicator(
                    value: value,
                    strokeWidth: 14,
                    strokeCap: StrokeCap.round,
                    backgroundColor: scheme.surfaceContainerHighest,
                  ),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    zikr,
                    textDirection: TextDirection.rtl,
                    style: context.texts.titleMedium?.copyWith(
                      color: scheme.primary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    key: TasbehView.countValueKey,
                    '$counter',
                    style: context.texts.displayMedium?.copyWith(
                      color: scheme.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    context.l10n.ofTotal(total),
                    style: context.texts.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
