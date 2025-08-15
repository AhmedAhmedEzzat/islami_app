import 'package:flutter/material.dart';
import 'package:islami1/core/constants/assets.dart';
import 'package:islami1/core/constants/colors.dart';
import 'package:islami1/models/on_boarding_model.dart';
import 'package:islami1/modules/layuot/layout_view.dart';
import 'package:islami1/modules/layuot/onboarding/dot_indicator.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OnBoardingScreen extends StatefulWidget {
  const OnBoardingScreen({super.key});

  static const String routeName = '/onboarding';

  @override
  State<OnBoardingScreen> createState() => _OnBoardingScreenState();
}

class _OnBoardingScreenState extends State<OnBoardingScreen> {
  int currentIndex = 0;
  PageController pageController = PageController();

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    pageController.addListener(() {
      currentIndex = pageController.page?.toInt() ?? 0;
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Image.asset(
              Assets.headerLogo,
              height: MediaQuery.of(context).size.height * 0.2,
            ),
          ),
          Expanded(
            child: PageView.builder(
              controller: pageController,
              itemCount: OnBoardingData.onBoardingList.length,
              itemBuilder: (context, index) {
                return Column(
                  children: [
                    Expanded(
                      child: Image.asset(
                        OnBoardingData.onBoardingList[index].imagePath,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      OnBoardingData.onBoardingList[index].title,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Janna',
                        color: ColorsPallete.primaryColor,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        textAlign: TextAlign.center,
                        OnBoardingData.onBoardingList[index].description ?? '',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'Janna',
                          color: ColorsPallete.primaryColor,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          Stack(
            alignment: Alignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: ColorsPallete.primaryColor,
                      backgroundColor: Colors.transparent,
                      textStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Janna',
                      ),
                    ),
                    onPressed: currentIndex != 0
                        ? () {
                            pageController.animateToPage(
                              currentIndex - 1,
                              duration: const Duration(milliseconds: 500),
                              curve: Curves.easeIn,
                            );
                          }
                        : null,
                    child: currentIndex != 0 ? Text('Back') : const Text(''),
                  ),
                  TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: ColorsPallete.primaryColor,
                      backgroundColor: Colors.transparent,
                      textStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Janna',
                      ),
                    ),
                    onPressed: () {
                      if (currentIndex == 4) {
                        _seenOnBoarding();
                      } else {
                        pageController.animateToPage(
                          currentIndex + 1,
                          duration: const Duration(milliseconds: 500),
                          curve: Curves.easeIn,
                        );
                      }
                    },
                    child: Text(currentIndex == 4 ? 'Finish' : 'Next'),
                  ),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  OnBoardingData.onBoardingList.length,
                  (index) => DotIndicator(isActive: index == currentIndex),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _seenOnBoarding() async {
    SharedPreferences preference = await SharedPreferences.getInstance();
    preference.setBool('firstTime', false);
    Navigator.pushNamed(context, LayoutView.routeName);
  }
}
