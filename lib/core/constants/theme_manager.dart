import 'package:flutter/material.dart';

import 'colors.dart';

abstract class ThemeManager {
  static ThemeData themeData = ThemeData(
    primaryColor: ColorsPallete.primaryColor,
    scaffoldBackgroundColor: Colors.transparent,
    appBarTheme: AppBarTheme(
      backgroundColor: ColorsPallete.quranDetailsColor,
      iconTheme: IconThemeData(color: ColorsPallete.primaryColor),
      titleTextStyle: TextStyle(
        color: ColorsPallete.primaryColor,
        fontSize: 20,
        fontWeight: FontWeight.w700,
        fontFamily: 'Janna',
      ),
    ),

    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      type: BottomNavigationBarType.fixed,
      selectedItemColor: ColorsPallete.selectedIcon,
      showSelectedLabels: true,
      showUnselectedLabels: false,
      selectedLabelStyle: const TextStyle(
        fontFamily: 'Janna',
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
      unselectedItemColor: ColorsPallete.unselectedIcon,

      backgroundColor: ColorsPallete.primaryColor,
    ),
    textTheme: TextTheme(
      headlineSmall: TextStyle(
        color: Colors.black,
        fontSize: 24,
        fontWeight: FontWeight.w700,
        fontFamily: 'Janna',
      ),
      titleLarge: TextStyle(
        color: const Color(0xFFFFFFFF),
        fontSize: 20,
        fontWeight: FontWeight.w700,
        fontFamily: 'Janna',
      ),
      bodyLarge: TextStyle(
        color: const Color(0xFFFFFFFF),
        fontSize: 16,
        fontWeight: FontWeight.w700,
        fontFamily: 'Janna',
      ),
      bodyMedium: TextStyle(
        color: const Color(0xFFFFFFFF),
        fontSize: 14,
        fontWeight: FontWeight.w700,
        fontFamily: 'Janna',
      ),
      bodySmall: TextStyle(
        color: const Color(0xFFFFFFFF),
        fontSize: 12,
        fontWeight: FontWeight.w700,
        fontFamily: 'Janna',
      ),
    ),
  );
}
