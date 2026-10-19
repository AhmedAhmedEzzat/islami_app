import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/constants/muezzins.dart';
import '../../core/services/adhan_sounds.dart';
import '../../core/services/notification_refresh.dart';
import '../../core/services/prayer_notification_service.dart';
import '../../core/state/settings_cubit.dart';
import '../../core/state/settings_state.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/l10n_ext.dart';

/// Whose adhan the prayer alert plays: a bundled recording, or one the user
/// has on their phone (with a separate one for Fajr if they like).
class MuezzinView extends StatefulWidget {
  const MuezzinView({super.key});

  @override
  State<MuezzinView> createState() => _MuezzinViewState();
}

class _MuezzinViewState extends State<MuezzinView> {
  late final Future<bool> _canPickFile = AdhanSounds.canPickFile();

  /// Asks where to choose from, then lets the user choose.
  Future<void> _choose({required bool fajr}) async {
    final cubit = context.read<SettingsCubit>();
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final canFile = await _canPickFile;
    if (!mounted) return;
    final fromFile = !canFile
        ? false
        : await showModalBottomSheet<bool>(
            context: context,
            showDragHandle: true,
            builder: (context) => SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: const Icon(Icons.audio_file_outlined),
                    title: Text(l10n.chooseAudioFile),
                    subtitle: Text(l10n.chooseAudioFileSubtitle),
                    onTap: () => Navigator.pop(context, true),
                  ),
                  ListTile(
                    leading: const Icon(Icons.library_music_outlined),
                    title: Text(l10n.choosePhoneSound),
                    subtitle: Text(l10n.choosePhoneSoundSubtitle),
                    onTap: () => Navigator.pop(context, false),
                  ),
                ],
              ),
            ),
          );
    if (fromFile == null) return;
    try {
      final current = fajr ? cubit.state.customFajrAdhan : cubit.state.customAdhan;
      final picked = fromFile ? await AdhanSounds.pickFile() : await AdhanSounds.pickSystem(current: current?.uri);
      if (picked == null) return;
      await cubit.setCustomAdhan(picked, fajr: fajr);
    } on PlatformException catch (e) {
      debugPrint('Adhan not chosen: $e');
      messenger.showSnackBar(SnackBar(content: Text(l10n.customAdhanFailed)));
    }
  }

  Future<void> _test(SettingsState state) async {
    final muezzin = await NotificationRefresh.playableMuezzin(state);
    if (!mounted) return;
    await PrayerNotificationService.showTest(
      locale: Localizations.localeOf(context),
      sound: state.prayerSound,
      muezzin: muezzin,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = context.colors;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.muezzinSetting)),
      body: BlocBuilder<SettingsCubit, SettingsState>(
        builder: (context, state) {
          final cubit = context.read<SettingsCubit>();
          final custom = state.customAdhan;
          final selected = state.muezzin.id;
          return RadioGroup<String>(
            groupValue: selected,
            onChanged: (id) {
              if (id != null) cubit.setMuezzin(id);
            },
            child: ListView(
              padding: const EdgeInsets.only(bottom: AppSpacing.xl),
              children: [
                _Header(l10n.bundledAdhans),
                for (final m in Muezzins.all)
                  RadioListTile<String>(
                    value: m.id,
                    title: Text(
                      m == Muezzins.standard ? l10n.muezzinDefault : (context.isArabic ? m.nameAr : m.nameEn),
                    ),
                  ),
                _Header(l10n.customAdhanTitle),
                if (!AdhanSounds.supported)
                  Padding(
                    padding: AppSpacing.pageH,
                    child: Text(l10n.customAdhanAndroidOnly, style: context.texts.bodyMedium),
                  )
                else ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.sm),
                    child: Text(
                      l10n.customAdhanIntro,
                      style: context.texts.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ),
                  if (custom == null)
                    Padding(
                      padding: AppSpacing.pageH,
                      child: Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: FilledButton.tonalIcon(
                          onPressed: () => _choose(fajr: false),
                          icon: const Icon(Icons.add),
                          label: Text(l10n.chooseRecording),
                        ),
                      ),
                    )
                  else ...[
                    RadioListTile<String>(
                      value: Muezzins.customId,
                      title: Text(custom.title.isEmpty ? l10n.customAdhanTitle : custom.title),
                      subtitle: Text(l10n.customAdhanFourPrayers),
                      secondary: _SoundActions(
                        onChange: () => _choose(fajr: false),
                        onRemove: () => cubit.setCustomAdhan(null),
                      ),
                    ),
                    ListTile(
                      contentPadding: const EdgeInsetsDirectional.only(start: 72, end: AppSpacing.lg),
                      title: Text(l10n.customFajrAdhan),
                      subtitle: Text(state.customFajrAdhan?.title ?? l10n.customFajrSame),
                      trailing: state.customFajrAdhan == null
                          ? TextButton(onPressed: () => _choose(fajr: true), child: Text(l10n.chooseRecordingShort))
                          : _SoundActions(
                              onChange: () => _choose(fajr: true),
                              onRemove: () => cubit.setCustomAdhan(null, fajr: true),
                            ),
                    ),
                  ],
                ],
                const SizedBox(height: AppSpacing.lg),
                Padding(
                  padding: AppSpacing.pageH,
                  child: OutlinedButton.icon(
                    onPressed: state.prayerNotifications ? () => _test(state) : null,
                    icon: const Icon(Icons.play_circle_outline),
                    label: Text(l10n.testAdhan),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.sm),
    child: Text(
      text,
      style: context.texts.titleSmall?.copyWith(color: context.colors.primary, fontWeight: FontWeight.w700),
    ),
  );
}

/// Change or remove one of the user's recordings.
class _SoundActions extends StatelessWidget {
  const _SoundActions({required this.onChange, required this.onRemove});

  final VoidCallback onChange;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      IconButton(tooltip: context.l10n.changeRecording, icon: const Icon(Icons.edit_outlined), onPressed: onChange),
      IconButton(tooltip: context.l10n.removeRecording, icon: const Icon(Icons.delete_outline), onPressed: onRemove),
    ],
  );
}
