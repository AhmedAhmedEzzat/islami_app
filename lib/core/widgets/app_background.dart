import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';
import '../../core/utils/l10n_ext.dart';

/// Page shell for the five main tabs.
///
/// The app ships large decorative photographs which used to be painted
/// full-bleed behind every screen. That is the main reason it read as a demo,
/// and in light mode it made body text unreadable. Here the artwork is reduced
/// to a bounded ornament across the top, faded by brightness and covered by a
/// scrim that fades into the surface colour, so text never sits on a photo.
class AppBackground extends StatelessWidget {
  const AppBackground({
    super.key,
    required this.child,
    this.ornament,
    this.title,
    this.actions,
  });

  /// Decorative asset painted behind the header area only.
  final String? ornament;

  /// Rendered as the page heading in the themed text style.
  final String? title;

  final List<Widget>? actions;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Material rather than a plain coloured Container: ListTile and InkWell
    // paint their ripples on the nearest Material ancestor, and a ColoredBox
    // in between hides them (Flutter asserts on exactly this).
    return Material(
      color: scheme.surface,
      child: Stack(
        children: [
          if (ornament != null)
            SizedBox(
              height: AppOrnament.height,
              width: double.infinity,
              child: ShaderMask(
                // Fades the artwork out towards the content, so there is never
                // a hard edge where the photo stops.
                shaderCallback: (rect) => LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black, Colors.black.withValues(alpha: 0)],
                ).createShader(rect),
                blendMode: BlendMode.dstIn,
                child: Opacity(
                  opacity: isDark
                      ? AppOrnament.darkOpacity
                      : AppOrnament.lightOpacity,
                  child: Image.asset(
                    ornament!,
                    fit: BoxFit.cover,
                    excludeFromSemantics: true,
                  ),
                ),
              ),
            ),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null)
                  Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(
                      AppSpacing.lg,
                      AppSpacing.md,
                      AppSpacing.sm,
                      AppSpacing.sm,
                    ),
                    child: Row(
                      children: [
                        // The same screen can be a tab root or a pushed page;
                        // only the pushed one needs a way back.
                        if (ModalRoute.of(context)?.canPop ?? false)
                          const BackButton(),
                        Expanded(
                          child: Text(
                            title!,
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(color: scheme.onSurface),
                          ),
                        ),
                        ...?actions,
                      ],
                    ),
                  ),
                Expanded(child: child),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A centred message used for empty and error states.
class AppStateMessage extends StatelessWidget {
  const AppStateMessage({
    super.key,
    required this.message,
    this.icon,
    this.onRetry,
    this.retryLabel,
  });

  final String message;
  final IconData? icon;
  final VoidCallback? onRetry;
  final String? retryLabel;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 48, color: context.colors.outline),
              const SizedBox(height: AppSpacing.md),
            ],
            Text(
              message,
              textAlign: TextAlign.center,
              style: context.texts.bodyLarge?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: AppSpacing.lg),
              FilledButton.tonal(onPressed: onRetry, child: Text(retryLabel ?? context.l10n.tryAgain)),
            ],
          ],
        ),
      ),
    );
  }
}
