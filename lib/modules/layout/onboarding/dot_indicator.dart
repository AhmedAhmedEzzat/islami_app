import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class DotIndicator extends StatelessWidget {
  const DotIndicator({super.key, required this.isActive});

  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      alignment: Alignment.center,
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.symmetric(horizontal: 8),
      height: 8,
      width: isActive ? 24 : 8,
      decoration: BoxDecoration(
        color: isActive
            ? context.colors.primary
            : context.colors.outlineVariant,
        borderRadius: BorderRadius.circular(20),
      ),
    );
  }
}
