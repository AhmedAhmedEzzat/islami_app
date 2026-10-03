import 'package:flutter/material.dart';

import '../../../core/constants/prefs_keys.dart';
import '../../../core/services/shared_prefs_helper.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/l10n_ext.dart';
import '../../../models/on_boarding_model.dart';
import '../layout_view.dart';
import 'dot_indicator.dart';

class OnBoardingScreen extends StatefulWidget {
  static const String routeName = '/onboarding';

  const OnBoardingScreen({super.key});

  @override
  State<OnBoardingScreen> createState() => _OnBoardingScreenState();
}

class _OnBoardingScreenState extends State<OnBoardingScreen> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;

  int get _lastIndex => OnBoardingSlide.values.length - 1;

  (String, String) _copy(BuildContext context, OnBoardingSlide slide) {
    final l10n = context.l10n;
    return switch (slide) {
      OnBoardingSlide.welcome => (l10n.onboard1Title, l10n.onboard1Body),
      OnBoardingSlide.readListen => (l10n.onboard2Title, l10n.onboard2Body),
      OnBoardingSlide.ahadeth => (l10n.onboard3Title, l10n.onboard3Body),
      OnBoardingSlide.tasbeh => (l10n.onboard4Title, l10n.onboard4Body),
      OnBoardingSlide.timesRadio => (l10n.onboard5Title, l10n.onboard5Body),
    };
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await LocalStorageServices.setBool(PrefsKeys.firstTime, false);
    if (!mounted) return;
    // pushReplacement, so Back cannot return to onboarding.
    Navigator.pushReplacementNamed(context, LayoutView.routeName);
  }

  void _next() {
    if (_currentIndex == _lastIndex) {
      _finish();
    } else {
      _pageController.animateToPage(
        _currentIndex + 1,
        duration: AppDurations.slow,
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final pages = OnBoardingSlide.values;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton(
                onPressed: _finish,
                child: Text(context.l10n.skip),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: pages.length,
                // Driven from onPageChanged rather than a scroll listener that
                // called setState on every pixel of the drag.
                onPageChanged: (index) =>
                    setState(() => _currentIndex = index),
                itemBuilder: (context, index) {
                  final page = pages[index];
                  final (title, body) = _copy(context, page);
                  return Padding(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    child: Column(
                      children: [
                        Expanded(
                          child: Image.asset(
                            page.imagePath,
                            excludeFromSemantics: true,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        Text(
                          title,
                          textAlign: TextAlign.center,
                          style: context.texts.headlineSmall?.copyWith(
                            color: scheme.primary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          body,
                          textAlign: TextAlign.center,
                          style: context.texts.bodyLarge?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                children: [
                  SizedBox(
                    width: 80,
                    child: _currentIndex == 0
                        ? null
                        : TextButton(
                            onPressed: () => _pageController.animateToPage(
                              _currentIndex - 1,
                              duration: AppDurations.slow,
                              curve: Curves.easeInOut,
                            ),
                            child: Text(context.l10n.back),
                          ),
                  ),
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        pages.length,
                        (i) => DotIndicator(isActive: i == _currentIndex),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 80,
                    child: Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: FilledButton(
                        onPressed: _next,
                        child: Text(
                          _currentIndex == _lastIndex
                              ? context.l10n.finish
                              : context.l10n.next,
                        ),
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
