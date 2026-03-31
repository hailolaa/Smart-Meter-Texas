import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_meter_texas/core/settings/app_settings_store.dart';
import 'package:smart_meter_texas/features/monetization/presentation/screens/paywall_screen.dart';

void main() {
  Future<void> pumpPaywall(WidgetTester tester) async {
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (context, state) => const PaywallScreen()),
        GoRoute(path: '/dashboard', builder: (context, state) => const SizedBox.shrink()),
      ],
    );
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
  }

  testWidgets('shows Continue to Dashboard during active trial', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await AppSettingsStore.instance.load();
    await AppSettingsStore.instance.ensureTrialStarted();
    await pumpPaywall(tester);
    expect(find.text('Continue to Dashboard'), findsOneWidget);
  });

  testWidgets('shows subscription options after trial expires', (tester) async {
    SharedPreferences.setMockInitialValues({
      'settings_trial_start_date': DateTime.now()
          .subtract(const Duration(days: 9))
          .toUtc()
          .toIso8601String(),
    });
    await AppSettingsStore.instance.load();
    await pumpPaywall(tester);
    expect(find.text('Start 1 Week Free Trial'), findsOneWidget);
  });
}
