import 'package:flutter/material.dart';
import 'package:islami1/core/constants/theme_manager.dart';
import 'package:islami1/core/services/shared_prefs_helper.dart';
import 'package:islami1/modules/layuot/quran/quran_details_view.dart';
import 'package:islami1/modules/splash/splash_view.dart';

import 'modules/layuot/layout_view.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  LocalStorageServices.init();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeManager.themeData,
      initialRoute: SplashView.routeName,
      routes: {
        SplashView.routeName: (context) => const SplashView(),
        LayoutView.routeName: (context) => const LayoutView(),
        QuranDetailsView.routeName: (context) => const QuranDetailsView(),
      },
    );
  }
}
