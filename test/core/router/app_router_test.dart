import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_meter_texas/core/router/app_router.dart';
import 'package:smart_meter_texas/core/router/app_routes.dart';
import 'package:smart_meter_texas/core/settings/app_settings_store.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppSettingsStore.instance.load();
  });

  test('first-time user routes to /home-type after login', () async {
    await AppSettingsStore.instance.setHasCompletedOnboarding(false);
    final route = resolveAuthenticatedLandingRoute(AppSettingsStore.instance);
    expect(route, AppRoutes.homeType);
  });

  test('returning user with active trial routes to dashboard', () async {
    await AppSettingsStore.instance.setHasCompletedOnboarding(true);
    await AppSettingsStore.instance.ensureTrialStarted();
    final route = resolveAuthenticatedLandingRoute(AppSettingsStore.instance);
    expect(route, AppRoutes.dashboard);
  });
}
