import 'package:flutter/material.dart';
import 'package:islami1/core/constants/colors.dart';

class DotIndicator extends StatelessWidget {
  DotIndicator({super.key, required this.isActive});

  bool isActive;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      alignment: Alignment.center,
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.symmetric(horizontal: 8),
      height: 8,
      width: isActive ? 24 : 8,

      decoration: BoxDecoration(
        color: isActive ? ColorsPallete.primaryColor : Colors.grey,
        borderRadius: BorderRadius.circular(20),
      ),
    );
  }
}
