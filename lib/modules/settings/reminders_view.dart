import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/constants/dhikr_reminders.dart';
import '../../core/services/prayer_notification_service.dart';
import '../../core/state/settings_cubit.dart';
import '../../core/state/settings_state.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/l10n_ext.dart';
import 'settings_section.dart';

/// The reminders besides the adhan itself, on their own page so the main
/// settings screen stays short. They all post only while prayer
/// notifications are on, which is why Settings links here only then.
class RemindersView extends StatelessWidget {
  const RemindersView({super.key});

  /// How many of the reminders on this page are on, for the link's subtitle.
  static int enabledCount(SettingsState s) =>
      [
        s.dailyHadith,
        s.adhkarReminders,
        s.dhikrHours > 0,
        s.khatmaReminders,
        s.fridayKahf,
      ].where((on) => on).length +
      s.sunnahAlerts.length +
      s.fastingAlerts.length;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.otherRemindersTitle)),
      body: BlocBuilder<SettingsCubit, SettingsState>(
        builder: (context, state) {
          final cubit = context.read<SettingsCubit>();
          return ListView(
            padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
            children: [
              SettingsSection(
                title: l10n.dailyRemindersHeader,
                icon: Icons.today_outlined,
                children: [
                  SwitchListTile(
                    value: state.dailyHadith,
                    title: Text(l10n.dailyHadithSetting),
                    subtitle: Text(l10n.dailyHadithSubtitle),
                    secondary: const Icon(Icons.format_quote_outlined),
                    onChanged: cubit.setDailyHadith,
                  ),
                  SwitchListTile(
                    value: state.adhkarReminders,
                    title: Text(l10n.adhkarRemindersSetting),
                    subtitle: Text(l10n.adhkarRemindersSubtitle),
                    secondary: const Icon(Icons.wb_twilight),
                    onChanged: cubit.setAdhkarReminders,
                  ),
                  ListTile(
                    leading: const Icon(Icons.favorite_border),
                    title: Text(l10n.dhikrRemindersSetting),
                    subtitle: Text(
                      state.dhikrHours == 0
                          ? l10n.dhikrOff
                          : l10n.dhikrEvery(state.dhikrHours),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      final picked = await showSettingsPicker<int>(
                        context,
                        l10n.dhikrRemindersSetting,
                        {
                          for (final h in DhikrReminders.intervals)
                            h: h == 0 ? l10n.dhikrOff : l10n.dhikrEvery(h),
                        },
                        state.dhikrHours,
                      );
                      if (picked != null) cubit.setDhikrHours(picked);
                    },
                  ),
                  SwitchListTile(
                    value: state.khatmaReminders,
                    title: Text(l10n.khatmaReminderSetting),
                    subtitle: Text(l10n.khatmaReminderSubtitle),
                    secondary: const Icon(Icons.flag_outlined),
                    onChanged: cubit.setKhatmaReminders,
                  ),
                ],
              ),
              SettingsSection(
                title: l10n.sunnahRemindersHeader,
                icon: Icons.mosque_outlined,
                children: [
                  for (final (alert, icon, title, subtitle) in [
                    (SunnahAlert.jumuah, Icons.mosque_outlined, l10n.jumuahSetting, l10n.jumuahSubtitle),
                    (SunnahAlert.duha, Icons.wb_sunny_outlined, l10n.duhaSetting, l10n.duhaSubtitle),
                    (SunnahAlert.qiyam, Icons.nightlight_outlined, l10n.qiyamSetting, l10n.qiyamSubtitle),
                  ])
                    SwitchListTile(
                      value: state.sunnahAlerts.contains(alert),
                      title: Text(title),
                      subtitle: Text(subtitle),
                      secondary: Icon(icon),
                      onChanged: (_) => cubit.toggleSunnahAlert(alert),
                    ),
                  SwitchListTile(
                    value: state.fridayKahf,
                    title: Text(l10n.fridayKahfSetting),
                    secondary: const Icon(Icons.menu_book_outlined),
                    onChanged: cubit.setFridayKahf,
                  ),
                ],
              ),
              SettingsSection(
                title: l10n.fastingNotificationsHeader,
                icon: Icons.restaurant_outlined,
                children: [
                  for (final (alert, icon, title, subtitle) in [
                    (
                      FastingAlert.mondayThursday,
                      Icons.event_repeat_outlined,
                      l10n.fastMondayThursdaySetting,
                      l10n.fastMondayThursdaySubtitle,
                    ),
                    (FastingAlert.whiteDays, Icons.brightness_3_outlined, l10n.fastWhiteDaysSetting, null),
                    (FastingAlert.ramadan, Icons.restaurant_outlined, l10n.fastRamadanSetting, null),
                    (FastingAlert.arafahAshura, Icons.wb_twilight_outlined, l10n.fastArafahAshuraSetting, null),
                  ])
                    SwitchListTile(
                      value: state.fastingAlerts.contains(alert),
                      title: Text(title),
                      subtitle: subtitle == null ? null : Text(subtitle),
                      secondary: Icon(icon),
                      onChanged: (_) => cubit.toggleFastingAlert(alert),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
