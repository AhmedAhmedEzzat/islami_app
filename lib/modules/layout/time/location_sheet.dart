import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/services/prayer_times_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/l10n_ext.dart';

/// Choose between GPS and a city typed by hand. Pops true if anything changed.
class LocationSheet extends StatefulWidget {
  const LocationSheet({super.key});

  static Future<bool?> show(BuildContext context) => showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: const LocationSheet(),
    ),
  );

  @override
  State<LocationSheet> createState() => _LocationSheetState();
}

class _LocationSheetState extends State<LocationSheet> {
  Timer? _debounce;
  List<PrayerLocation> _results = const [];
  bool _searching = false;
  String _query = '';

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged(String value) {
    _query = value;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      if (_query.trim().length < 2) {
        setState(() => _results = const []);
        return;
      }
      setState(() => _searching = true);
      final found = await PrayerTimesService.searchCity(_query);
      if (!mounted) return;
      setState(() {
        _results = found;
        _searching = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final current = PrayerTimesService.currentLocation();

    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.7,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Text(l10n.locationTitle, style: context.texts.titleLarge),
          ),
          ListTile(
            leading: Icon(Icons.my_location, color: context.colors.primary),
            title: Text(l10n.useMyLocation),
            trailing: current.isManual ? null : const Icon(Icons.check),
            onTap: () async {
              await PrayerTimesService.clearManualLocation();
              if (context.mounted) Navigator.pop(context, true);
            },
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: TextField(
              autofocus: false,
              onChanged: _onChanged,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: l10n.searchCityHint,
                prefixIcon: const Icon(Icons.search),
              ),
            ),
          ),
          if (_searching) const LinearProgressIndicator(),
          Expanded(
            child: _query.trim().length >= 2 && !_searching && _results.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    child: Text(
                      l10n.noCityFound,
                      textAlign: TextAlign.center,
                      style: context.texts.bodyMedium?.copyWith(
                        color: context.colors.onSurfaceVariant,
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: _results.length,
                    itemBuilder: (context, i) {
                      final r = _results[i];
                      return ListTile(
                        leading: const Icon(Icons.location_city),
                        title: Text(r.name ?? ''),
                        subtitle: Text(
                          '${r.coordinates.latitude.toStringAsFixed(3)}, '
                          '${r.coordinates.longitude.toStringAsFixed(3)}',
                          textDirection: TextDirection.ltr,
                        ),
                        onTap: () async {
                          await PrayerTimesService.setManualLocation(r);
                          if (context.mounted) Navigator.pop(context, true);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
