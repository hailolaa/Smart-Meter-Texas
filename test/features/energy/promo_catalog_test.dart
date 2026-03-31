import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_meter_texas/core/settings/app_settings_store.dart';
import 'package:smart_meter_texas/features/energy/data/repositories/promo_catalog.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppSettingsStore.instance.load();
  });

  test('catalog returns at least 2 offers', () {
    final offers = PromoCatalog.pickTopOffers(settings: AppSettingsStore.instance);
    expect(offers.length, greaterThanOrEqualTo(2));
  });

  test('offers rotate by day', () {
    final first = PromoCatalog.pickTopOffers(
      settings: AppSettingsStore.instance,
      now: DateTime(2026, 1, 1),
    );
    final second = PromoCatalog.pickTopOffers(
      settings: AppSettingsStore.instance,
      now: DateTime(2026, 1, 2),
    );
    expect(first.first.title, isNot(second.first.title));
  });
}
