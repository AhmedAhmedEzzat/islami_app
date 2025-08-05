import 'package:flutter/material.dart';
import 'package:islami1/core/constants/assets.dart';
import 'package:islami1/core/constants/colors.dart';

class HadethItemWidget extends StatelessWidget {
  const HadethItemWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 310,
      height: 620,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: ColorsPallete.primaryColor,
        image: DecorationImage(
          image: AssetImage(Assets.hadethBackgroundCard),
          fit: BoxFit.fill,
        ),
      ),
      child: Stack(children: [Column()]),
    );
  }
}
