import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/constants/prefs_keys.dart';
import '../../../core/services/notification_refresh.dart';
import '../../../core/services/prayer_times_service.dart';
import '../../../core/services/shared_prefs_helper.dart';
import '../../../core/state/settings_cubit.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/l10n_ext.dart';
import '../../../models/on_boarding_model.dart';
import '../../settings/prayer_notifications_prompt.dart';
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

  /// The slides, then one page that sets up location and the adhan.
  int get _lastIndex => OnBoardingSlide.values.length;

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
                itemCount: pages.length + 1,
                // Driven from onPageChanged rather than a scroll listener that
                // called setState on every pixel of the drag.
                onPageChanged: (index) =>
                    setState(() => _currentIndex = index),
                itemBuilder: (context, index) {
                  if (index == pages.length) return const _SetupPage();
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
                        pages.length + 1,
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

/// The last onboarding page: the two things without which prayer times are
/// wrong and the adhan never sounds. Both are optional and can be done later
/// from Settings and the Prayer tab.
class _SetupPage extends StatefulWidget {
  const _SetupPage();

  @override
  State<_SetupPage> createState() => _SetupPageState();
}

class _SetupPageState extends State<_SetupPage> {
  bool _locating = false;
  PrayerLocation _location = PrayerTimesService.currentLocation();

  Future<void> _locate() async {
    setState(() => _locating = true);
    final fresh = await PrayerTimesService.refreshLocation();
    if (!mounted) return;
    setState(() {
      _location = fresh;
      _locating = false;
    });
    // The times move with the place, and so does the adhan if it is on.
    final settings = context.read<SettingsCubit>().state;
    NotificationRefresh.reschedule(settings, Localizations.localeOf(context));
    if (fresh.isFallback && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.setupLocationFailed)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = context.colors;
    final notificationsOn = context.select<SettingsCubit, bool>((c) => c.state.prayerNotifications);
    final located = !_location.isFallback;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        children: [
          CircleAvatar(
            radius: 44,
            backgroundColor: scheme.primaryContainer,
            child: Icon(Icons.mosque_outlined, size: 44, color: scheme.onPrimaryContainer),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            l10n.setupTitle,
            textAlign: TextAlign.center,
            style: context.texts.headlineSmall?.copyWith(color: scheme.primary),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            l10n.setupBody,
            textAlign: TextAlign.center,
            style: context.texts.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.xl),
          _SetupStep(
            icon: Icons.my_location,
            title: l10n.setupLocationTitle,
            body: located ? (_location.name ?? l10n.setupLocationDone) : l10n.setupLocationBody,
            done: located,
            busy: _locating,
            action: l10n.setupLocationAction,
            onPressed: _locate,
          ),
          const SizedBox(height: AppSpacing.md),
          _SetupStep(
            icon: Icons.notifications_active_outlined,
            title: l10n.setupAdhanTitle,
            body: notificationsOn ? l10n.setupAdhanDone : l10n.setupAdhanBody,
            done: notificationsOn,
            action: l10n.setupAdhanAction,
            onPressed: () => turnOnPrayerNotifications(context),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            l10n.setupLater,
            textAlign: TextAlign.center,
            style: context.texts.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _SetupStep extends StatelessWidget {
  const _SetupStep({
    required this.icon,
    required this.title,
    required this.body,
    required this.done,
    required this.action,
    required this.onPressed,
    this.busy = false,
  });

  final IconData icon;
  final String title;
  final String body;
  final bool done;
  final bool busy;
  final String action;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    return Card(
      color: done ? scheme.primaryContainer : scheme.surfaceContainer,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          children: [
            Icon(done ? Icons.check_circle : icon, color: scheme.primary, size: 28),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: context.texts.titleMedium),
                  const SizedBox(height: 2),
                  Text(body, style: context.texts.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                ],
              ),
            ),
            if (!done) ...[
              const SizedBox(width: AppSpacing.sm),
              busy
                  ? const SizedBox.square(dimension: 24, child: CircularProgressIndicator(strokeWidth: 2.5))
                  : FilledButton.tonal(onPressed: onPressed, child: Text(action)),
            ],
          ],
        ),
      ),
    );
  }
}
