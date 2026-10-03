import 'package:flutter/material.dart';

/// The Sakina mark: a crescent with the Arabic س seated in its opening.
///
/// This is the single definition of the artwork. The launcher icon, the native
/// splash image and the in-app splash all paint it through this painter, so the
/// three can never drift apart — which is what makes the native-to-Dart splash
/// handoff seamless.
class SakinaMark extends CustomPainter {
  const SakinaMark({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final side = size.shortestSide;
    final centre = Offset(size.width / 2, size.height / 2);
    final r = side / 2;

    final paint = Paint()
      ..color = color
      ..isAntiAlias = true;

    // Crescent: a disc with a second, offset disc subtracted from it.
    final outer = Path()..addOval(Rect.fromCircle(center: centre, radius: r));
    final bite = Path()
      ..addOval(
        Rect.fromCircle(
          center: centre.translate(r * 0.52, -r * 0.16),
          radius: r * 0.82,
        ),
      );

    canvas.drawPath(
      Path.combine(PathOperation.difference, outer, bite),
      paint,
    );

    // The س sits in the crescent's opening.
    final letter = TextPainter(
      text: TextSpan(
        text: 'س',
        style: TextStyle(
          fontFamily: 'Janna',
          fontSize: r * 0.62,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
      textDirection: TextDirection.rtl,
      textAlign: TextAlign.center,
    )..layout();

    letter.paint(
      canvas,
      Offset(
        centre.dx + r * 0.30 - letter.width / 2,
        centre.dy + r * 0.10 - letter.height / 2,
      ),
    );
  }

  @override
  bool shouldRepaint(SakinaMark old) => old.color != color;
}
