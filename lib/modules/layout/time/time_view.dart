import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
// intl also exports TextDirection, which shadows the Flutter one.
import 'package:intl/intl.dart' hide TextDirection;

import '../../../core/constants/assets.dart';
import '../../../core/services/islamic_calendar.dart';
import '../../../core/services/prayer_notification_service.dart';
import '../../../core/services/prayer_times_service.dart';
import '../../../core/state/settings_cubit.dart';
import '../../../core/state/settings_state.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/l10n_ext.dart';
import '../../../core/utils/prayer_labels.dart';
import '../../../core/widgets/app_background.dart';
import '../../settings/settings_view.dart';
import 'azkar_section.dart';
import 'location_sheet.dart';
import 'next_prayer_card.dart';
import 'qibla_view.dart';
import 'timetable_view.dart';
import 'tracker_view.dart';

/// Prayer times for a day, the countdown to the next prayer, and the way
/// into Qibla, the monthly timetable and the prayer tracker.
class TimeView extends StatefulWidget {
  const TimeView({super.key});

  @override
  State<TimeView> createState() => _TimeViewState();
}

class _TimeViewState extends State<TimeView> {
  late PrayerLocation _location;
  DateTime _day = DateTime.now();
  DateTime _now = DateTime.now();
  Timer? _ticker;
  bool _locating = false;

  @override
  void initState() {
    super.initState();
    _location = PrayerTimesService.currentLocation();
    _refreshLocation();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _refreshLocation() async {
    if (_location.isManual) return;
    setState(() => _locating = true);
    final fresh = await PrayerTimesService.refreshLocation();
    if (!mounted) return;
    setState(() {
      _location = fresh;
      _locating = false;
    });
    _rescheduleIfOn();
  }

  /// A different location moves every prayer, so the schedule is rebuilt.
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

  Future<void> _changeLocation() async {
    final changed = await LocationSheet.show(context);
    if (changed != true || !mounted) return;
    setState(() => _location = PrayerTimesService.currentLocation());
    if (!_location.isManual) await _refreshLocation();
    _rescheduleIfOn();
  }

  bool get _isToday => DateUtils.isSameDay(_day, _now);

  void _shiftDay(int days) =>
      setState(() => _day = _day.add(Duration(days: days)));

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return AppBackground(
      ornament: Assets.timeBackground,
      title: l10n.prayerTimesTitle,
      actions: [
        IconButton(
          tooltip: l10n.settings,
          icon: const Icon(Icons.settings_outlined),
          // Root navigator: Settings is reachable from several tabs.
          onPressed: () => Navigator.of(
            context,
            rootNavigator: true,
          ).push(MaterialPageRoute<void>(builder: (_) => const SettingsView())),
        ),
      ],
      child: BlocBuilder<SettingsCubit, SettingsState>(
        builder: (context, settings) {
          // For another day, compute at noon so "next prayer" is meaningless
          // and the full day shows; for today, compute at the current time.
          final date = _isToday
              ? _now
              : DateTime(_day.year, _day.month, _day.day, 12);
          final result = PrayerTimesService.computeFor(
            coordinates: _location.coordinates,
            date: date,
            config: settings.prayerConfig,
            usedFallbackLocation: _location.isFallback,
          );

          return ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.xl,
            ),
            children: [
              _LocationRow(
                location: _location,
                locating: _locating,
                onChange: _changeLocation,
              ),
              const SizedBox(height: AppSpacing.sm),
              _DayNavigator(
                day: _day,
                isToday: _isToday,
                onPrevious: () => _shiftDay(-1),
                onNext: () => _shiftDay(1),
                onToday: () => setState(() => _day = DateTime.now()),
              ),
              const SizedBox(height: AppSpacing.md),
              if (_isToday && result.next != null) ...[
                NextPrayerCard(result: result, now: _now),
                const SizedBox(height: AppSpacing.md),
              ],
              _PrayerList(
                result: result,
                highlightNext: _isToday,
                settings: settings,
              ),
              const SizedBox(height: AppSpacing.lg),
              _Shortcuts(location: _location),
              const SizedBox(height: AppSpacing.xl),
              Text(
                l10n.azkarSection,
                style: context.texts.titleMedium?.copyWith(
                  color: context.colors.onSurface,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              const AzkarSection(),
            ],
          );
        },
      ),
    );
  }
}

class _LocationRow extends StatelessWidget {
  const _LocationRow({
    required this.location,
    required this.locating,
    required this.onChange,
  });

  final PrayerLocation location;
  final bool locating;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = context.colors;
    final String label;
    if (locating && location.isFallback) {
      label = l10n.locating;
    } else if (location.isFallback) {
      label = l10n.defaultLocation;
    } else {
      label = location.name?.isNotEmpty == true
          ? location.name!
          : '${location.coordinates.latitude.toStringAsFixed(2)}, '
                '${location.coordinates.longitude.toStringAsFixed(2)}';
    }

    return Row(
      children: [
        Icon(
          location.isManual ? Icons.location_city : Icons.my_location,
          size: 18,
          color: scheme.primary,
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.texts.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
        if (locating)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        TextButton(onPressed: onChange, child: Text(l10n.changeLocation)),
      ],
    );
  }
}

class _DayNavigator extends StatelessWidget {
  const _DayNavigator({
    required this.day,
    required this.isToday,
    required this.onPrevious,
    required this.onNext,
    required this.onToday,
  });

  final DateTime day;
  final bool isToday;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onToday;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final hijri = IslamicCalendar.of(
      day,
      offset: context.watch<SettingsCubit>().state.hijriOffset,
    );

    return Card(
      color: scheme.surfaceContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          children: [
            IconButton(
              onPressed: onPrevious,
              icon: const Icon(Icons.chevron_left),
              tooltip: MaterialLocalizations.of(context).previousPageTooltip,
            ),
            Expanded(
              child: Column(
                children: [
                  Text(
                    DateFormat.yMMMMEEEEd(locale).format(day),
                    textAlign: TextAlign.center,
                    style: context.texts.titleSmall,
                  ),
                  Text(
                    '${hijri.hDay} ${hijri.longMonthName} ${hijri.hYear}',
                    textAlign: TextAlign.center,
                    style: context.texts.bodySmall?.copyWith(
                      color: scheme.primary,
                    ),
                  ),
                  if (!isToday)
                    TextButton(
                      onPressed: onToday,
                      child: Text(context.l10n.today),
                    ),
                ],
              ),
            ),
            IconButton(
              onPressed: onNext,
              icon: const Icon(Icons.chevron_right),
              tooltip: MaterialLocalizations.of(context).nextPageTooltip,
            ),
          ],
        ),
      ),
    );
  }
}

class _PrayerList extends StatelessWidget {
  const _PrayerList({
    required this.result,
    required this.highlightNext,
    required this.settings,
  });

  final PrayerTimesResult result;
  final bool highlightNext;
  final SettingsState settings;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final cubit = context.read<SettingsCubit>();

    return Card(
      color: scheme.surfaceContainerLow,
      child: Column(
        children: [
          for (final entry in result.prayers)
            Builder(
              builder: (context) {
                final isNext =
                    highlightNext &&
                    result.next != null &&
                    entry.time == result.next!.time;
                final canNotify = entry.prayer != PrayerName.sunrise;
                final notified =
                    settings.prayerNotifications &&
                    settings.notifiedPrayers.contains(entry.prayer);

                return Container(
                  decoration: isNext
                      ? BoxDecoration(
                          color: scheme.secondaryContainer,
                          borderRadius: AppRadius.cardRadius,
                        )
                      : null,
                  child: ListTile(
                    leading: Icon(_icon(entry.prayer), color: scheme.primary),
                    title: Text(
                      prayerLabel(context, entry.prayer),
                      style: TextStyle(
                        fontWeight: isNext ? FontWeight.w700 : null,
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          DateFormat.jm(locale).format(entry.time),
                          style: context.texts.titleMedium?.copyWith(
                            fontWeight: isNext ? FontWeight.w700 : null,
                          ),
                        ),
                        if (canNotify)
                          IconButton(
                            tooltip: context.l10n.notifyPrayer,
                            icon: Icon(
                              notified
                                  ? Icons.notifications_active
                                  : Icons.notifications_off_outlined,
                              color: notified ? scheme.primary : scheme.outline,
                            ),
                            onPressed: () {
                              if (!settings.prayerNotifications) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      context.l10n.notificationsOffHint,
                                    ),
                                  ),
                                );
                                return;
                              }
                              cubit.togglePrayerNotification(entry.prayer);
                            },
                          )
                        else
                          const SizedBox(width: 48),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  static IconData _icon(PrayerName p) => switch (p) {
    PrayerName.fajr => Icons.nights_stay_outlined,
    PrayerName.sunrise => Icons.wb_twilight,
    PrayerName.dhuhr => Icons.wb_sunny_outlined,
    PrayerName.asr => Icons.wb_cloudy_outlined,
    PrayerName.maghrib => Icons.wb_twilight_outlined,
    PrayerName.isha => Icons.bedtime_outlined,
  };
}

class _Shortcuts extends StatelessWidget {
  const _Shortcuts({required this.location});

  final PrayerLocation location;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    Widget tile(IconData icon, String label, WidgetBuilder builder) => Expanded(
      child: Card(
        color: context.colors.surfaceContainer,
        child: InkWell(
          borderRadius: AppRadius.cardRadius,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute<void>(builder: builder),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
            child: Column(
              children: [
                Icon(icon, color: context.colors.primary),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: context.texts.labelMedium,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    return Row(
      children: [
        tile(
          Icons.explore_outlined,
          l10n.qiblaTitle,
          (_) => QiblaView(location: location),
        ),
        const SizedBox(width: AppSpacing.sm),
        tile(
          Icons.calendar_month_outlined,
          l10n.monthlyTimetable,
          (_) => TimetableView(location: location),
        ),
        const SizedBox(width: AppSpacing.sm),
        tile(
          Icons.check_circle_outline,
          l10n.prayerTracker,
          (_) => const TrackerView(),
        ),
      ],
    );
  }
}
