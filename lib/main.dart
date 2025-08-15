import 'package:flutter/material.dart';
import 'package:islami1/core/constants/theme_manager.dart';
import 'package:islami1/core/services/shared_prefs_helper.dart';
import 'package:islami1/modules/layuot/onboarding/on_boarding_screen.dart';
import 'package:islami1/modules/layuot/quran/quran_details_view.dart';
import 'package:islami1/modules/splash/splash_view.dart';

import 'modules/layuot/layout_view.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocalStorageServices.init();
  var isFirstTime = LocalStorageServices.getBool('firstTime') ?? true;
  runApp(MyApp(
    isFirstTime: isFirstTime,
  ));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, required this.isFirstTime});

  final bool isFirstTime;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeManager.themeData,
      initialRoute: isFirstTime ? OnBoardingScreen.routeName : SplashView
          .routeName,
      routes: {
        SplashView.routeName: (context) => const SplashView(),
        OnBoardingScreen.routeName: (context) => const OnBoardingScreen(),
        LayoutView.routeName: (context) => const LayoutView(),
        QuranDetailsView.routeName: (context) => const QuranDetailsView(),
      },
    );
  }
}
