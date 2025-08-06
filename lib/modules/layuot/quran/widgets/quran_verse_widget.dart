import 'package:flutter/material.dart';
import 'package:islami1/core/constants/colors.dart';

class QuranVerseWidget extends StatelessWidget {
  QuranVerseWidget({super.key, required this.verse});

  String verse;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      margin: EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.all(Radius.circular(14)),
        color: ColorsPallete.primaryColor,
      ),
      child: Text(
        verse,
        textDirection: TextDirection.rtl,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.black,
          fontSize: 18,
          fontWeight: FontWeight.w500,
          fontFamily: 'Janna',
        ),
      ),
    );
  }
}
