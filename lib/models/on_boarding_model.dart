import 'package:islami1/core/constants/assets.dart';

class OnBoardingData {
  String imagePath;
  String title;
  String? description;

  OnBoardingData({
    required this.imagePath,
    required this.title,
    this.description,
  });

  static List<OnBoardingData> onBoardingList = [
    OnBoardingData(
      imagePath: Assets.onBoarding1,
      title: 'Welcome To Islmi App',
    ),
    OnBoardingData(
      imagePath: Assets.onBoarding2,
      title: 'Welcome To Islmi App',
      description: 'We Are Very Excited To Have You In Our Community',
    ),
    OnBoardingData(
      imagePath: Assets.onBoarding3,
      title: 'Reading the Quran',
      description: 'Read, and your Lord is the Most Generous',
    ),
    OnBoardingData(
      imagePath: Assets.onBoarding4,
      title: 'Bearish',
      description: 'Praise the name of your Lord, the Most High',
    ),
    OnBoardingData(
      imagePath: Assets.onBoarding5,
      title: 'Holy Quran Radio',
      description:
          'You can listen to the Holy Quran Radio through the application for free and easily',
    ),
  ];
}
