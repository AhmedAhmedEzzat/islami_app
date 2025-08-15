import 'dart:math';

import 'package:flutter/material.dart';

import '../../../core/constants/assets.dart';

class TasbehView extends StatefulWidget {
  const TasbehView({super.key});

  @override
  State<TasbehView> createState() => _TasbehViewState();
}

class _TasbehViewState extends State<TasbehView> {
  int counter = 0;
  int index = 0;
  double _beadsRotation = 0.0;
  final double _rotationIncrement = pi / 33;

  final List<String> azkar = [
    'سُبْحَانَ اللَّه',
    'الْـحَمْدُ لِلَّه',
    'اللَّهُ أَكْبَر',
  ];

  void onTapSebha() {
    setState(() {
      counter++;
      _beadsRotation += _rotationIncrement;
      if (counter == 34) {
        counter = 0;
        index = (index + 1) % azkar.length;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTapSebha,
      child: Container(
        height: double.infinity,
        width: double.infinity,
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage(Assets.tasbehBackground),
            fit: BoxFit.cover,
          ),
        ),
        child: Column(
          children: [
            Image.asset(
              Assets.headerLogo,
              height: MediaQuery.of(context).size.height * 0.2,
            ),

            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                'سَبِّحِ اسْمَ رَبِّكَ الأعلى',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  fontFamily: 'Janna',
                ),
              ),
            ),

            Expanded(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned.fill(
                    top: MediaQuery.of(context).size.height * 0.05,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: AnimatedRotation(
                        duration: const Duration(milliseconds: 300),
                        turns: _beadsRotation,

                        child: Image.asset(
                          Assets.tasbehBeads,
                          fit: BoxFit.fitWidth,
                        ),
                      ),
                    ),
                  ),

                  Positioned(
                    top: MediaQuery.of(context).size.height * 0.01,
                    child: Image.asset(
                      Assets.tasbehHead,
                      width: MediaQuery.of(context).size.width * 0.45,
                    ),
                  ),

                  Positioned(
                    top: MediaQuery.of(context).size.height * 0.3,
                    child: Text(
                      azkar[index],
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Janna',
                        color: Colors.white,
                      ),
                    ),
                  ),

                  Positioned(
                    bottom: MediaQuery.of(context).size.height * 0.2,
                    child: Text(
                      '$counter',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Janna',
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}