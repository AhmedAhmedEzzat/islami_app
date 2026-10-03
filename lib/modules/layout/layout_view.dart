import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/constants/constants.dart';
import '../../core/state/now_playing.dart';
import '../../core/state/quran_player_cubit.dart';
import '../../core/state/quran_player_state.dart';
import '../../core/state/radio_cubit.dart';
import '../../core/state/radio_state.dart';
import '../../models/quran_open_request.dart';
import '../../models/radio_channel.dart';
import '../../core/services/recent_suras.dart';
import '../../models/sura_data_model.dart';
import '../home/home_view.dart';
import '../more/more_view.dart';
import 'azkar/azkar_tab_view.dart';
import 'layout_scope.dart';
import 'quran/quran_details_view.dart';
import 'quran/quran_view.dart';
import 'radio/radio_view.dart';
import 'tab_navigator.dart';
import 'time/time_view.dart';
import 'widgets/now_playing_bar.dart';
import '../../core/utils/l10n_ext.dart';

class LayoutView extends StatefulWidget {
  static const String routeName = '/layout';

  const LayoutView({super.key});

  @override
  State<LayoutView> createState() => _LayoutViewState();
}

class _LayoutViewState extends State<LayoutView> {
  int _selectedIndex = AppTab.home;

  // Order must match AppTab.
  static const List<Widget> _roots = [
    HomeView(),
    QuranView(),
    TimeView(),
    AzkarTabView(),
    MoreView(),
  ];

  late final List<GlobalKey<NavigatorState>> _navKeys = List.generate(
    _roots.length,
    (_) => GlobalKey<NavigatorState>(),
  );

  late final List<TabRouteObserver> _observers = List.generate(
    _roots.length,
    (_) => TabRouteObserver(),
  );

  /// A tab is built the first time it is opened and kept alive afterwards.
  ///
  /// IndexedStack alone would build all five at launch, which would start the
  /// prayer-times ticker and ask for location before the user ever opens the
  /// Time tab.
  late final List<bool> _visited = List.generate(
    _roots.length,
    (i) => i == AppTab.home,
  );

  @override
  void initState() {
    super.initState();
    // canPop below is read by the framework before a predictive-back gesture
    // starts, so it must never be stale.
    for (final observer in _observers) {
      observer.addListener(_onRouteChanged);
    }
  }

  @override
  void dispose() {
    for (final observer in _observers) {
      observer
        ..removeListener(_onRouteChanged)
        ..dispose();
    }
    super.dispose();
  }

  void _onRouteChanged() {
    if (!mounted) return;
    // The observers fire didPush while the tab navigators are building their
    // initial routes, so a bare setState here would run during build.
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
      return;
    }
    setState(() {});
  }

  NavigatorState? get _activeNavigator => _navKeys[_selectedIndex].currentState;

  /// Only let the app close from Home with nothing pushed on it.
  bool get _canPopApp =>
      _selectedIndex == AppTab.home &&
      !(_navKeys[AppTab.home].currentState?.canPop() ?? false);

  void _handlePop(bool didPop) {
    if (didPop) return;
    final navigator = _activeNavigator;
    if (navigator != null && navigator.canPop()) {
      navigator.pop();
      return;
    }
    setState(() => _selectedIndex = AppTab.home);
  }

  void _selectTab(int index) {
    if (index == _selectedIndex) return;
    setState(() {
      _visited[index] = true;
      _selectedIndex = index;
    });
  }

  /// Runs [action] on [tab]'s navigator, waiting a frame if the tab is being
  /// built for the first time and its navigator does not exist yet.
  void _withNavigator(int tab, void Function(NavigatorState navigator) action) {
    final navigator = _navKeys[tab].currentState;
    if (navigator != null) {
      action(navigator);
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final navigator = _navKeys[tab].currentState;
      if (navigator != null) action(navigator);
    });
  }

  /// Opens [sura] in the Quran tab, from wherever the request came from.
  void _openSura(SuraDataModel sura, {int? ayah}) {
    _selectTab(AppTab.quran);
    // Already looking at it — pushing again would stack a duplicate.
    if (ayah == null && _observers[AppTab.quran].showsSura(sura.suraID)) return;
    RecentSuras.remember(sura);
    _withNavigator(AppTab.quran, (navigator) {
      navigator
        ..popUntil((route) => route.isFirst)
        ..pushNamed(
          QuranDetailsView.routeName,
          arguments: QuranOpenRequest(sura, ayah: ayah),
        );
    });
  }

  void _onDestinationSelected(int index) {
    if (index == _selectedIndex) {
      // Re-tapping the active tab returns it to its root.
      _navKeys[index].currentState?.popUntil((route) => route.isFirst);
      return;
    }
    _selectTab(index);
  }

  void _openNowPlaying(NowPlaying playing) {
    if (playing.source == NowPlayingSource.radio) {
      // Radio lives under More. If it is open on another tab, go there.
      for (var tab = 0; tab < _roots.length; tab++) {
        if (_observers[tab].showsRoute(RadioView.routeName)) {
          _selectTab(tab);
          return;
        }
      }
      _selectTab(AppTab.more);
      _withNavigator(AppTab.more, (navigator) {
        navigator
          ..popUntil((route) => route.isFirst)
          ..push(
            MaterialPageRoute<void>(
              settings: const RouteSettings(name: RadioView.routeName),
              builder: (_) => const RadioView(),
            ),
          );
      });
      return;
    }

    final id = int.tryParse(playing.suraId ?? '');
    if (id == null || id < 1 || id > Constants.suraDataLists.length) return;
    final sura = Constants.suraDataLists[id - 1];
    if (_observers[AppTab.quran].showsSura(sura.suraID)) {
      _selectTab(AppTab.quran);
      return;
    }
    final ayah = playing.ayah;
    _openSura(sura, ayah: (ayah ?? 0) > 0 ? ayah : null);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // A single PopScope for the whole layout: IndexedStack keeps offstage
      // tabs mounted, so one per tab would all register at once and a hidden
      // tab could swallow the back gesture.
      canPop: _canPopApp,
      onPopInvokedWithResult: (didPop, _) => _handlePop(didPop),
      child: LayoutScope(
        selectTab: _selectTab,
        openSura: _openSura,
        child: Scaffold(
          body: IndexedStack(
            index: _selectedIndex,
            children: [
              for (var i = 0; i < _roots.length; i++)
                if (_visited[i])
                  TabNavigator(
                    navigatorKey: _navKeys[i],
                    observer: _observers[i],
                    root: _roots[i],
                  )
                else
                  const SizedBox.shrink(),
            ],
          ),
          bottomNavigationBar: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildNowPlaying(),
              NavigationBar(
                selectedIndex: _selectedIndex,
                onDestinationSelected: _onDestinationSelected,
                destinations: [
                  NavigationDestination(
                    icon: const Icon(Icons.home_outlined),
                    selectedIcon: const Icon(Icons.home),
                    label: context.l10n.tabHome,
                  ),
                  NavigationDestination(
                    icon: const Icon(Icons.menu_book_outlined),
                    selectedIcon: const Icon(Icons.menu_book),
                    label: context.l10n.tabQuran,
                  ),
                  NavigationDestination(
                    icon: const Icon(Icons.access_time_outlined),
                    selectedIcon: const Icon(Icons.access_time_filled),
                    label: context.l10n.tabPrayer,
                  ),
                  NavigationDestination(
                    icon: const Icon(Icons.radio_button_checked_outlined),
                    selectedIcon: const Icon(Icons.radio_button_checked),
                    label: context.l10n.tabAzkar,
                  ),
                  NavigationDestination(
                    icon: const Icon(Icons.apps_outlined),
                    selectedIcon: const Icon(Icons.apps),
                    label: context.l10n.tabMore,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNowPlaying() {
    return BlocBuilder<QuranPlayerCubit, QuranPlayerState>(
      builder: (context, quran) {
        return BlocBuilder<RadioCubit, RadioState>(
          builder: (context, radio) {
            final playing = deriveNowPlaying(
              quran: quran,
              radio: radio,
              suraTitle: (id) {
                final index = int.tryParse(id);
                if (index == null ||
                    index < 1 ||
                    index > Constants.suraDataLists.length) {
                  return context.l10n.quranTitle;
                }
                final sura = Constants.suraDataLists[index - 1];
                return context.isArabic ? sura.suraNameAR : sura.suraNameEN;
              },
              stationTitle: (index) => RadioChannel.channels[index].name,
            );

            // Hide it when the page already on screen owns this player, so
            // the sura's own seek bar is not duplicated.
            final visible = _observers[_selectedIndex];
            final alreadyVisible =
                (playing?.source == NowPlayingSource.recitation &&
                    visible.showsSura(playing?.suraId)) ||
                (playing?.source == NowPlayingSource.radio &&
                    visible.showsRoute(RadioView.routeName));

            return NowPlayingBar(
              nowPlaying: alreadyVisible ? null : playing,
              onTap: () => playing == null ? null : _openNowPlaying(playing),
              onTogglePlay: () {
                if (playing == null) return;
                if (playing.source == NowPlayingSource.radio) {
                  final index = radio.currentIndex;
                  if (index != null) context.read<RadioCubit>().toggle(index);
                } else {
                  context.read<QuranPlayerCubit>().togglePlayPause();
                }
              },
              onStop: () {
                if (playing == null) return;
                if (playing.source == NowPlayingSource.radio) {
                  context.read<RadioCubit>().stop();
                } else {
                  context.read<QuranPlayerCubit>().stop();
                }
              },
            );
          },
        );
      },
    );
  }
}
