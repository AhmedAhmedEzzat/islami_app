import 'package:flutter/material.dart';
import 'package:islami1/modules/layuot/quran/quran_view.dart';
import 'package:islami1/modules/layuot/radio/radio_view.dart';
import 'package:islami1/modules/layuot/tasbeh/tasbeh_view.dart';
import 'package:islami1/modules/layuot/time/time_view.dart';

import '../../core/constants/assets.dart';
import 'hadeth/hadeth_view.dart';

class LayoutView extends StatefulWidget {
  static const String routeName = '/layout';

  const LayoutView({super.key});

  @override
  State<LayoutView> createState() => _LayoutViewState();
}

class _LayoutViewState extends State<LayoutView> {
  int _selectedIndex = 0;
  List<Widget> screens = [
    QuranView(),
    HadethView(),
    TasbehView(),
    RadioView(),
    TimeView(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        items: [
          BottomNavigationBarItem(
            icon: ImageIcon(AssetImage(Assets.quranIcon)),
            label: 'Quran',
            activeIcon: Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(20),
              ),
              child: ImageIcon(AssetImage(Assets.quranIcon)),
            ),
          ),

          BottomNavigationBarItem(
            icon: ImageIcon(AssetImage(Assets.hadethIcon)),
            label: 'Hadeth',
            activeIcon: Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(20),
              ),
              child: ImageIcon(AssetImage(Assets.hadethIcon)),
            ),
          ),
          BottomNavigationBarItem(
            icon: ImageIcon(AssetImage(Assets.tasbehIcon)),
            label: 'Tasbeh',
            activeIcon: Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(20),
              ),
              child: ImageIcon(AssetImage(Assets.tasbehIcon)),
            ),
          ),
          BottomNavigationBarItem(
            icon: ImageIcon(AssetImage(Assets.radioIcon)),
            label: 'Radio',
            activeIcon: Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(20),
              ),
              child: ImageIcon(AssetImage(Assets.radioIcon)),
            ),
          ),
          BottomNavigationBarItem(
            icon: ImageIcon(AssetImage(Assets.timeIcon)),
            label: 'Time',
            activeIcon: Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(20),
              ),
              child: ImageIcon(AssetImage(Assets.timeIcon)),
            ),
          ),
        ],
      ),
    );
  }
}
