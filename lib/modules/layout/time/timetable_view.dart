import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../../core/services/islamic_calendar.dart';
import '../../../core/services/prayer_times_service.dart';
import '../../../core/state/settings_cubit.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/l10n_ext.dart';
import '../../../core/utils/prayer_labels.dart';

/// Every prayer for every day of a month, as printed mosque timetables are.
class TimetableView extends StatefulWidget {
  const TimetableView({super.key, required this.location});

  final PrayerLocation location;

  @override
  State<TimetableView> createState() => _TimetableViewState();
}

class _TimetableViewState extends State<TimetableView> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final settings = context.watch<SettingsCubit>().state;
    final config = settings.prayerConfig;
    final rows = PrayerTimesService.computeMonth(
      coordinates: widget.location.coordinates,
      month: _month,
      config: config,
    );
    final today = DateUtils.dateOnly(DateTime.now());
    final time = DateFormat.Hm(locale);

    TextStyle? head = context.texts.labelSmall?.copyWith(
      fontWeight: FontWeight.w700,
      color: scheme.primary,
    );

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.monthlyTimetable)),
      body: Column(
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () => setState(() => _month = DateTime(_month.year, _month.month - 1)),
              ),
              Expanded(
                child: Text(
                  DateFormat.yMMMM(locale).format(_month),
                  textAlign: TextAlign.center,
                  style: context.texts.titleMedium,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () => setState(() => _month = DateTime(_month.year, _month.month + 1)),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
            child: Row(
              children: [
                SizedBox(width: 56, child: Text('', style: head)),
                for (final p in PrayerName.values)
                  Expanded(
                    child: Text(
                      prayerLabel(context, p),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: head,
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              itemCount: rows.length,
              itemBuilder: (context, i) {
                final (day, entries) = rows[i];
                final isToday = day == today;
                final hijri = IslamicCalendar.of(day, offset: settings.hijriOffset);
                return Container(
                  color: isToday
                      ? scheme.secondaryContainer
                      : (i.isEven ? null : scheme.surfaceContainerLow),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.sm,
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 56,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              DateFormat.E(locale).add_d().format(day),
                              style: context.texts.labelMedium?.copyWith(
                                fontWeight: isToday ? FontWeight.w700 : null,
                              ),
                            ),
                            Text(
                              '${hijri.hDay}/${hijri.hMonth}',
                              style: context.texts.labelSmall?.copyWith(color: scheme.primary),
                            ),
                          ],
                        ),
                      ),
                      for (final e in entries)
                        Expanded(
                          child: Text(
                            time.format(e.time),
                            textAlign: TextAlign.center,
                            style: context.texts.bodySmall?.copyWith(
                              fontFeatures: const [FontFeature.tabularFigures()],
                              fontWeight: isToday ? FontWeight.w700 : null,
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
