import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../core/services/islamic_calendar.dart';
import '../../core/state/settings_cubit.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/l10n_ext.dart';

String eventLabel(BuildContext context, IslamicEvent e) {
  final l10n = context.l10n;
  return switch (e) {
    IslamicEvent.newYear => l10n.eventNewYear,
    IslamicEvent.ashura => l10n.eventAshura,
    IslamicEvent.ramadan => l10n.eventRamadan,
    IslamicEvent.lastTenNights => l10n.eventLastTen,
    IslamicEvent.eidFitr => l10n.eventEidFitr,
    IslamicEvent.dhulHijjah => l10n.eventDhulHijjah,
    IslamicEvent.arafah => l10n.eventArafah,
    IslamicEvent.eidAdha => l10n.eventEidAdha,
  };
}

/// A Hijri month grid with its Gregorian dates, occasions and White Days.
class CalendarView extends StatefulWidget {
  const CalendarView({super.key});

  @override
  State<CalendarView> createState() => _CalendarViewState();
}

class _CalendarViewState extends State<CalendarView> {
  int? _year;
  int? _month;

  void _shift(int months) {
    var m = _month! + months;
    var y = _year!;
    if (m < 1) {
      m = 12;
      y--;
    } else if (m > 12) {
      m = 1;
      y++;
    }
    setState(() {
      _year = y;
      _month = m;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = context.colors;
    final offset = context.watch<SettingsCubit>().state.hijriOffset;
    final today = DateUtils.dateOnly(DateTime.now());
    final todayHijri = IslamicCalendar.of(today, offset: offset);
    final year = _year ??= todayHijri.hYear;
    final month = _month ??= todayHijri.hMonth;
    final locale = Localizations.localeOf(context).toLanguageTag();

    final days = IslamicCalendar.daysInMonth(year, month);
    final first = IslamicCalendar.toGregorian(year, month, 1, offset: offset);
    final firstDayIndex = MaterialLocalizations.of(context).firstDayOfWeekIndex;
    // Columns are weekdays starting from the locale's first day.
    final leading = (first.weekday % 7 - firstDayIndex) % 7;
    final weekdayNames = MaterialLocalizations.of(context).narrowWeekdays;
    final monthName = (HijriCalendar()..hMonth = month).getLongMonthName();

    final monthEvents = [
      for (var d = 1; d <= days; d++)
        for (final e in IslamicCalendar.eventsOn(month, d)) (d, e),
    ];

    return Scaffold(
      appBar: AppBar(title: Text(l10n.calendarTitle)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () => _shift(-1),
              ),
              Expanded(
                child: Column(
                  children: [
                    Text('$monthName $year', style: context.texts.titleLarge),
                    Text(
                      '${DateFormat.yMMM(locale).format(first)} – '
                      '${DateFormat.yMMM(locale).format(first.add(Duration(days: days - 1)))}',
                      style: context.texts.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () => _shift(1),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              for (var i = 0; i < 7; i++)
                Expanded(
                  child: Text(
                    weekdayNames[(firstDayIndex + i) % 7],
                    textAlign: TextAlign.center,
                    style: context.texts.labelMedium?.copyWith(
                      color: scheme.primary,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 0.85,
            children: [
              for (var i = 0; i < leading; i++) const SizedBox(),
              for (var d = 1; d <= days; d++)
                Builder(
                  builder: (context) {
                    final g = first.add(Duration(days: d - 1));
                    final isToday = g == today;
                    final events = IslamicCalendar.eventsOn(month, d);
                    final white = IslamicCalendar.isWhiteDay(d);
                    return Container(
                      margin: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: isToday
                            ? scheme.primary
                            : events.isNotEmpty
                            ? scheme.tertiaryContainer
                            : white
                            ? scheme.secondaryContainer.withValues(alpha: 0.5)
                            : null,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '$d',
                            style: context.texts.titleSmall?.copyWith(
                              color: isToday ? scheme.onPrimary : null,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            '${g.day}',
                            style: context.texts.labelSmall?.copyWith(
                              color: isToday
                                  ? scheme.onPrimary
                                  : scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          if (monthEvents.isNotEmpty) ...[
            Text(l10n.eventsThisMonth, style: context.texts.titleMedium),
            for (final (d, e) in monthEvents)
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: scheme.tertiaryContainer,
                  foregroundColor: scheme.onTertiaryContainer,
                  child: Text('$d'),
                ),
                title: Text(eventLabel(context, e)),
                subtitle: Text(
                  DateFormat.yMMMMEEEEd(locale).format(
                    IslamicCalendar.toGregorian(year, month, d, offset: offset),
                  ),
                ),
              ),
          ],
          ListTile(
            leading: CircleAvatar(backgroundColor: scheme.secondaryContainer),
            title: Text(l10n.whiteDays),
          ),
          const Divider(),
          Text(l10n.upcomingEvents, style: context.texts.titleMedium),
          for (final u in IslamicCalendar.upcoming(
            today,
            offset: offset,
            count: 6,
          ))
            ListTile(
              leading: Icon(Icons.event, color: scheme.primary),
              title: Text(eventLabel(context, u.event)),
              subtitle: Text(DateFormat.yMMMMEEEEd(locale).format(u.date)),
              trailing: Text(
                l10n.inDays(u.daysFrom(today)),
                style: context.texts.labelLarge?.copyWith(
                  color: scheme.primary,
                ),
              ),
            ),
          const SizedBox(height: AppSpacing.md),
          Text(
            l10n.hijriDisclaimer,
            style: context.texts.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
