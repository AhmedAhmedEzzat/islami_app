import 'package:flutter/material.dart';

import '../../models/quran_open_request.dart';
import 'quran/quran_details_view.dart';

/// Tracks the topmost route of one tab.
///
/// Needed so the layout can answer three questions honestly: can this tab pop,
/// should re-tapping the tab reset it, and is the sura being recited already
/// the visible page (so the mini player should stay hidden).
class TabRouteObserver extends NavigatorObserver with ChangeNotifier {
  Route<dynamic>? _top;

  Route<dynamic>? get top => _top;

  /// True when this tab is showing the details page for [suraId].
  bool showsSura(String? suraId) {
    if (suraId == null) return false;
    final settings = _top?.settings;
    if (settings?.name != QuranDetailsView.routeName) return false;
    return QuranOpenRequest.suraOf(settings?.arguments)?.suraID == suraId;
  }

  /// True when the top route of this tab is the named one.
  bool showsRoute(String name) => _top?.settings.name == name;

  void _update(Route<dynamic>? route) {
    if (identical(route, _top)) return;
    _top = route;
    notifyListeners();
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _update(route);

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _update(previousRoute);

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _update(previousRoute);

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) =>
      _update(newRoute);
}

/// One tab's own navigation stack.
///
/// Giving each tab its own [Navigator] is what keeps the bottom bar visible
/// while a sura, hadeth or azkar page is open: the pushed route renders inside
/// the tab rather than on top of the whole app.
class TabNavigator extends StatelessWidget {
  const TabNavigator({
    super.key,
    required this.navigatorKey,
    required this.observer,
    required this.root,
  });

  final GlobalKey<NavigatorState> navigatorKey;
  final TabRouteObserver observer;
  final Widget root;

  @override
  Widget build(BuildContext context) {
    return HeroControllerScope(
      // Nested navigators do not inherit MaterialApp's hero controller, and a
      // controller cannot be shared between navigators.
      controller: MaterialApp.createMaterialHeroController(),
      child: Navigator(
        key: navigatorKey,
        observers: [observer],
        onGenerateRoute: (settings) {
          if (settings.name == QuranDetailsView.routeName) {
            return MaterialPageRoute<void>(
              // `settings` must be forwarded or QuranDetailsView loses the
              // SuraDataModel argument it reads in didChangeDependencies.
              settings: settings,
              builder: (_) => const QuranDetailsView(),
            );
          }
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => root,
          );
        },
      ),
    );
  }
}
