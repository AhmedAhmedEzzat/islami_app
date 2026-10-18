import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/assets.dart';
import '../../../core/constants/prefs_keys.dart';
import '../../../core/services/shared_prefs_helper.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_background.dart';
import '../../../core/widgets/text_prompt_dialog.dart';
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
  /// The classic sequence after prayer, each said 33 times, one after the
  /// other.
  static const List<String> classic = [
    'سُبْحَانَ اللَّه',
    'الْـحَمْدُ لِلَّه',
    'اللَّهُ أَكْبَر',
  ];

  static const List<int> targetChoices = [33, 99, 100, 1000];

  int counter = 0;
  int index = 0;
  int rounds = 0;

  /// Counts in a round.
  int target = 33;

  /// Adhkar the user added, after the classic three.
  List<String> custom = [];

  /// Every count today, across all adhkar, and which day that is.
  int today = 0;
  String _day = _todayKey();

  /// The dhikr of the round just completed, so undo can step back into it.
  /// Cleared once the selection or target changes, when that round is no
  /// longer what "back" means.
  int? _lastRound;

  /// Starts a new day's total if midnight has passed. True if it did.
  bool _rollDay() {
    if (_todayKey() == _day) return false;
    _day = _todayKey();
    today = 0;
    return true;
  }

  List<String> get azkar => [...classic, ...custom];

  static String _todayKey() {
    final d = DateTime.now();
    return '${d.year}-${d.month}-${d.day}';
  }

  @override
  void initState() {
    super.initState();
    // The count used to be lost on every tab switch and every restart.
    counter = LocalStorageServices.getInt(PrefsKeys.tasbehCount) ?? 0;
    rounds = LocalStorageServices.getInt(PrefsKeys.tasbehRounds) ?? 0;
    target = LocalStorageServices.getInt(PrefsKeys.tasbehTarget) ?? 33;
    custom = LocalStorageServices.getStringList(PrefsKeys.tasbehCustom) ?? [];
    index = (LocalStorageServices.getInt(PrefsKeys.tasbehZikrIndex) ?? 0).clamp(0, azkar.length - 1);
    today = LocalStorageServices.getString(PrefsKeys.tasbehTodayDate) == _todayKey()
        ? LocalStorageServices.getInt(PrefsKeys.tasbehToday) ?? 0
        : 0;
  }

  void _persist() {
    LocalStorageServices.setInt(PrefsKeys.tasbehCount, counter);
    LocalStorageServices.setInt(PrefsKeys.tasbehZikrIndex, index);
    LocalStorageServices.setInt(PrefsKeys.tasbehRounds, rounds);
    LocalStorageServices.setInt(PrefsKeys.tasbehToday, today);
    LocalStorageServices.setString(PrefsKeys.tasbehTodayDate, _day);
  }

  void _increment() {
    setState(() {
      // A new day starts a new total, even with the screen left open.
      _rollDay();
      counter++;
      today++;
      if (counter >= target) {
        counter = 0;
        rounds++;
        _lastRound = index;
        // The classic three follow one another; the user's own stay put.
        if (index < classic.length) index = (index + 1) % classic.length;
        HapticFeedback.mediumImpact();
      } else {
        HapticFeedback.selectionClick();
      }
    });
    _persist();
  }

  /// Steps back one count, rolling back across a completed round if needed.
  void _undo() {
    if (counter == 0 && _lastRound == null) return;
    setState(() {
      // Yesterday's taps are not taken off today's total.
      if (!_rollDay() && today > 0) today--;
      if (counter > 0) {
        counter--;
      } else {
        rounds--;
        index = _lastRound!;
        _lastRound = null;
        counter = target - 1;
      }
    });
    _persist();
  }

  Future<void> _pickTarget() async {
    final picked = await showDialog<int>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(context.l10n.tasbehTarget),
        children: [
          for (final t in targetChoices)
            ListTile(
              title: Text('$t'),
              trailing: t == target ? Icon(Icons.check, color: context.colors.primary) : null,
              onTap: () => Navigator.pop(context, t),
            ),
        ],
      ),
    );
    if (picked == null || picked == target) return;
    setState(() {
      target = picked;
      _lastRound = null;
      // Already at the new, lower target: that round is complete.
      if (counter >= target) {
        counter = 0;
        rounds++;
        if (index < classic.length) index = (index + 1) % classic.length;
      }
    });
    LocalStorageServices.setInt(PrefsKeys.tasbehTarget, target);
    _persist();
  }

  Future<void> _addZikr() async {
    final text = await showTextPrompt(
      context,
      title: context.l10n.tasbehAdd,
      confirm: context.l10n.qadaAdd,
      hint: context.l10n.tasbehAddHint,
      maxLength: 80,
      textDirection: TextDirection.rtl,
    );
    if (text == null || text.isEmpty || azkar.contains(text)) return;
    setState(() {
      _lastRound = null;
      custom = [...custom, text];
      index = azkar.length - 1;
      counter = 0;
    });
    LocalStorageServices.setStringList(PrefsKeys.tasbehCustom, custom);
    _persist();
  }

  Future<void> _removeZikr(int i) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(context.l10n.tasbehRemove(azkar[i])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(context.l10n.cancel)),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(context.l10n.delete)),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() {
      _lastRound = null;
      custom = [...custom]..removeAt(i - classic.length);
      if (index == i) {
        index = 0;
        counter = 0;
      } else if (index > i) {
        index--;
      }
    });
    LocalStorageServices.setStringList(PrefsKeys.tasbehCustom, custom);
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
      _lastRound = null;
    });
    _persist();
  }

  void _selectZikr(int value) {
    setState(() {
      _lastRound = null;
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
            runSpacing: AppSpacing.xs,
            children: [
              for (var i = 0; i < azkar.length; i++)
                GestureDetector(
                  // The user's own adhkar can be removed with a long press.
                  onLongPress: i < classic.length ? null : () => _removeZikr(i),
                  child: ChoiceChip(
                    selected: i == index,
                    onSelected: (_) => _selectZikr(i),
                    label: Text(azkar[i], textDirection: TextDirection.rtl),
                  ),
                ),
              ActionChip(
                avatar: const Icon(Icons.add, size: 18),
                label: Text(context.l10n.tasbehAdd),
                onPressed: _addZikr,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          _CounterRing(
            key: TasbehView.counterKey,
            counter: counter,
            total: target,
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
          const SizedBox(height: AppSpacing.xs),
          Text(
            context.l10n.tasbehToday(_todayKey() == _day ? today : 0),
            style: context.texts.labelMedium?.copyWith(color: scheme.primary),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton.icon(
                key: TasbehView.undoKey,
                onPressed: (counter == 0 && _lastRound == null) ? null : _undo,
                icon: const Icon(Icons.undo),
                label: Text(context.l10n.undo),
              ),
              const SizedBox(width: AppSpacing.md),
              TextButton.icon(
                onPressed: _pickTarget,
                icon: const Icon(Icons.flag_outlined),
                label: Text(context.l10n.tasbehTargetValue(target)),
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
