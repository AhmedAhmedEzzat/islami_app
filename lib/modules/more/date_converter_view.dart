import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../core/services/islamic_calendar.dart';
import '../../core/state/settings_cubit.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/arabic_text.dart';
import '../../core/utils/l10n_ext.dart';

/// Converts a date between the Gregorian and Hijri calendars, either way,
/// with the reader's Hijri adjustment applied.
class DateConverterView extends StatefulWidget {
  const DateConverterView({super.key});

  /// The years the Umm al-Qura tables cover: 14 March 1937 to 16 November
  /// 2077, which takes in every date the Gregorian picker offers.
  static const int firstHijriYear = 1356;
  static const int lastHijriYear = 1500;

  @override
  State<DateConverterView> createState() => _DateConverterViewState();
}

class _DateConverterViewState extends State<DateConverterView> {
  bool _fromHijri = false;
  DateTime _gregorian = DateTime.now();
  late int _hYear;
  late int _hMonth;
  late int _hDay;

  int get _offset => context.read<SettingsCubit>().state.hijriOffset;

  @override
  void initState() {
    super.initState();
    final today = IslamicCalendar.of(DateTime.now(), offset: context.read<SettingsCubit>().state.hijriOffset);
    _hYear = today.hYear;
    _hMonth = today.hMonth;
    _hDay = today.hDay;
  }

  Future<void> _pickGregorian() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _gregorian,
      firstDate: DateTime(1938),
      lastDate: DateTime(2076, 12, 31),
    );
    if (picked != null) setState(() => _gregorian = picked);
  }

  String _hijriText(HijriCalendar h) => context.isArabic
      ? '${ArabicText.digits(h.hDay)} ${h.longMonthName} ${ArabicText.digits(h.hYear)} هـ'
      : '${h.hDay} ${h.longMonthName} ${h.hYear} AH';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = context.colors;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final offset = context.select<SettingsCubit, int>((c) => c.state.hijriOffset);

    final DateTime gregorian;
    final String result;
    // The 30th does not exist in a 29-day month; it shows as the 29th.
    final hDay = _hDay.clamp(1, IslamicCalendar.daysInMonth(_hYear, _hMonth));
    if (_fromHijri) {
      gregorian = IslamicCalendar.toGregorian(_hYear, _hMonth, hDay, offset: offset);
      result = DateFormat.yMMMMEEEEd(locale).format(gregorian);
    } else {
      gregorian = DateTime(_gregorian.year, _gregorian.month, _gregorian.day);
      final comma = context.isArabic ? '،' : ',';
      result = '${DateFormat.EEEE(locale).format(gregorian)}$comma ${_hijriText(IslamicCalendar.of(gregorian, offset: offset))}';
    }
    final now = DateTime.now();
    final fromToday = DateTime.utc(gregorian.year, gregorian.month, gregorian.day)
        .difference(DateTime.utc(now.year, now.month, now.day))
        .inDays;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.dateConverter)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          SegmentedButton<bool>(
            segments: [
              ButtonSegment(value: false, label: Text(l10n.gregorianToHijri)),
              ButtonSegment(value: true, label: Text(l10n.hijriToGregorian)),
            ],
            selected: {_fromHijri},
            showSelectedIcon: false,
            onSelectionChanged: (s) => setState(() {
              // Carry the date across, so switching shows the same day.
              if (s.first) {
                final h = IslamicCalendar.of(_gregorian, offset: _offset);
                _hYear = h.hYear;
                _hMonth = h.hMonth;
                _hDay = h.hDay;
              } else {
                _gregorian = gregorian;
              }
              _fromHijri = s.first;
            }),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (!_fromHijri)
            OutlinedButton.icon(
              onPressed: _pickGregorian,
              icon: const Icon(Icons.event),
              label: Text(DateFormat.yMMMMd(locale).format(_gregorian)),
            )
          else
            Row(
              children: [
                Expanded(
                  child: _Dropdown(
                    label: l10n.dayLabel,
                    value: hDay,
                    items: {
                      for (var d = 1; d <= IslamicCalendar.daysInMonth(_hYear, _hMonth); d++)
                        d: context.isArabic ? ArabicText.digits(d) : '$d',
                    },
                    onChanged: (v) => setState(() => _hDay = v),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  flex: 2,
                  child: _Dropdown(
                    label: l10n.monthLabel,
                    value: _hMonth,
                    items: {for (var m = 1; m <= 12; m++) m: (HijriCalendar()..hMonth = m).getLongMonthName()},
                    onChanged: (v) => setState(() {
                      _hMonth = v;
                      _hDay = _hDay.clamp(1, IslamicCalendar.daysInMonth(_hYear, _hMonth));
                    }),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _Dropdown(
                    label: l10n.yearLabel,
                    value: _hYear,
                    items: {
                      for (var y = DateConverterView.firstHijriYear; y <= DateConverterView.lastHijriYear; y++)
                        y: context.isArabic ? ArabicText.digits(y) : '$y',
                    },
                    onChanged: (v) => setState(() {
                      _hYear = v;
                      _hDay = _hDay.clamp(1, IslamicCalendar.daysInMonth(_hYear, _hMonth));
                    }),
                  ),
                ),
              ],
            ),
          const SizedBox(height: AppSpacing.xl),
          Card(
            color: scheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                children: [
                  Icon(Icons.swap_vert, color: scheme.onPrimaryContainer),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    result,
                    textAlign: TextAlign.center,
                    style: context.texts.headlineSmall?.copyWith(
                      color: scheme.onPrimaryContainer,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    fromToday < 0 ? l10n.daysAgo(-fromToday) : l10n.daysFromToday(fromToday),
                    style: context.texts.bodyMedium?.copyWith(color: scheme.onPrimaryContainer),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            l10n.hijriDisclaimer,
            style: context.texts.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _Dropdown extends StatelessWidget {
  const _Dropdown({required this.label, required this.value, required this.items, required this.onChanged});

  final String label;
  final int value;
  final Map<int, String> items;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<int>(
    initialValue: value,
    isExpanded: true,
    decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
    items: [
      for (final MapEntry(:key, value: text) in items.entries)
        DropdownMenuItem(value: key, child: Text(text, overflow: TextOverflow.ellipsis)),
    ],
    onChanged: (v) {
      if (v != null) onChanged(v);
    },
  );
}
