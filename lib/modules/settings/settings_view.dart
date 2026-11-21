import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/services/islamic_calendar.dart';

import '../../core/constants/reciters.dart';
import '../../core/services/prayer_config.dart';
import '../../core/services/prayer_times_service.dart';
import '../../core/utils/prayer_labels.dart';
import '../../core/constants/muezzins.dart';
import '../../core/services/notification_refresh.dart';
import '../../core/services/prayer_notification_service.dart';
import '../../core/services/recitation_downloads.dart';
import '../more/listen_view.dart';
import 'backup_tiles.dart';
import 'muezzin_view.dart';
import 'prayer_notifications_prompt.dart';
import 'reminders_view.dart';
import 'settings_section.dart';
import 'tafsir_download_tile.dart';
import '../../core/state/settings_cubit.dart';
import '../../core/state/settings_state.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/l10n_ext.dart';

class SettingsView extends StatelessWidget {
  static const String routeName = '/settings';

  const SettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.settings)),
      body: BlocBuilder<SettingsCubit, SettingsState>(
        builder: (context, state) {
          final cubit = context.read<SettingsCubit>();

          final l10n = context.l10n;
          final notificationsOn = state.prayerNotifications;

          return ListView(
            padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
            children: [
              SettingsSection(
                title: l10n.generalSection,
                icon: Icons.palette_outlined,
                children: [
                  SettingsLabel(l10n.themeLabel),
                  Padding(
                    padding: AppSpacing.pageH,
                    child: SegmentedButton<ThemeMode>(
                      showSelectedIcon: false,
                      segments: [
                        ButtonSegment(
                          value: ThemeMode.light,
                          icon: const Icon(Icons.light_mode_outlined),
                          label: Text(l10n.themeLight),
                        ),
                        ButtonSegment(
                          value: ThemeMode.system,
                          icon: const Icon(Icons.brightness_auto_outlined),
                          label: Text(l10n.themeAuto),
                        ),
                        ButtonSegment(
                          value: ThemeMode.dark,
                          icon: const Icon(Icons.dark_mode_outlined),
                          label: Text(l10n.themeDark),
                        ),
                      ],
                      selected: {state.themeMode},
                      onSelectionChanged: (s) => cubit.setThemeMode(s.first),
                    ),
                  ),
                  SettingsLabel(l10n.languageSection),
                  Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(
                      AppSpacing.lg,
                      0,
                      AppSpacing.lg,
                      AppSpacing.md,
                    ),
                    child: SegmentedButton<String>(
                      showSelectedIcon: false,
                      segments: [
                        ButtonSegment(
                          value: 'system',
                          label: Text(l10n.languageSystem),
                        ),
                        ButtonSegment(
                          value: 'en',
                          label: Text(l10n.languageEnglish),
                        ),
                        ButtonSegment(
                          value: 'ar',
                          label: Text(l10n.languageArabic),
                        ),
                      ],
                      selected: {state.locale?.languageCode ?? 'system'},
                      onSelectionChanged: (s) => cubit.setLocale(
                        s.first == 'system' ? null : Locale(s.first),
                      ),
                    ),
                  ),
                ],
              ),

              SettingsSection(
                title: l10n.quranTitle,
                icon: Icons.menu_book_outlined,
                children: [
                  SettingsLabel(l10n.quranTextSize),
                  Padding(
                    padding: AppSpacing.pageH,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          decoration: BoxDecoration(
                            color: context.sakina.versePanel,
                            borderRadius: AppRadius.cardRadius,
                          ),
                          child: Text(
                            'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ',
                            textAlign: TextAlign.center,
                            textDirection: TextDirection.rtl,
                            style: AppTheme.quranVerse(
                              context,
                              state.quranFontScale,
                            ),
                          ),
                        ),
                        Slider(
                          value: state.quranFontScale,
                          min: SettingsState.minFontScale,
                          max: SettingsState.maxFontScale,
                          divisions: 12,
                          label: '${(state.quranFontScale * 100).round()}%',
                          onChanged: cubit.setQuranFontScale,
                        ),
                      ],
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.auto_stories_outlined),
                    title: Text(l10n.mushafPaperSetting),
                    subtitle: Text(_paperLabel(context, state.mushafPaper)),
                    onTap: () async {
                      final picked = await showSettingsPicker<MushafPaper>(
                        context,
                        l10n.mushafPaperSetting,
                        {
                          for (final p in MushafPaper.values)
                            p: _paperLabel(context, p),
                        },
                        state.mushafPaper,
                      );
                      if (picked != null) cubit.setMushafPaper(picked);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.record_voice_over_outlined),
                    title: Text(l10n.reciterLabel),
                    subtitle: Text(
                      context.isArabic
                          ? Reciters.byId(state.reciterId).nameAr
                          : Reciters.byId(state.reciterId).nameEn,
                    ),
                    onTap: () async {
                      final picked = await showSettingsPicker<String>(
                        context,
                        l10n.reciterLabel,
                        {
                          for (final r in Reciters.all)
                            r.id: context.isArabic ? r.nameAr : r.nameEn,
                        },
                        state.reciterId,
                      );
                      if (picked != null) cubit.setReciter(picked);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.headphones_outlined),
                    title: Text(l10n.listenTitle),
                    subtitle: Text(
                      RecitationDownloads.supported
                          ? l10n.offlineRecitationsSubtitle
                          : l10n.listenSubtitleWeb,
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => const ListenView(),
                      ),
                    ),
                  ),
                  const TafsirDownloadTile(),
                ],
              ),

              SettingsSection(
                title: l10n.prayerTimesSection,
                icon: Icons.schedule_outlined,
                children: [
                  ListTile(
                    leading: const Icon(Icons.calculate_outlined),
                    title: Text(l10n.prayerSettingsSection),
                    subtitle: Text(
                      methodLabel(context, state.calculationMethod),
                    ),
                    onTap: () async {
                      final picked = await showSettingsPicker<String>(
                        context,
                        l10n.prayerSettingsSection,
                        {
                          for (final m in PrayerConfig.methods)
                            m: methodLabel(context, m),
                        },
                        state.calculationMethod,
                      );
                      if (picked != null) cubit.setCalculationMethod(picked);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.wb_cloudy_outlined),
                    title: Text(l10n.madhabTitle),
                    subtitle: Text(
                      state.madhab == 'hanafi'
                          ? l10n.madhabHanafi
                          : l10n.madhabShafi,
                    ),
                    onTap: () async {
                      final picked = await showSettingsPicker<String>(
                        context,
                        l10n.madhabTitle,
                        {
                          'shafi': l10n.madhabShafi,
                          'hanafi': l10n.madhabHanafi,
                        },
                        state.madhab,
                      );
                      if (picked != null) cubit.setMadhab(picked);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.calendar_month_outlined),
                    title: Text(l10n.hijriAdjustment),
                    // Today's date with the adjustment applied, so the effect
                    // of each tap is visible right here.
                    subtitle: Builder(
                      builder: (context) {
                        final h = IslamicCalendar.of(
                          DateTime.now(),
                          offset: state.hijriOffset,
                        );
                        return Text('${h.hDay} ${h.longMonthName} ${h.hYear}');
                      },
                    ),
                    trailing: _Stepper(
                      value: state.hijriOffset > 0
                          ? '+${state.hijriOffset}'
                          : '${state.hijriOffset}',
                      valueWidth: 32,
                      lessTooltip: l10n.dayEarlier,
                      moreTooltip: l10n.dayLater,
                      onLess: state.hijriOffset <= -2
                          ? null
                          : () => cubit.setHijriOffset(state.hijriOffset - 1),
                      onMore: state.hijriOffset >= 2
                          ? null
                          : () => cubit.setHijriOffset(state.hijriOffset + 1),
                    ),
                  ),
                  // Rarely needed, so folded away: most people only ever
                  // pick a method and a madhab.
                  ExpansionTile(
                    shape: const Border(),
                    collapsedShape: const Border(),
                    leading: const Icon(Icons.tune),
                    title: Text(l10n.prayerMoreOptions),
                    subtitle: Text(l10n.prayerMoreOptionsHint),
                    children: [
                      ListTile(
                        leading: const Icon(Icons.public),
                        title: Text(l10n.highLatitudeTitle),
                        subtitle: Text(
                          _highLatLabel(context, state.highLatitude),
                        ),
                        onTap: () async {
                          final picked = await showSettingsPicker<String>(
                            context,
                            l10n.highLatitudeTitle,
                            {
                              for (final r in const [
                                'middle',
                                'seventh',
                                'twilight',
                              ])
                                r: _highLatLabel(context, r),
                            },
                            state.highLatitude,
                          );
                          if (picked != null) cubit.setHighLatitude(picked);
                        },
                      ),
                      SettingsLabel(l10n.adjustmentsHint),
                      for (final p in PrayerName.values)
                        ListTile(
                          dense: true,
                          contentPadding: const EdgeInsetsDirectional.only(
                            start: AppSpacing.xxl + AppSpacing.lg,
                            end: AppSpacing.sm,
                          ),
                          title: Text(prayerLabel(context, p)),
                          trailing: _Stepper(
                            value: l10n.minutesShort(state.adjustments[p] ?? 0),
                            valueWidth: 56,
                            lessTooltip: l10n.minuteEarlier,
                            moreTooltip: l10n.minuteLater,
                            onLess: () => cubit.setAdjustment(
                              p,
                              (state.adjustments[p] ?? 0) - 1,
                            ),
                            onMore: () => cubit.setAdjustment(
                              p,
                              (state.adjustments[p] ?? 0) + 1,
                            ),
                          ),
                        ),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                  ),
                ],
              ),

              SettingsSection(
                title: l10n.notificationsSection,
                icon: Icons.notifications_outlined,
                children: [
                  SwitchListTile(
                    value: notificationsOn,
                    title: Text(l10n.prayerNotificationsToggle),
                    subtitle: Text(
                      notificationsOn
                          ? l10n.prayerNotificationsSubtitle
                          : l10n.notificationsOffHint,
                    ),
                    secondary: const Icon(Icons.notifications_active_outlined),
                    onChanged: (on) => _togglePrayerNotifications(context, on),
                  ),
                  // Every other notification option only does something while
                  // the switch above is on, so they are shown only then
                  // instead of as a long greyed-out list.
                  if (notificationsOn) ...[
                    ListTile(
                      leading: const Icon(Icons.volume_up_outlined),
                      title: Text(l10n.prayerSoundSetting),
                      subtitle: Text(
                        _prayerSoundLabel(context, state.prayerSound),
                      ),
                      onTap: () async {
                        final picked = await showSettingsPicker<PrayerSound>(
                          context,
                          l10n.prayerSoundSetting,
                          {
                            for (final s in PrayerSound.values)
                              s: _prayerSoundLabel(context, s),
                          },
                          state.prayerSound,
                        );
                        if (picked != null) cubit.setPrayerSound(picked);
                      },
                    ),
                    if (state.prayerSound == PrayerSound.adhan)
                      ListTile(
                        leading: const Icon(Icons.mosque_outlined),
                        title: Text(l10n.muezzinSetting),
                        subtitle: Text(_muezzinName(context, state.muezzin)),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => const MuezzinView(),
                          ),
                        ),
                      ),
                    ListTile(
                      leading: const Icon(Icons.alarm),
                      title: Text(l10n.reminderTitleSetting),
                      subtitle: Text(
                        state.reminderMinutes == 0
                            ? l10n.reminderOff
                            : l10n.minutesShort(state.reminderMinutes),
                      ),
                      onTap: () async {
                        final picked = await showSettingsPicker<int>(
                          context,
                          l10n.reminderTitleSetting,
                          {
                            for (final m in SettingsState.reminderChoices)
                              m: m == 0
                                  ? l10n.reminderOff
                                  : l10n.minutesShort(m),
                          },
                          state.reminderMinutes,
                        );
                        if (picked != null) cubit.setReminderMinutes(picked);
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.notifications_none_outlined),
                      title: Text(l10n.otherRemindersTitle),
                      subtitle: Text(
                        l10n.otherRemindersSubtitle(
                          RemindersView.enabledCount(state),
                        ),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => const RemindersView(),
                        ),
                      ),
                    ),
                    ListTile(
                      leading: const Icon(Icons.play_circle_outline),
                      title: Text(l10n.testAdhan),
                      subtitle: Text(l10n.testAdhanSubtitle),
                      onTap: () async {
                        final locale = Localizations.localeOf(context);
                        await PrayerNotificationService.showTest(
                          locale: locale,
                          sound: state.prayerSound,
                          muezzin:
                              await NotificationRefresh.playableMuezzin(state),
                        );
                      },
                    ),
                  ],
                  ListTile(
                    leading: const Icon(Icons.help_outline),
                    title: Text(l10n.adhanHelpTitle),
                    onTap: () => _showAdhanHelp(context),
                  ),
                ],
              ),

              if (BackupTiles.supported)
                SettingsSection(
                  title: l10n.backupSection,
                  icon: Icons.cloud_sync_outlined,
                  children: const [BackupTiles()],
                ),

              const SizedBox(height: AppSpacing.xl),
              Center(
                child: Text(
                  'Sakina',
                  style: context.texts.titleMedium?.copyWith(
                    color: context.colors.primary,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  static String _highLatLabel(BuildContext context, String rule) =>
      switch (rule) {
        'seventh' => context.l10n.highLatSeventh,
        'twilight' => context.l10n.highLatTwilight,
        _ => context.l10n.highLatMiddle,
      };

  static String _paperLabel(BuildContext context, MushafPaper paper) => switch (paper) {
    MushafPaper.auto => context.l10n.paperAuto,
    MushafPaper.white => context.l10n.paperWhite,
    MushafPaper.sepia => context.l10n.paperSepia,
    MushafPaper.night => context.l10n.paperNight,
  };

  static String _muezzinName(BuildContext context, Muezzin m) => m == Muezzins.standard
      ? context.l10n.muezzinDefault
      : m.isCustom
      ? [context.l10n.customAdhanTitle, if (m.nameEn.isNotEmpty) m.nameEn].join(' · ')
      : (context.isArabic ? m.nameAr : m.nameEn);

  static String _prayerSoundLabel(BuildContext context, PrayerSound sound) =>
      switch (sound) {
        PrayerSound.adhan => context.l10n.prayerSoundAdhan,
        PrayerSound.standard => context.l10n.prayerSoundStandard,
        PrayerSound.silent => context.l10n.prayerSoundSilent,
      };

  /// What to check when the adhan does not sound: on many Android phones a
  /// battery saver stops alarms from apps it decides are idle.
  static Future<void> _showAdhanHelp(BuildContext context) {
    final l10n = context.l10n;
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.notifications_paused_outlined),
        title: Text(l10n.adhanHelpTitle),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final step in [
                l10n.adhanHelpNotifications,
                l10n.adhanHelpExact,
                l10n.adhanHelpBattery,
                l10n.adhanHelpVolume,
              ])
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.check_circle_outline, size: 20),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(child: Text(step)),
                    ],
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => PrayerNotificationService.requestPermissions(),
            child: Text(l10n.adhanHelpGrant),
          ),
          FilledButton(onPressed: () => Navigator.pop(context), child: Text(l10n.ok)),
        ],
      ),
    );
  }

  /// Permission is asked for here, in response to the user flipping the
  /// switch — Android 13+ may ignore a prompt nobody asked for.
  static Future<void> _togglePrayerNotifications(
    BuildContext context,
    bool on,
  ) async {
    if (on) {
      await turnOnPrayerNotifications(context);
    } else {
      await context.read<SettingsCubit>().setPrayerNotifications(false);
    }
  }
}

/// A − value + control, for small numeric offsets.
class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.value,
    required this.valueWidth,
    required this.lessTooltip,
    required this.moreTooltip,
    required this.onLess,
    required this.onMore,
  });

  final String value;
  final double valueWidth;
  final String lessTooltip;
  final String moreTooltip;
  final VoidCallback? onLess;
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: lessTooltip,
          icon: const Icon(Icons.remove_circle_outline),
          onPressed: onLess,
        ),
        SizedBox(
          width: valueWidth,
          child: Text(
            value,
            textAlign: TextAlign.center,
            textDirection: TextDirection.ltr,
          ),
        ),
        IconButton(
          tooltip: moreTooltip,
          icon: const Icon(Icons.add_circle_outline),
          onPressed: onMore,
        ),
      ],
    );
  }
}
