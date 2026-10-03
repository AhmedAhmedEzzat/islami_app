import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/l10n_ext.dart';

class RadioCard extends StatelessWidget {
  const RadioCard({
    super.key,
    required this.title,
    required this.isPlaying,
    required this.isActive,
    required this.isBuffering,
    required this.isMuted,
    required this.onPlayPressed,
    this.onVolumePressed,
  });

  final String title;
  final bool isPlaying;
  final bool isActive;
  final bool isBuffering;
  final bool isMuted;
  final VoidCallback onPlayPressed;

  /// Null while this station is not active, which disables the button rather
  /// than letting it silently do nothing.
  final VoidCallback? onVolumePressed;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;

    return Card(
      color: isActive ? scheme.primaryContainer : scheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: [
            IconButton.filled(
              tooltip: isPlaying
                  ? context.l10n.pauseStation
                  : context.l10n.playStation,
              onPressed: onPlayPressed,
              icon: isBuffering
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    )
                  : Icon(isPlaying ? Icons.pause : Icons.play_arrow),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                title,
                style: context.texts.titleMedium?.copyWith(
                  color: isActive
                      ? scheme.onPrimaryContainer
                      : scheme.onSurface,
                ),
              ),
            ),
            IconButton(
              tooltip: isMuted ? context.l10n.unmute : context.l10n.mute,
              onPressed: onVolumePressed,
              icon: Icon(isMuted ? Icons.volume_off : Icons.volume_up),
            ),
          ],
        ),
      ),
    );
  }
}
