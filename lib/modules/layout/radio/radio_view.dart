import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/constants/assets.dart';
import '../../../core/state/radio_cubit.dart';
import '../../../core/state/radio_state.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_background.dart';
import '../../../models/radio_channel.dart';
import 'radio_card.dart';
import '../../../core/utils/l10n_ext.dart';

class RadioView extends StatelessWidget {
  /// Named so the now-playing bar can tell when the radio is already on screen.
  static const String routeName = '/radio';

  const RadioView({super.key});

  @override
  Widget build(BuildContext context) {
    final channels = RadioChannel.channels;

    // The old screen had a Radio/Reciters toggle, but both tabs rendered the
    // same list with the same streams and only a different title prefix. It
    // was removed rather than left as a control that does nothing.
    return AppBackground(
      ornament: Assets.radioBackground,
      title: context.l10n.radioTitle,
      child: BlocConsumer<RadioCubit, RadioState>(
        listenWhen: (a, b) => a.errorKey != b.errorKey && b.errorKey != null,
        listener: (context, state) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.l10n.radioUnreachable)),
          );
          context.read<RadioCubit>().clearError();
        },
        builder: (context, state) {
          return ListView.separated(
            padding: const EdgeInsetsDirectional.fromSTEB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.xl,
            ),
            itemCount: channels.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, index) {
              final cubit = context.read<RadioCubit>();
              final isActive = state.isActiveAt(index);

              return RadioCard(
                title: channels[index].name,
                isPlaying: state.isPlayingAt(index),
                isActive: isActive,
                isBuffering: state.isBufferingAt(index),
                isMuted: isActive && state.isMuted,
                onPlayPressed: () => cubit.toggle(index),
                onVolumePressed: isActive ? cubit.toggleMute : null,
              );
            },
          );
        },
      ),
    );
  }
}
