import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_meter_texas/core/network/smt_api_client.dart';
import 'package:smart_meter_texas/core/session/smt_session_store.dart';
import 'package:smart_meter_texas/core/settings/app_settings_store.dart';
import 'package:smart_meter_texas/features/alerts/presentation/screens/alerts_screen.dart';

class _FakeApiClient extends SmtApiClient {
  @override
  Future<Map<String, dynamic>> getUserUsageHistory({int days = 30}) async {
    return {
      'success': true,
      'data': {'dailyPoints': []}
    };
  }

  @override
  Future<Map<String, dynamic>> getUsage({String? esiid}) async {
    return {
      'success': true,
      'data': {
        'result': {'usage': 0}
      }
    };
  }

  @override
  Future<Map<String, dynamic>> getEnergyTrends() async {
    return {
      'success': true,
      'data': {'percentVsYesterday': 0, 'costTrend': 0}
    };
  }

  @override
  Future<Map<String, dynamic>> getOdrRateLimit() async {
    return {
      'success': true,
      'data': {'lockedUntil': null}
    };
  }
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SmtSessionStore.instance.load();
    await AppSettingsStore.instance.load();
  });

  testWidgets('empty state shows themed placeholder', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AlertsScreen(apiClient: _FakeApiClient()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('No alerts right now'), findsOneWidget);
  });

  testWidgets('pull-to-refresh keeps list interactive', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AlertsScreen(apiClient: _FakeApiClient()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.drag(find.text('Recent Alerts'), const Offset(0, 300));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Recent Alerts'), findsOneWidget);
  });
}
