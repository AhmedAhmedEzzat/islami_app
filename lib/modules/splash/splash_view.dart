import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';
import '../../core/widgets/sakina_mark.dart';
import '../layout/layout_view.dart';

/// Animated launch screen.
///
/// It paints the same [SakinaMark] on the same green as the native splash, so
/// the native-to-Dart handoff has no visible seam.
class SplashView extends StatefulWidget {
  static const String routeName = '/splash';

  /// Matches `windowSplashScreenBackground` in values-v31/styles.xml.
  static const Color background = Color(0xFF1B5E20);
  static const Color backgroundDark = Color(0xFF0F1B10);

  const SplashView({super.key});

  @override
  State<SplashView> createState() => _SplashViewState();
}

class _SplashViewState extends State<SplashView>
    with SingleTickerProviderStateMixin {
  static const Duration _total = Duration(milliseconds: 2400);

  late final AnimationController _controller;
  late final Animation<double> _markScale;
  late final Animation<double> _titleFade;
  late final Animation<double> _arabicFade;

  Timer? _timer;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _total)..forward();

    // The mark holds at its native size and only breathes very slightly, so
    // the handoff from the native splash reads as one continuous screen.
    _markScale = Tween<double>(begin: 1.0, end: 1.06).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.10, 0.70, curve: Curves.easeInOut),
      ),
    );
    _titleFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.33, 0.58, curve: Curves.easeOutCubic),
    );
    _arabicFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.46, 0.71, curve: Curves.easeOutCubic),
    );

    // Navigation stays on a Timer rather than an animation status listener:
    // an AnimationController does not advance while the app is backgrounded,
    // so a status listener could leave the user stuck on the splash.
    _timer = Timer(_total, _goToLayout);
  }

  void _goToLayout() {
    if (!mounted || _navigated) return;
    _navigated = true;
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 320),
        pageBuilder: (_, _, _) => const LayoutView(),
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background =
        isDark ? SplashView.backgroundDark : SplashView.background;

    return Scaffold(
      backgroundColor: background,
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ScaleTransition(
                  scale: _markScale,
                  child: SizedBox(
                    width: 148,
                    height: 148,
                    child: const CustomPaint(
                      painter: SakinaMark(color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                _FadeUp(
                  progress: _titleFade.value,
                  offset: 14,
                  child: Text(
                    'Sakina',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                _FadeUp(
                  progress: _arabicFade.value,
                  offset: 10,
                  child: Text(
                    'سكينة',
                    textDirection: TextDirection.rtl,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.75),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _FadeUp extends StatelessWidget {
  const _FadeUp({
    required this.progress,
    required this.offset,
    required this.child,
  });

  final double progress;
  final double offset;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: progress.clamp(0.0, 1.0),
      child: Transform.translate(
        offset: Offset(0, offset * (1 - progress)),
        child: child,
      ),
    );
  }
}
