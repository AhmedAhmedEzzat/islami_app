import 'dart:async';

import 'package:adhan/adhan.dart' show Coordinates;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
// intl also exports TextDirection, which shadows the Flutter one.
import 'package:intl/intl.dart' hide TextDirection;

import '../../core/constants/assets.dart';
import '../../core/constants/daily_verses.dart';
import '../../core/constants/quran_duas.dart';
import '../../core/services/hadeth_service.dart';
import '../../core/services/islamic_calendar.dart';
import '../../core/services/prayer_notification_service.dart';
import '../../core/services/prayer_times_service.dart';
import '../../core/services/quran_service.dart';
import '../../core/services/recent_suras.dart';
import '../../core/state/settings_cubit.dart';
import '../../core/state/settings_state.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/arabic_text.dart';
import '../../core/utils/l10n_ext.dart';
import '../../core/utils/prayer_labels.dart';
import '../../core/widgets/app_background.dart';
import '../../models/hadeth_data_model.dart';
import '../../models/sura_data_model.dart';
import '../../models/zikr_model.dart';
import '../layout/azkar/azkar_view.dart';
import '../layout/hadeth/hadeth_details_view.dart';
import '../layout/layout_scope.dart';
import '../layout/quran/quran_view.dart';
import '../layout/radio/radio_view.dart';
import '../layout/tasbeh/tasbeh_view.dart';
import '../layout/time/next_prayer_card.dart';
import '../layout/time/qibla_view.dart';
import '../layout/time/tracker_view.dart';
import '../more/calendar_view.dart';
import '../more/duas_view.dart';
import '../more/names_view.dart';
import '../settings/settings_view.dart';

/// The first tab: today at a glance and one tap to everything daily.
class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  late PrayerLocation _location;
  DateTime _now = DateTime.now();
  Timer? _ticker;
  late final Future<HadethDataModel?> _hadeth = _hadethOfTheDay();

  @override
  void initState() {
    super.initState();
    _location = PrayerTimesService.currentLocation();
    if (!_location.isManual) _refreshLocation();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      // Home stays mounted behind the other tabs; only tick while visible.
      if (mounted && _visible) setState(() => _now = DateTime.now());
    });
  }

  bool _visible = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // IndexedStack turns TickerMode off for hidden tabs, which lands here.
    final visible = TickerMode.valuesOf(context).enabled;
    if (visible && !_visible) _now = DateTime.now();
    _visible = visible;
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _refreshLocation() async {
    final before = _location.coordinates;
    final fresh = await PrayerTimesService.refreshLocation();
    if (!mounted) return;
    setState(() => _location = fresh);
    if (!_same(before, fresh.coordinates)) _rescheduleIfOn();
  }

  static bool _same(Coordinates a, Coordinates b) =>
      (a.latitude - b.latitude).abs() < 1e-4 &&
      (a.longitude - b.longitude).abs() < 1e-4;

  /// The prayer alerts were planned for the old position.
  void _rescheduleIfOn() {
    final s = context.read<SettingsCubit>().state;
    if (!s.prayerNotifications) return;
    PrayerNotificationService.reschedule(
      enabled: true,
      locale: Localizations.localeOf(context),
      config: s.prayerConfig,
      prayers: s.notifiedPrayers,
      reminderMinutes: s.reminderMinutes,
      fridayKahf: s.fridayKahf,
    );
  }

  static Future<HadethDataModel?> _hadethOfTheDay() async {
    final all = await HadethService.loadAll();
    if (all.isEmpty) return null;
    return all[dayNumber(DateTime.now()) % all.length];
  }

  void _push(Widget page, {String? name}) => Navigator.push(
    context,
    MaterialPageRoute<void>(
      settings: RouteSettings(name: name),
      builder: (_) => page,
    ),
  );

  void _openSura(SuraDataModel sura, {int? ayah}) {
    final scope = LayoutScope.maybeOf(context);
    if (scope != null) {
      scope.openSura(sura, ayah: ayah);
    } else {
      openSura(context, sura, ayah: ayah);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return AppBackground(
      ornament: Assets.quranBackground,
      title: l10n.assalamu,
      actions: [
        IconButton(
          tooltip: l10n.settings,
          icon: const Icon(Icons.settings_outlined),
          onPressed: () => Navigator.of(
            context,
            rootNavigator: true,
          ).push(MaterialPageRoute<void>(builder: (_) => const SettingsView())),
        ),
      ],
      child: BlocBuilder<SettingsCubit, SettingsState>(
        builder: (context, settings) {
          final result = PrayerTimesService.computeFor(
            coordinates: _location.coordinates,
            date: _now,
            config: settings.prayerConfig,
            usedFallbackLocation: _location.isFallback,
          );
          final offset = settings.hijriOffset;
          final ramadanDay = IslamicCalendar.ramadanDay(_now, offset: offset);

          return ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.xl,
            ),
            children: [
              _DateHeader(now: _now, hijriOffset: offset),
              const SizedBox(height: AppSpacing.md),
              NextPrayerCard(
                result: result,
                now: _now,
                subtitle: _location.isFallback
                    ? l10n.defaultLocation
                    : _location.name,
                onTap: () =>
                    LayoutScope.maybeOf(context)?.selectTab(AppTab.prayer),
              ),
              const SizedBox(height: AppSpacing.sm),
              _TodayPrayers(result: result, now: _now),
              if (ramadanDay != null) ...[
                const SizedBox(height: AppSpacing.md),
                _RamadanCard(day: ramadanDay, result: result, now: _now),
              ],
              ..._fastingHint(context, offset),
              const SizedBox(height: AppSpacing.md),
              ValueListenableBuilder<List<SuraDataModel>>(
                valueListenable: RecentSuras.notifier,
                builder: (context, recent, _) {
                  if (recent.isEmpty) return const SizedBox.shrink();
                  final sura = recent.first;
                  return Card(
                    color: context.colors.surfaceContainer,
                    child: ListTile(
                      leading: Icon(
                        Icons.auto_stories_outlined,
                        color: context.colors.primary,
                      ),
                      title: Text(l10n.continueWhereLeft),
                      subtitle: Text(
                        context.isArabic ? sura.suraNameAR : sura.suraNameEN,
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _openSura(sura),
                    ),
                  );
                },
              ),
              const SizedBox(height: AppSpacing.lg),
              _SectionTitle(l10n.quickAccess),
              _QuickGrid(
                tiles: [
                  _Tile(
                    Icons.explore_outlined,
                    l10n.qiblaTitle,
                    () => _push(QiblaView(location: _location)),
                  ),
                  _Tile(
                    Icons.radio_button_checked_outlined,
                    l10n.tasbehTitle,
                    () => _push(const TasbehView()),
                  ),
                  _Tile(
                    _now.hour < 12
                        ? Icons.wb_sunny_outlined
                        : Icons.nights_stay_outlined,
                    _now.hour < 12
                        ? l10n.morningAzkarNow
                        : l10n.eveningAzkarNow,
                    () => _push(
                      const AzkarView(chapterId: FeaturedAzkar.morningEvening),
                    ),
                  ),
                  _Tile(
                    Icons.volunteer_activism_outlined,
                    l10n.duasTitle,
                    () => _push(const DuasView()),
                  ),
                  _Tile(
                    Icons.auto_awesome_outlined,
                    l10n.namesTitle,
                    () => _push(const NamesView()),
                  ),
                  _Tile(
                    Icons.calendar_month_outlined,
                    l10n.calendarTitle,
                    () => _push(const CalendarView()),
                  ),
                  _Tile(
                    Icons.radio_outlined,
                    l10n.radioTitle,
                    () => _push(const RadioView(), name: RadioView.routeName),
                  ),
                  _Tile(
                    Icons.check_circle_outline,
                    l10n.prayerTracker,
                    () => _push(const TrackerView()),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              _SectionTitle(l10n.verseOfTheDay),
              _VerseOfTheDay(
                // Keyed by the verse so a new day loads a new one.
                key: ValueKey(DailyVerses.forDay(_now).label),
                dua: DailyVerses.forDay(_now),
                onOpen: (sura, ayah) => _openSura(sura, ayah: ayah),
              ),
              const SizedBox(height: AppSpacing.lg),
              _SectionTitle(l10n.hadethOfTheDay),
              FutureBuilder<HadethDataModel?>(
                future: _hadeth,
                builder: (context, snap) {
                  final h = snap.data;
                  if (h == null) return const SizedBox(height: 80);
                  return Card(
                    color: context.colors.surfaceContainerLow,
                    child: InkWell(
                      borderRadius: AppRadius.cardRadius,
                      onTap: () => _push(HadethDetailsView(hadeth: h)),
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              h.title,
                              textDirection: TextDirection.rtl,
                              style: context.texts.titleMedium?.copyWith(
                                color: context.colors.primary,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              h.content.join(' '),
                              textDirection: TextDirection.rtl,
                              maxLines: 4,
                              overflow: TextOverflow.ellipsis,
                              style: context.texts.bodyLarge?.copyWith(
                                height: 1.7,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
              ..._nextEvent(context, offset),
            ],
          );
        },
      ),
    );
  }

  /// Sunday and Wednesday evenings remind of the Monday/Thursday fast; the
  /// 12th–15th of the Hijri month of the White Days.
  List<Widget> _fastingHint(BuildContext context, int offset) {
    final l10n = context.l10n;
    final hijriDay = IslamicCalendar.of(_now, offset: offset).hDay;
    final tomorrow = _now.add(const Duration(days: 1));
    final String? text;
    if (hijriDay >= 12 && hijriDay <= 15) {
      text = l10n.whiteDays;
    } else if (tomorrow.weekday == DateTime.monday ||
        tomorrow.weekday == DateTime.thursday) {
      final locale = Localizations.localeOf(context).toLanguageTag();
      text = l10n.fastTomorrow(DateFormat.EEEE(locale).format(tomorrow));
    } else {
      text = null;
    }
    if (text == null) return const [];
    return [
      const SizedBox(height: AppSpacing.sm),
      Card(
        color: context.colors.tertiaryContainer,
        child: ListTile(
          dense: true,
          leading: Icon(
            Icons.restaurant_outlined,
            color: context.colors.onTertiaryContainer,
          ),
          title: Text(
            text,
            style: TextStyle(color: context.colors.onTertiaryContainer),
          ),
        ),
      ),
    ];
  }

  List<Widget> _nextEvent(BuildContext context, int offset) {
    final upcoming = IslamicCalendar.upcoming(_now, offset: offset, count: 1);
    if (upcoming.isEmpty) return const [];
    final next = upcoming.first;
    return [
      const SizedBox(height: AppSpacing.md),
      Card(
        color: context.colors.surfaceContainer,
        child: ListTile(
          leading: Icon(Icons.event_outlined, color: context.colors.primary),
          title: Text(eventLabel(context, next.event)),
          subtitle: Text(context.l10n.inDays(next.daysFrom(_now))),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _push(const CalendarView()),
        ),
      ),
    ];
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: Text(
      text,
      style: context.texts.titleMedium?.copyWith(
        color: context.colors.onSurface,
      ),
    ),
  );
}

class _DateHeader extends StatelessWidget {
  const _DateHeader({required this.now, required this.hijriOffset});

  final DateTime now;
  final int hijriOffset;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = context.colors;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final hijri = IslamicCalendar.of(now, offset: hijriOffset);
    final hijriText = context.isArabic
        ? '${ArabicText.digits(hijri.hDay)} ${hijri.longMonthName} ${ArabicText.digits(hijri.hYear)}'
        : '${hijri.hDay} ${hijri.longMonthName} ${hijri.hYear}';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            now.hour < 12 ? l10n.greetingMorning : l10n.greetingEvening,
            style: context.texts.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          Text(
            hijriText,
            style: context.texts.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: scheme.primary,
            ),
          ),
          Text(
            DateFormat.yMMMMEEEEd(locale).format(now),
            style: context.texts.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// The five daily prayers in one row, the next one picked out.
class _TodayPrayers extends StatelessWidget {
  const _TodayPrayers({required this.result, required this.now});

  final PrayerTimesResult result;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final next = result.next;

    return Card(
      color: scheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.md,
          horizontal: AppSpacing.xs,
        ),
        child: Row(
          children: [
            for (final p in result.prayers.where(
              (p) => p.prayer != PrayerName.sunrise,
            ))
              Expanded(
                child: Builder(
                  builder: (context) {
                    final isNext =
                        next != null &&
                        next.prayer == p.prayer &&
                        next.time == p.time;
                    final passed = !p.time.isAfter(now);
                    final color = isNext
                        ? scheme.primary
                        : passed
                        ? scheme.onSurfaceVariant
                        : scheme.onSurface;
                    return Column(
                      children: [
                        Text(
                          prayerLabel(context, p.prayer),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.texts.labelMedium?.copyWith(
                            color: color,
                            fontWeight: isNext ? FontWeight.w700 : null,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        FittedBox(
                          child: Text(
                            DateFormat.jm(locale).format(p.time),
                            style: context.texts.bodySmall?.copyWith(
                              color: color,
                              fontWeight: isNext ? FontWeight.w700 : null,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Imsak (ten minutes before Fajr, as the printed Ramadan timetables have it)
/// and Iftar at Maghrib, with a countdown to Iftar during the fast.
class _RamadanCard extends StatelessWidget {
  const _RamadanCard({
    required this.day,
    required this.result,
    required this.now,
  });

  final int day;
  final PrayerTimesResult result;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = context.colors;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final fajr = result.entry(PrayerName.fajr).time;
    final iftar = result.entry(PrayerName.maghrib).time;
    final imsak = fajr.subtract(const Duration(minutes: 10));
    final fasting = now.isAfter(fajr) && now.isBefore(iftar);

    Widget cell(String label, DateTime t) => Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: context.texts.labelLarge?.copyWith(
              color: scheme.onSecondaryContainer,
            ),
          ),
          Text(
            DateFormat.jm(locale).format(t),
            style: context.texts.titleLarge?.copyWith(
              color: scheme.onSecondaryContainer,
            ),
          ),
        ],
      ),
    );

    return Card(
      color: scheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: [
            Text(
              l10n.ramadanDay(day),
              style: context.texts.titleMedium?.copyWith(
                color: scheme.onSecondaryContainer,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(children: [cell(l10n.imsak, imsak), cell(l10n.iftar, iftar)]),
            if (fasting) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                l10n.iftarIn(formatCountdown(iftar.difference(now))),
                style: context.texts.bodyMedium?.copyWith(
                  color: scheme.onSecondaryContainer,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Tile {
  const _Tile(this.icon, this.label, this.onTap);

  final IconData icon;
  final String label;
  final VoidCallback onTap;
}

class _QuickGrid extends StatelessWidget {
  const _QuickGrid({required this.tiles});

  final List<_Tile> tiles;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 0.82,
      children: [
        for (final t in tiles)
          InkWell(
            borderRadius: AppRadius.cardRadius,
            onTap: t.onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: scheme.primaryContainer,
                    child: Icon(t.icon, color: scheme.onPrimaryContainer),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    t.label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.texts.labelSmall,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _VerseOfTheDay extends StatefulWidget {
  const _VerseOfTheDay({super.key, required this.dua, required this.onOpen});

  final QuranDua dua;
  final void Function(SuraDataModel sura, int ayah) onOpen;

  @override
  State<_VerseOfTheDay> createState() => _VerseOfTheDayState();
}

class _VerseOfTheDayState extends State<_VerseOfTheDay> {
  late final Future<(List<String>, List<String>)> _text = _load();

  Future<(List<String>, List<String>)> _load() async {
    final d = widget.dua;
    final id = '${d.sura}';
    final arabic = await QuranService.loadSura(id);
    List<String> english = const [];
    try {
      english = await QuranService.loadTranslation(id);
    } catch (_) {}
    List<String> slice(List<String> all) =>
        all.length >= d.to ? all.sublist(d.from - 1, d.to) : const [];
    return (slice(arabic), slice(english));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final d = widget.dua;

    return FutureBuilder<(List<String>, List<String>)>(
      future: _text,
      builder: (context, snap) {
        final data = snap.data;
        if (data == null || data.$1.isEmpty) return const SizedBox(height: 120);
        final (arabic, english) = data;
        final verses = [
          for (var i = 0; i < arabic.length; i++)
            '${arabic[i]} ﴿${ArabicText.digits(d.from + i)}﴾',
        ].join(' ');

        return Card(
          color: scheme.surfaceContainerLow,
          child: InkWell(
            borderRadius: AppRadius.cardRadius,
            onTap: () => widget.onOpen(suraByNumber(d.sura), d.from),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    verses,
                    textAlign: TextAlign.center,
                    textDirection: TextDirection.rtl,
                    style: TextStyle(
                      fontFamily: 'AmiriQuran',
                      fontSize: 22,
                      height: 2.1,
                      color: scheme.onSurface,
                    ),
                  ),
                  if (!context.isArabic && english.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      english.join(' '),
                      textAlign: TextAlign.center,
                      style: context.texts.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    '${suraName(context, d.sura)} · ${d.label}',
                    textAlign: TextAlign.center,
                    style: context.texts.labelMedium?.copyWith(
                      color: scheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
