import 'dart:async';

import 'package:adhan/adhan.dart' show Coordinates;
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
// intl also exports TextDirection, which shadows the Flutter one.
import 'package:intl/intl.dart' hide TextDirection;

import '../../core/constants/assets.dart';
import '../../core/constants/constants.dart';
import '../../core/constants/daily_verses.dart';
import '../../core/constants/prefs_keys.dart';
import '../../core/constants/quran_duas.dart';
import '../../core/services/azkar_progress.dart';
import '../../core/services/hadeth_service.dart';
import '../../core/services/islamic_calendar.dart';
import '../../core/services/mushaf_layout.dart';
import '../../core/services/notification_refresh.dart';
import '../../core/services/prayer_times_service.dart';
import '../../core/services/quran_service.dart';
import '../../core/services/recent_suras.dart';
import '../../core/services/shared_prefs_helper.dart';
import '../../core/state/settings_cubit.dart';
import '../../core/state/settings_state.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/arabic_text.dart';
import '../../core/utils/l10n_ext.dart';
import '../../core/utils/prayer_labels.dart';
import '../../core/services/khatma.dart';
import '../../core/widgets/app_background.dart';
import '../../core/widgets/fade_slide_in.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../models/hadeth_data_model.dart';
import '../../models/sura_data_model.dart';
import '../../models/zikr_model.dart';
import '../layout/azkar/azkar_view.dart';
import '../layout/hadeth/hadeth_details_view.dart';
import '../layout/layout_scope.dart';
import '../layout/quran/quran_view.dart';
import '../layout/tasbeh/tasbeh_view.dart';
import '../layout/time/next_prayer_card.dart';
import '../layout/time/qibla_view.dart';
import '../more/duas_view.dart';
import '../settings/prayer_notifications_prompt.dart';
import '../settings/settings_view.dart';
import 'khatma_card.dart';

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
  late Future<HadethDataModel?> _hadeth = _hadethOfTheDay();
  bool _remindersDismissed = LocalStorageServices.getBool(PrefsKeys.remindersCardDismissed) ?? false;

  /// When Home was first built, and how long after that its cards ease in.
  final DateTime _openedAt = DateTime.now();
  static const Duration _entrance = Duration(seconds: 1);
  int _hadethDay = dayNumber(DateTime.now());

  @override
  void initState() {
    super.initState();
    _location = PrayerTimesService.currentLocation();
    if (!_location.isManual) _refreshLocation();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      // Home stays mounted behind the other tabs; only tick while visible.
      if (mounted && _visible) setState(_tick);
    });
  }

  /// Moves the clock on, and with it the hadith of the day when the app has
  /// stayed open past midnight.
  void _tick() {
    _now = DateTime.now();
    final day = dayNumber(_now);
    if (day != _hadethDay) {
      _hadethDay = day;
      _hadeth = _hadethOfTheDay();
    }
  }

  bool _visible = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // IndexedStack turns TickerMode off for hidden tabs, which lands here.
    final visible = TickerMode.valuesOf(context).enabled;
    if (visible && !_visible) {
      _tick();
      // A city chosen on the Prayer tab while this one was hidden.
      final saved = PrayerTimesService.currentLocation();
      if (saved.isManual != _location.isManual ||
          saved.isFallback != _location.isFallback ||
          !_same(saved.coordinates, _location.coordinates)) {
        _location = saved;
      }
    }
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
    if (!_same(before, fresh.coordinates)) _reschedule();
  }

  static bool _same(Coordinates a, Coordinates b) =>
      (a.latitude - b.latitude).abs() < 1e-4 &&
      (a.longitude - b.longitude).abs() < 1e-4;

  /// The prayer alerts and the widget's times were for the old position.
  void _reschedule() {
    final s = context.read<SettingsCubit>().state;
    NotificationRefresh.reschedule(s, Localizations.localeOf(context));
  }

  static Future<HadethDataModel?> _hadethOfTheDay() async {
    return HadethService.ofDay(await HadethService.loadAll(), DateTime.now());
  }

  void _push(Widget page, {String? name}) => Navigator.push(
    context,
    MaterialPageRoute<void>(
      settings: RouteSettings(name: name),
      builder: (_) => page,
    ),
  );

  void _openSura(SuraDataModel sura, {int? ayah, int? page}) {
    final scope = LayoutScope.maybeOf(context);
    if (scope != null) {
      scope.openSura(sura, ayah: ayah, page: page);
    } else {
      openSura(context, sura, ayah: ayah, page: page);
    }
  }

  /// Opens the mushaf at a 1-based [page].
  Future<void> _openPage(int page) async {
    final layout = await MushafLayout.load();
    if (!mounted) return;
    final p = page.clamp(1, MushafLayout.pageCount);
    _openSura(Constants.suraDataLists[layout.firstWord(p).sura - 1], page: p);
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

          // On a tablet the cards keep a readable width instead of
          // stretching edge to edge.
          final side = ((MediaQuery.sizeOf(context).width - 720) / 2)
              .clamp(AppSpacing.lg, double.infinity);
          // Each card arrives a moment after the one above it, once: when
          // Home first opens, not again as a card scrolls back into view.
          var order = 0;
          final entering = DateTime.now().difference(_openedAt) < _entrance;
          Widget enter(Widget child) => FadeSlideIn(index: order++, animate: entering, child: child);

          return ListView(
            padding: EdgeInsets.fromLTRB(side, 0, side, AppSpacing.xl),
            children: [
              enter(_DateHeader(now: _now, hijriOffset: offset)),
              const SizedBox(height: AppSpacing.sm),
              // The next prayer and the rest of today's, in one card.
              enter(
                NextPrayerCard(
                  result: result,
                  now: _now,
                  subtitle: _location.isFallback
                      ? l10n.defaultLocation
                      : _location.name,
                  onTap: () =>
                      LayoutScope.maybeOf(context)?.selectTab(AppTab.prayer),
                  footer: _TodayPrayers(result: result, now: _now),
                ),
              ),
              // At most one notice at a time, the most pressing first.
              enter(
                AnimatedSize(
                  duration: AppDurations.normal,
                  curve: Curves.easeOut,
                  alignment: Alignment.topCenter,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: _notice(context, settings, result, ramadanDay, offset),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              enter(
                _QuickGrid(
                  tiles: [
                    _Tile(
                      Icons.explore_outlined,
                      l10n.qiblaTitle,
                      () => _push(QiblaView(location: _location)),
                    ),
                    _Tile(
                      AzkarProgress.isMorning(_now)
                          ? Icons.wb_sunny_outlined
                          : Icons.nights_stay_outlined,
                      AzkarProgress.isMorning(_now)
                          ? l10n.morningAzkarNow
                          : l10n.eveningAzkarNow,
                      () => _push(
                        const AzkarView(chapterId: FeaturedAzkar.morningEvening),
                      ),
                    ),
                    _Tile(
                      Icons.radio_button_checked_outlined,
                      l10n.tasbehTitle,
                      () => _push(const TasbehView()),
                    ),
                    _Tile(
                      Icons.volunteer_activism_outlined,
                      l10n.duasTitle,
                      () => _push(const DuasView()),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              enter(_QuranCard(now: _now, onOpenSura: _openSura, onOpenPage: _openPage)),
              const SizedBox(height: AppSpacing.lg),
              enter(
                _DailyInspiration(
                  verse: _VerseOfTheDay(
                    // Keyed by the verse so a new day loads a new one.
                    key: ValueKey(DailyVerses.forDay(_now).label),
                    dua: DailyVerses.forDay(_now),
                    onOpen: (sura, ayah) => _openSura(sura, ayah: ayah),
                  ),
                  hadith: _HadithOfTheDay(
                    hadeth: _hadeth,
                    onOpen: (h) => _push(HadethDetailsView(hadeth: h)),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// The one notice Home shows, if any: Ramadan's times, then the invitation
  /// to turn reminders on, then a fasting day coming up.
  List<Widget> _notice(
    BuildContext context,
    SettingsState settings,
    PrayerTimesResult result,
    int? ramadanDay,
    int offset,
  ) {
    if (ramadanDay != null) {
      return [
        const SizedBox(height: AppSpacing.md),
        _RamadanCard(day: ramadanDay, result: result, now: _now),
      ];
    }
    if (!settings.prayerNotifications && !_remindersDismissed) {
      return [
        _RemindersCard(
          onDismiss: () {
            setState(() => _remindersDismissed = true);
            LocalStorageServices.setBool(PrefsKeys.remindersCardDismissed, true);
          },
        ),
      ];
    }
    return _fastingHint(context, offset);
  }

  /// Sunday and Wednesday evenings remind of the Monday/Thursday fast; the
  /// 12th–15th of the Hijri month of the White Days.
  List<Widget> _fastingHint(BuildContext context, int offset) {
    final l10n = context.l10n;
    final hijriDay = IslamicCalendar.of(_now, offset: offset).hDay;
    // The next calendar day, not 24 hours on, which a clock change can put
    // on the day after.
    final tomorrow = DateTime(_now.year, _now.month, _now.day + 1);
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

}

/// Morning until noon, afternoon until five, evening after that.
String greetingFor(AppLocalizations l10n, DateTime now) => switch (now.hour) {
  < 12 => l10n.greetingMorning,
  < 17 => l10n.greetingAfternoon,
  _ => l10n.greetingEvening,
};

/// Invites a reader whose reminders are off to turn them on: without them
/// there is no adhan and no hadith of the day. Put away for good by "Not now";
/// Settings still has the switch.
class _RemindersCard extends StatelessWidget {
  const _RemindersCard({required this.onDismiss});

  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = context.colors;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: Card(
        color: scheme.primaryContainer,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.notifications_active_outlined, color: scheme.onPrimaryContainer),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      l10n.remindersCardTitle,
                      style: context.texts.titleMedium?.copyWith(color: scheme.onPrimaryContainer),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                l10n.remindersCardBody,
                style: context.texts.bodyMedium?.copyWith(color: scheme.onPrimaryContainer),
              ),
              const SizedBox(height: AppSpacing.sm),
              OverflowBar(
                alignment: MainAxisAlignment.end,
                spacing: AppSpacing.sm,
                children: [
                  TextButton(onPressed: onDismiss, child: Text(l10n.remindersCardLater)),
                  FilledButton(
                    onPressed: () => turnOnPrayerNotifications(context),
                    child: Text(l10n.remindersCardAction),
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
            greetingFor(l10n, now),
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
    // An icon and up to two lines of label. The height follows the phone's
    // font size rather than the tile's width, so a large font is not cut off.
    final labelStyle = context.texts.labelSmall;
    final lineHeight = (labelStyle?.fontSize ?? 11) * (labelStyle?.height ?? 1.45);
    final labelHeight = MediaQuery.textScalerOf(context).scale(lineHeight * 2);
    return GridView(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisExtent: 48 + AppSpacing.xs * 3 + labelHeight.ceilToDouble() + 2,
      ),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
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
                    style: labelStyle,
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

/// The reader's Quran in one card: today's khatma portion while a khatma is
/// under way (or its celebration once finished), otherwise the sura they were last reading, otherwise an
/// invitation to start a khatma.
class _QuranCard extends StatelessWidget {
  const _QuranCard({
    required this.now,
    required this.onOpenSura,
    required this.onOpenPage,
  });

  final DateTime now;
  final void Function(SuraDataModel sura) onOpenSura;
  final ValueChanged<int> onOpenPage;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<KhatmaPlan?>(
      valueListenable: Khatma.notifier,
      builder: (context, plan, _) => ValueListenableBuilder<List<SuraDataModel>>(
        valueListenable: RecentSuras.notifier,
        builder: (context, recent, _) {
          final Widget child;
          if (plan != null || recent.isEmpty) {
            child = KhatmaCard(now: now, onOpenPage: onOpenPage);
          } else {
            final sura = recent.first;
            child = Card(
              color: context.colors.surfaceContainer,
              child: ListTile(
                leading: Icon(
                  Icons.auto_stories_outlined,
                  color: context.colors.primary,
                ),
                title: Text(context.l10n.continueWhereLeft),
                subtitle: Text(
                  context.isArabic ? sura.suraNameAR : sura.suraNameEN,
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => onOpenSura(sura),
              ),
            );
          }
          return AnimatedSwitcher(duration: AppDurations.normal, child: child);
        },
      ),
    );
  }
}

/// The verse and the hadith of the day, one at a time, swapped with a tap.
class _DailyInspiration extends StatefulWidget {
  const _DailyInspiration({required this.verse, required this.hadith});

  final Widget verse;
  final Widget hadith;

  @override
  State<_DailyInspiration> createState() => _DailyInspirationState();
}

class _DailyInspirationState extends State<_DailyInspiration> {
  bool _hadith = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<bool>(
          showSelectedIcon: false,
          segments: [
            ButtonSegment(
              value: false,
              icon: const Icon(Icons.menu_book_outlined),
              label: Text(l10n.verseOfTheDay, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            ButtonSegment(
              value: true,
              icon: const Icon(Icons.format_quote_outlined),
              label: Text(l10n.hadethOfTheDay, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ],
          selected: {_hadith},
          onSelectionChanged: (s) => setState(() => _hadith = s.first),
        ),
        const SizedBox(height: AppSpacing.sm),
        AnimatedSize(
          duration: AppDurations.normal,
          curve: Curves.easeOut,
          alignment: Alignment.topCenter,
          child: AnimatedSwitcher(
            duration: AppDurations.normal,
            layoutBuilder: (current, previous) => Stack(
              alignment: Alignment.topCenter,
              children: [...previous, ?current],
            ),
            child: KeyedSubtree(
              key: ValueKey(_hadith),
              child: _hadith ? widget.hadith : widget.verse,
            ),
          ),
        ),
      ],
    );
  }
}

class _HadithOfTheDay extends StatelessWidget {
  const _HadithOfTheDay({required this.hadeth, required this.onOpen});

  final Future<HadethDataModel?> hadeth;
  final ValueChanged<HadethDataModel> onOpen;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<HadethDataModel?>(
      future: hadeth,
      builder: (context, snap) {
        final h = snap.data;
        if (h == null) return const SizedBox(height: 120);
        return Card(
          color: context.colors.surfaceContainerLow,
          child: InkWell(
            borderRadius: AppRadius.cardRadius,
            onTap: () => onOpen(h),
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
                    maxLines: 5,
                    overflow: TextOverflow.ellipsis,
                    style: context.texts.bodyLarge?.copyWith(height: 1.7),
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
