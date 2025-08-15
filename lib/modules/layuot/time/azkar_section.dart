import 'package:flutter/material.dart';
import 'package:islami1/core/constants/colors.dart';

import '../../../core/constants/assets.dart';

class AzkarSection extends StatelessWidget {
  const AzkarSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GridView.count(
        crossAxisCount: 2,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        children: const [
          _AzkarCard(title: "Evening Azkar", image: Assets.eveningAzkar),
          _AzkarCard(title: "Morning Azkar", image: Assets.morningAzkar),
        ],
      ),
    );
  }
}

class _AzkarCard extends StatelessWidget {
  final String title;
  final String image;

  const _AzkarCard({required this.title, required this.image});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: ColorsPallete.unselectedIcon,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ColorsPallete.primaryColor),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Image.asset(image),
            ),
          ),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 10),
        ],
      ),
    );
  }
}
