import '../core/constants/assets.dart';

/// Onboarding slides. The copy lives in the ARB files; this only holds the
/// artwork and an identifier the view maps to localized strings.
enum OnBoardingSlide {
  welcome(Assets.onBoarding1),
  readListen(Assets.onBoarding2),
  ahadeth(Assets.onBoarding3),
  tasbeh(Assets.onBoarding4),
  timesRadio(Assets.onBoarding5);

  const OnBoardingSlide(this.imagePath);

  final String imagePath;
}
