import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/constants/assets.dart';
import '../../core/services/prayer_times_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/l10n_ext.dart';
import '../../core/widgets/app_background.dart';
import '../layout/hadeth/hadeth_view.dart';
import '../layout/radio/radio_view.dart';
import '../layout/time/qibla_view.dart';
import '../layout/time/tracker_view.dart';
import '../settings/settings_view.dart';
import 'calendar_view.dart';
import 'duas_view.dart';
import 'names_view.dart';
import 'zakat_view.dart';

/// Everything that is not a daily destination of its own.
class MoreView extends StatelessWidget {
  const MoreView({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    void push(Widget page, {String? name}) => Navigator.push(
      context,
      MaterialPageRoute<void>(
        settings: RouteSettings(name: name),
        builder: (_) => page,
      ),
    );

    final tiles = <(IconData, String, VoidCallback)>[
      (
        Icons.format_quote_outlined,
        l10n.hadethTitle,
        () => push(const HadethView()),
      ),
      (
        Icons.volunteer_activism_outlined,
        l10n.duasTitle,
        () => push(const DuasView()),
      ),
      (
        Icons.auto_awesome_outlined,
        l10n.namesTitle,
        () => push(const NamesView()),
      ),
      (
        Icons.radio_outlined,
        l10n.radioTitle,
        () => push(const RadioView(), name: RadioView.routeName),
      ),
      (
        Icons.calendar_month_outlined,
        l10n.calendarTitle,
        () => push(const CalendarView()),
      ),
      (
        Icons.explore_outlined,
        l10n.qiblaTitle,
        () => push(QiblaView(location: PrayerTimesService.currentLocation())),
      ),
      (
        Icons.check_circle_outline,
        l10n.prayerTracker,
        () => push(const TrackerView()),
      ),
      (
        Icons.calculate_outlined,
        l10n.zakatTitle,
        () => push(const ZakatView()),
      ),
    ];

    return AppBackground(
      ornament: Assets.radioBackground,
      title: l10n.tabMore,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.xl,
        ),
        children: [
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: AppSpacing.sm,
            crossAxisSpacing: AppSpacing.sm,
            childAspectRatio: 1.6,
            children: [
              for (final (icon, label, onTap) in tiles)
                Card(
                  color: context.colors.surfaceContainer,
                  child: InkWell(
                    borderRadius: AppRadius.cardRadius,
                    onTap: onTap,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(icon, size: 28, color: context.colors.primary),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          label,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          style: context.texts.labelLarge,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Card(
            color: context.colors.surfaceContainerLow,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.settings_outlined),
                  title: Text(l10n.settings),
                  onTap: () => Navigator.of(context, rootNavigator: true).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const SettingsView(),
                    ),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.share_outlined),
                  title: Text(l10n.shareApp),
                  onTap: () => SharePlus.instance.share(
                    ShareParams(text: l10n.shareAppText),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: Text(l10n.aboutTitle),
                  onTap: () => push(const _AboutView()),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AboutView extends StatelessWidget {
  const _AboutView();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = context.colors;
    const sources = [
      (
        'Quran text',
        'Tanzil Project (tanzil.net), Uthmani — via api.alquran.cloud',
      ),
      ('Translation', 'Saheeh International — via api.alquran.cloud'),
      ('Tafsir', 'Al-Muyassar, Al-Jalalayn — via api.alquran.cloud'),
      ('Recitation', 'everyayah.com'),
      ('Radio', 'mp3quran.net (Qurango)'),
      ('Adhkar', 'Hisn al-Muslim — hisnmuslim.com'),
      ('99 Names', 'api.aladhan.com'),
      ('Prayer times', 'adhan (computed on the device)'),
      ('Quran font', 'Amiri Quran — SIL Open Font License'),
    ];

    return Scaffold(
      appBar: AppBar(title: Text(l10n.aboutTitle)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Center(
            child: Text(
              'Sakina · سكينة',
              style: context.texts.headlineSmall?.copyWith(
                color: scheme.primary,
              ),
            ),
          ),
          FutureBuilder<PackageInfo>(
            future: PackageInfo.fromPlatform(),
            builder: (context, snap) => Center(
              child: Text(
                snap.hasData
                    ? l10n.version(
                        '${snap.data!.version}+${snap.data!.buildNumber}',
                      )
                    : '',
                style: context.texts.bodySmall,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(l10n.aboutSources, style: context.texts.titleMedium),
          for (final (what, from) in sources)
            ListTile(
              dense: true,
              title: Text(what),
              subtitle: Text(from, textDirection: TextDirection.ltr),
            ),
        ],
      ),
    );
  }
}
