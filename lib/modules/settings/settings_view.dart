import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/services/islamic_calendar.dart';

import '../../core/constants/reciters.dart';
import '../../core/services/prayer_config.dart';
import '../../core/services/prayer_times_service.dart';
import '../../core/utils/prayer_labels.dart';
import '../../core/services/prayer_notification_service.dart';
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

          return ListView(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            children: [
              _SectionHeader(context.l10n.appearance),
              Padding(
                padding: AppSpacing.pageH,
                child: SegmentedButton<ThemeMode>(
                  segments: [
                    ButtonSegment(
                      value: ThemeMode.light,
                      icon: const Icon(Icons.light_mode_outlined),
                      label: Text(context.l10n.themeLight),
                    ),
                    ButtonSegment(
                      value: ThemeMode.system,
                      icon: const Icon(Icons.brightness_auto_outlined),
                      label: Text(context.l10n.themeAuto),
                    ),
                    ButtonSegment(
                      value: ThemeMode.dark,
                      icon: const Icon(Icons.dark_mode_outlined),
                      label: Text(context.l10n.themeDark),
                    ),
                  ],
                  selected: {state.themeMode},
                  onSelectionChanged: (s) => cubit.setThemeMode(s.first),
                ),
              ),

              _SectionHeader(context.l10n.quranTextSize),
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

              _SectionHeader(context.l10n.recitationSection),
              ListTile(
                leading: const Icon(Icons.record_voice_over_outlined),
                title: Text(context.l10n.reciterLabel),
                subtitle: Text(
                  context.isArabic
                      ? Reciters.byId(state.reciterId).nameAr
                      : Reciters.byId(state.reciterId).nameEn,
                ),
                onTap: () async {
                  final picked =
                      await _pick<String>(context, context.l10n.reciterLabel, {
                        for (final r in Reciters.all)
                          r.id: context.isArabic ? r.nameAr : r.nameEn,
                      }, state.reciterId);
                  if (picked != null) cubit.setReciter(picked);
                },
              ),

              _SectionHeader(context.l10n.prayerTimesSection),
              ListTile(
                leading: const Icon(Icons.calculate_outlined),
                title: Text(context.l10n.prayerSettingsSection),
                subtitle: Text(methodLabel(context, state.calculationMethod)),
                onTap: () async {
                  final picked = await _pick<String>(
                    context,
                    context.l10n.prayerSettingsSection,
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
                title: Text(context.l10n.madhabTitle),
                subtitle: Text(
                  state.madhab == 'hanafi'
                      ? context.l10n.madhabHanafi
                      : context.l10n.madhabShafi,
                ),
                onTap: () async {
                  final picked =
                      await _pick<String>(context, context.l10n.madhabTitle, {
                        'shafi': context.l10n.madhabShafi,
                        'hanafi': context.l10n.madhabHanafi,
                      }, state.madhab);
                  if (picked != null) cubit.setMadhab(picked);
                },
              ),
              ListTile(
                leading: const Icon(Icons.public),
                title: Text(context.l10n.highLatitudeTitle),
                subtitle: Text(_highLatLabel(context, state.highLatitude)),
                onTap: () async {
                  final picked = await _pick<String>(
                    context,
                    context.l10n.highLatitudeTitle,
                    {
                      for (final r in const ['middle', 'seventh', 'twilight'])
                        r: _highLatLabel(context, r),
                    },
                    state.highLatitude,
                  );
                  if (picked != null) cubit.setHighLatitude(picked);
                },
              ),
              ExpansionTile(
                leading: const Icon(Icons.tune),
                title: Text(context.l10n.adjustmentsTitle),
                subtitle: Text(context.l10n.adjustmentsHint),
                children: [
                  for (final p in PrayerName.values)
                    ListTile(
                      title: Text(prayerLabel(context, p)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline),
                            onPressed: () => cubit.setAdjustment(
                              p,
                              (state.adjustments[p] ?? 0) - 1,
                            ),
                          ),
                          SizedBox(
                            width: 56,
                            child: Text(
                              context.l10n.minutesShort(
                                state.adjustments[p] ?? 0,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline),
                            onPressed: () => cubit.setAdjustment(
                              p,
                              (state.adjustments[p] ?? 0) + 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              ListTile(
                leading: const Icon(Icons.calendar_month_outlined),
                title: Text(context.l10n.hijriAdjustment),
                // Today's date with the adjustment applied, so the effect of
                // each tap is visible right here.
                subtitle: Builder(
                  builder: (context) {
                    final h = IslamicCalendar.of(
                      DateTime.now(),
                      offset: state.hijriOffset,
                    );
                    return Text('${h.hDay} ${h.longMonthName} ${h.hYear}');
                  },
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed: state.hijriOffset <= -2
                          ? null
                          : () => cubit.setHijriOffset(state.hijriOffset - 1),
                    ),
                    SizedBox(
                      width: 32,
                      child: Text(
                        state.hijriOffset > 0
                            ? '+${state.hijriOffset}'
                            : '${state.hijriOffset}',
                        textAlign: TextAlign.center,
                        textDirection: TextDirection.ltr,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      onPressed: state.hijriOffset >= 2
                          ? null
                          : () => cubit.setHijriOffset(state.hijriOffset + 1),
                    ),
                  ],
                ),
              ),

              _SectionHeader(context.l10n.notificationsSection),
              SwitchListTile(
                value: state.prayerNotifications,
                title: Text(context.l10n.prayerNotificationsToggle),
                subtitle: Text(context.l10n.prayerNotificationsSubtitle),
                secondary: const Icon(Icons.notifications_active_outlined),
                onChanged: (on) => _togglePrayerNotifications(context, on),
              ),
              ListTile(
                enabled: state.prayerNotifications,
                leading: const Icon(Icons.alarm),
                title: Text(context.l10n.reminderTitleSetting),
                subtitle: Text(
                  state.reminderMinutes == 0
                      ? context.l10n.reminderOff
                      : context.l10n.minutesShort(state.reminderMinutes),
                ),
                onTap: () async {
                  final picked = await _pick<int>(
                    context,
                    context.l10n.reminderTitleSetting,
                    {
                      for (final m in SettingsState.reminderChoices)
                        m: m == 0
                            ? context.l10n.reminderOff
                            : context.l10n.minutesShort(m),
                    },
                    state.reminderMinutes,
                  );
                  if (picked != null) cubit.setReminderMinutes(picked);
                },
              ),
              SwitchListTile(
                value: state.fridayKahf,
                title: Text(context.l10n.fridayKahfSetting),
                secondary: const Icon(Icons.menu_book_outlined),
                onChanged: state.prayerNotifications
                    ? cubit.setFridayKahf
                    : null,
              ),

              _SectionHeader(context.l10n.languageSection),
              Padding(
                padding: AppSpacing.pageH,
                child: SegmentedButton<String>(
                  segments: [
                    ButtonSegment(
                      value: 'system',
                      label: Text(context.l10n.languageSystem),
                    ),
                    ButtonSegment(
                      value: 'en',
                      label: Text(context.l10n.languageEnglish),
                    ),
                    ButtonSegment(
                      value: 'ar',
                      label: Text(context.l10n.languageArabic),
                    ),
                  ],
                  selected: {state.locale?.languageCode ?? 'system'},
                  onSelectionChanged: (s) => cubit.setLocale(
                    s.first == 'system' ? null : Locale(s.first),
                  ),
                ),
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
              const SizedBox(height: AppSpacing.xxl),
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

  /// A single-choice dialog. Returns the picked value, or null if dismissed.
  static Future<T?> _pick<T>(
    BuildContext context,
    String title,
    Map<T, String> options,
    T current,
  ) {
    return showDialog<T>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        contentPadding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        content: SingleChildScrollView(
          child: RadioGroup<T>(
            groupValue: current,
            onChanged: (v) => Navigator.pop(context, v),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final e in options.entries)
                  RadioListTile<T>(value: e.key, title: Text(e.value)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Permission is asked for here, in response to the user flipping the
  /// switch — Android 13+ may ignore a prompt nobody asked for.
  static Future<void> _togglePrayerNotifications(
    BuildContext context,
    bool on,
  ) async {
    final cubit = context.read<SettingsCubit>();
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;

    if (!on) {
      await cubit.setPrayerNotifications(false);
      return;
    }

    final result = await PrayerNotificationService.requestPermissions();
    switch (result) {
      case NotificationPermission.denied:
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.notificationsDenied)),
        );
      case NotificationPermission.grantedInexact:
        await cubit.setPrayerNotifications(true);
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.notificationsInexact)),
        );
      case NotificationPermission.granted:
        await cubit.setPrayerNotifications(true);
    }
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Text(
        title,
        style: context.texts.labelLarge?.copyWith(
          color: context.colors.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
