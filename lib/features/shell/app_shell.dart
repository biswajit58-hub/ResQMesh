import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../services/app_state.dart';
import '../alerts/alerts_screen.dart';
import '../hazard_mapping/map_screen.dart';
import '../home/home_screen.dart';
import '../more/more_screen.dart';
import '../shelters/shelter_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;
  final Set<int> _visited = {0};
  AppState? _state;
  String? _shownNotice;
  bool _locationRequested = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _state = context.read<AppState>();
      _state?.addListener(_onState);
      if (!_locationRequested) {
        _locationRequested = true;
        final current = _state?.currentLocation;
        if (current == null) {
          _state?.acquireLocation(requestPermission: false);
        }
      }
    });
  }

  void _onState() {
    final notice = _state?.notice;
    if (notice == null) {
      _shownNotice = null;
      return;
    }
    if (!mounted || notice == _shownNotice) return;
    _shownNotice = notice;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.notifications_active_rounded,
                  color: AppColors.cyan, size: 17),
              const SizedBox(width: 8),
              Expanded(child: Text(notice)),
            ],
          ),
          duration: const Duration(seconds: 4),
        ),
      );
      _state?.clearNotice();
    });
  }

  @override
  void dispose() {
    _state?.removeListener(_onState);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final tabs = const [
      HomeScreen(),
      MapScreen(),
      AlertsScreen(),
      ShelterScreen(),
      MoreScreen(),
    ];
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: AppColors.surface,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: PopScope(
        canPop: _index == 0,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop && _index != 0) {
            setState(() => _index = 0);
          }
        },
        child: Scaffold(
          backgroundColor: AppColors.background,
          body: IndexedStack(
            index: _index,
            children: [
              for (var i = 0; i < tabs.length; i++)
                _visited.contains(i) ? tabs[i] : const SizedBox.shrink(),
            ],
          ),
          bottomNavigationBar: Container(
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: (index) => setState(() {
                _index = index;
                _visited.add(index);
              }),
              destinations: [
                NavigationDestination(
                  icon: const Icon(Icons.grid_view_rounded),
                  selectedIcon: const Icon(Icons.grid_view_rounded),
                  label: context.tr('home'),
                ),
                NavigationDestination(
                  icon: const Icon(Icons.map_outlined),
                  selectedIcon: const Icon(Icons.map_rounded),
                  label: context.tr('map'),
                ),
                NavigationDestination(
                  icon: Badge(
                    isLabelVisible: state.activeIncidents.isNotEmpty,
                    label: Text('${state.activeIncidents.length}'),
                    backgroundColor: AppColors.red,
                    child: const Icon(Icons.notifications_none_rounded),
                  ),
                  selectedIcon: Badge(
                    isLabelVisible: state.activeIncidents.isNotEmpty,
                    label: Text('${state.activeIncidents.length}'),
                    backgroundColor: AppColors.red,
                    child: const Icon(Icons.notifications_rounded),
                  ),
                  label: context.tr('alerts'),
                ),
                NavigationDestination(
                  icon: const Icon(Icons.home_work_outlined),
                  selectedIcon: const Icon(Icons.home_work_rounded),
                  label: context.tr('shelters'),
                ),
                NavigationDestination(
                  icon: const Icon(Icons.widgets_outlined),
                  selectedIcon: const Icon(Icons.widgets_rounded),
                  label: context.tr('more'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
