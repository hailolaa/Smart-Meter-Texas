import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_meter_texas/core/settings/app_settings_store.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppSettingsStore.instance.load();
  });

  test('saves and loads homeType', () async {
    await AppSettingsStore.instance.setHomeType('house');
    await AppSettingsStore.instance.load();
    expect(AppSettingsStore.instance.homeType, 'house');
  });

  test('saves and loads networkState', () async {
    await AppSettingsStore.instance.setNetworkState('texas');
    await AppSettingsStore.instance.load();
    expect(AppSettingsStore.instance.networkState, 'texas');
  });

  test('saves and loads tdspCompany', () async {
    await AppSettingsStore.instance.setTdspCompany('oncor');
    await AppSettingsStore.instance.load();
    expect(AppSettingsStore.instance.tdspCompany, 'oncor');
  });

  test('saves and loads retailProvider', () async {
    await AppSettingsStore.instance.setRetailProvider('txu');
    await AppSettingsStore.instance.load();
    expect(AppSettingsStore.instance.retailProvider, 'txu');
  });

  test('hasCompletedOnboarding is false by default', () async {
    await AppSettingsStore.instance.load();
    expect(AppSettingsStore.instance.hasCompletedOnboarding, isFalse);
  });

  test('hasCompletedOnboarding becomes true when explicitly set', () async {
    await AppSettingsStore.instance.setHasCompletedOnboarding(true);
    await AppSettingsStore.instance.load();
    expect(AppSettingsStore.instance.hasCompletedOnboarding, isTrue);
  });
}
