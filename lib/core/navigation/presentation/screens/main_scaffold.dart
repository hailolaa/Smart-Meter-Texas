import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/alerts/alerts_unread_store.dart';
import '../../../../core/settings/app_settings_store.dart';
import '../../../../features/account/presentation/screens/account_screen.dart';
import '../../../../features/alerts/presentation/screens/alerts_screen.dart';
import '../../../../features/energy/presentation/screens/energy_screen.dart';
import '../../../../features/energy/presentation/screens/usage_details_screen.dart';
import '../../../../features/history/presentation/screens/usage_history_screen.dart';
import '../widgets/app_bottom_nav.dart';

/// Provides a [switchTab] callback to any descendant widget so that
/// screens (e.g. EnergyScreen) can programmatically change the active tab.
class MainScaffoldController extends InheritedWidget {
  const MainScaffoldController({
    required this.switchTab,
    required super.child,
    super.key,
  });

  /// Call this with the desired tab index (0-4) to switch tabs.
  final void Function(int index) switchTab;

  /// Retrieve the nearest [MainScaffoldController] from the widget tree.
  static MainScaffoldController? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<MainScaffoldController>();
  }

  @override
  bool updateShouldNotify(MainScaffoldController oldWidget) => false;
}

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> with WidgetsBindingObserver {
  int _currentIndex = 0;
  int? _energyRefreshNonce = 0;
  int _alertsRefreshNonce = 0;
  int? _usageHistoryRefreshNonce = 0;
  int? _usageDetailsRefreshNonce = 0;
  int? _accountRefreshNonce = 0;
  bool _hasUnreadAlerts = false;
  StreamSubscription<bool>? _unreadSub;
  StreamSubscription<void>? _settingsSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bootstrapUnread();
    _unreadSub = AlertsUnreadStore.instance.changes.listen((hasUnread) {
      if (!mounted) return;
      setState(() => _hasUnreadAlerts = hasUnread);
    });
    // Settings edits can create/update budget-related alerts; trigger alert reload.
    _settingsSub = AppSettingsStore.instance.changes.listen((_) {
      if (!mounted) return;
      setState(() => _alertsRefreshNonce++);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (!mounted) return;
      setState(() {
        _refreshActiveTab();
      });
    }
  }

  void _refreshActiveTab() {
    if (_currentIndex == 0) {
      _energyRefreshNonce = (_energyRefreshNonce ?? 0) + 1;
    } else if (_currentIndex == 1) {
      _usageHistoryRefreshNonce = (_usageHistoryRefreshNonce ?? 0) + 1;
    } else if (_currentIndex == 2) {
      _usageDetailsRefreshNonce = (_usageDetailsRefreshNonce ?? 0) + 1;
    } else if (_currentIndex == 3) {
      _alertsRefreshNonce++;
    } else if (_currentIndex == 4) {
      _accountRefreshNonce = (_accountRefreshNonce ?? 0) + 1;
    }
  }

  Future<void> _bootstrapUnread() async {
    final hasUnread = await AlertsUnreadStore.instance.hasUnread();
    if (!mounted) return;
    setState(() => _hasUnreadAlerts = hasUnread);
  }

  void _switchTab(int index) {
    const totalTabs = 5;
    if (index >= 0 && index < totalTabs) {
      setState(() {
        _currentIndex = index;
        _refreshActiveTab();
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _unreadSub?.cancel();
    _settingsSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tabs = [
      EnergyScreen(refreshNonce: _energyRefreshNonce ?? 0),
      UsageHistoryScreen(refreshNonce: _usageHistoryRefreshNonce ?? 0),
      UsageDetailsScreen(refreshNonce: _usageDetailsRefreshNonce ?? 0),
      AlertsScreen(
        refreshNonce: _alertsRefreshNonce,
        onUnreadChanged: (hasUnread) {
          if (!mounted) return;
          setState(() => _hasUnreadAlerts = hasUnread);
        },
      ),
      AccountScreen(refreshNonce: _accountRefreshNonce ?? 0),
    ];

    return MainScaffoldController(
      switchTab: _switchTab,
      child: Scaffold(
        body: IndexedStack(index: _currentIndex, children: tabs),
        bottomNavigationBar: AppBottomNav(
          currentIndex: _currentIndex,
          hasUnreadAlerts: _hasUnreadAlerts,
          onIndexChanged: _switchTab,
        ),
      ),
    );
  }
}
