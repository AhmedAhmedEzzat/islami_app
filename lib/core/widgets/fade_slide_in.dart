import 'package:material_ui/material_ui.dart';

/// Fades [child] in while it rises a little, once, when it first appears.
///
/// [index] staggers a column of cards so they arrive one after another. When
/// the phone asks for reduced motion the child is shown straight away.
class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({super.key, required this.child, this.index = 0});

  final Widget child;
  final int index;

  /// The gap between one card and the next. Kept short so nothing waits.
  static const stagger = Duration(milliseconds: 60);
  static const duration = Duration(milliseconds: 380);

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: FadeSlideIn.duration + FadeSlideIn.stagger * widget.index.clamp(0, 8),
  );
  late final Animation<double> _t = CurvedAnimation(
    parent: _c,
    curve: Interval(
      1 - FadeSlideIn.duration.inMilliseconds / _c.duration!.inMilliseconds,
      1,
      curve: Curves.easeOutCubic,
    ),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_c.isAnimating || _c.isCompleted) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _c.value = 1;
    } else {
      _c.forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _t,
    child: widget.child,
    builder: (context, child) => Opacity(
      opacity: _t.value,
      child: Transform.translate(
        offset: Offset(0, 16 * (1 - _t.value)),
        child: child,
      ),
    ),
  );
}
