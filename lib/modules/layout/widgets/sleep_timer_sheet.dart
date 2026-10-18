import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/services/sleep_timer.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/l10n_ext.dart';

/// Lets the reader pick when audio should stop by itself.
Future<void> showSleepTimerSheet(BuildContext context, {bool offerEndOfSura = false}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) {
      final l10n = context.l10n;
      final active = SleepTimer.setting.value != null;
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.sm),
              child: Text(l10n.sleepTimer, style: context.texts.titleLarge),
            ),
            for (final m in SleepTimer.minuteChoices)
              ListTile(
                leading: const Icon(Icons.timer_outlined),
                title: Text(l10n.minutesShort(m)),
                onTap: () {
                  SleepTimer.start(Duration(minutes: m));
                  Navigator.pop(context);
                },
              ),
            if (offerEndOfSura)
              ListTile(
                leading: const Icon(Icons.last_page_rounded),
                title: Text(l10n.sleepEndOfSura),
                onTap: () {
                  SleepTimer.stopAtEndOfSura();
                  Navigator.pop(context);
                },
              ),
            if (active)
              ListTile(
                leading: Icon(Icons.timer_off_outlined, color: context.colors.error),
                title: Text(l10n.sleepTimerOff),
                onTap: () {
                  SleepTimer.cancel();
                  Navigator.pop(context);
                },
              ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      );
    },
  );
}

/// "⏾ 23 min" while a sleep timer runs; nothing otherwise.
class SleepTimerBadge extends StatefulWidget {
  const SleepTimerBadge({super.key});

  @override
  State<SleepTimerBadge> createState() => _SleepTimerBadgeState();
}

class _SleepTimerBadgeState extends State<SleepTimerBadge> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    // Minutes are all it shows, so a slow tick is enough.
    _tick = Timer.periodic(const Duration(seconds: 20), (_) {
      if (mounted && SleepTimer.setting.value?.endsAt != null) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<SleepSetting?>(
      valueListenable: SleepTimer.setting,
      builder: (context, setting, _) {
        if (setting == null) return const SizedBox.shrink();
        final label = setting.endOfSura
            ? context.l10n.sleepEndOfSuraShort
            : context.l10n.minutesShort((setting.remaining(DateTime.now()).inSeconds / 60).ceil());
        return Padding(
          padding: const EdgeInsetsDirectional.only(start: AppSpacing.xs),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.bedtime_outlined, size: 16, color: context.colors.primary),
              const SizedBox(width: 2),
              Text(label, style: context.texts.labelSmall?.copyWith(color: context.colors.primary)),
            ],
          ),
        );
      },
    );
  }
}

/// A sleep timer button for app bars, lit while a timer runs.
class SleepTimerButton extends StatelessWidget {
  const SleepTimerButton({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<SleepSetting?>(
      valueListenable: SleepTimer.setting,
      builder: (context, setting, _) => IconButton(
        tooltip: context.l10n.sleepTimer,
        isSelected: setting != null,
        icon: const Icon(Icons.bedtime_outlined),
        selectedIcon: const Icon(Icons.bedtime),
        onPressed: () => showSleepTimerSheet(context),
      ),
    );
  }
}
