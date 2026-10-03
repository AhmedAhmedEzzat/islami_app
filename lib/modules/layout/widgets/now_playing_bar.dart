import 'package:flutter/material.dart';

import '../../../core/state/now_playing.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/l10n_ext.dart';

/// Slim persistent player shown above the bottom tabs.
///
/// Without it, backing out of a sura left recitation playing with nothing on
/// screen to say what it was or how to stop it.
class NowPlayingBar extends StatelessWidget {
  const NowPlayingBar({
    super.key,
    required this.nowPlaying,
    required this.onTap,
    required this.onTogglePlay,
    required this.onStop,
  });

  /// Null hides the bar entirely.
  final NowPlaying? nowPlaying;

  final VoidCallback onTap;
  final VoidCallback onTogglePlay;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final playing = nowPlaying;

    return AnimatedSize(
      duration: AppDurations.normal,
      curve: Curves.easeOutCubic,
      alignment: Alignment.bottomCenter,
      child: playing == null
          ? const SizedBox(width: double.infinity)
          : Material(
              color: scheme.surfaceContainerHighest,
              child: InkWell(
                onTap: onTap,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (playing.isBuffering)
                      LinearProgressIndicator(
                        minHeight: 2,
                        backgroundColor: scheme.surfaceContainerHighest,
                      )
                    else if (playing.progress != null)
                      LinearProgressIndicator(
                        value: playing.progress,
                        minHeight: 2,
                        backgroundColor: scheme.surfaceContainerHighest,
                      )
                    else
                      const SizedBox(height: 2),
                    Padding(
                      padding: const EdgeInsetsDirectional.only(
                        start: AppSpacing.lg,
                        end: AppSpacing.sm,
                        top: AppSpacing.sm,
                        bottom: AppSpacing.sm,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            playing.source == NowPlayingSource.recitation
                                ? Icons.menu_book
                                : Icons.radio,
                            size: 20,
                            color: scheme.primary,
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Text(
                              (playing.ayah ?? 0) > 0
                                  ? '${playing.title} · ${playing.ayah}'
                                  : playing.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.texts.bodyMedium?.copyWith(
                                color: scheme.onSurface,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: playing.isPlaying ? context.l10n.pause : context.l10n.play,
                            visualDensity: VisualDensity.compact,
                            onPressed: onTogglePlay,
                            icon: Icon(
                              playing.isPlaying
                                  ? Icons.pause
                                  : Icons.play_arrow,
                            ),
                          ),
                          IconButton(
                            tooltip: context.l10n.stop,
                            visualDensity: VisualDensity.compact,
                            onPressed: onStop,
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
