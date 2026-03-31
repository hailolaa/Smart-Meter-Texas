import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_meter_texas/core/network/energy_realtime_client.dart';
import 'package:smart_meter_texas/core/network/smt_api_client.dart';
import 'package:smart_meter_texas/core/session/smt_session_store.dart';
import 'package:smart_meter_texas/features/energy/presentation/screens/usage_details_screen.dart';

class _FakeRealtimeClient implements EnergyRealtimeClient {
  final _controller = StreamController<EnergyRealtimeMessage>.broadcast();

  @override
  Stream<EnergyRealtimeMessage> connect({required String jwtToken}) => _controller.stream;

  void emit() {
    _controller.add(
      const EnergyRealtimeMessage(
        type: 'history_changed',
        sequence: 1,
        data: {'kwhToday': 5.0},
      ),
    );
  }

  @override
  void disconnect() {}

  @override
  Future<void> dispose() async {
    await _controller.close();
  }
}

class _FakeHttpClient extends http.BaseClient {
  int userUsageHistoryCalls = 0;
  int smtUsageHistoryCalls = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final path = request.url.path;
    if (path.endsWith('/api/user/usage/history')) {
      userUsageHistoryCalls += 1;
      return _jsonResponse({
        'success': true,
        'data': {
          'latestDate': '2026-03-30',
          'dailyPoints': [
            {'date': '2026-03-29', 'kwh': 4.2},
            {'date': '2026-03-30', 'kwh': 5.1},
          ],
        },
      });
    }

    if (path.endsWith('/api/smt/usage/history')) {
      smtUsageHistoryCalls += 1;
      return _jsonResponse({
        'success': true,
        'data': {
          'result': {'points': []}
        },
      });
    }

    return _jsonResponse({
      'success': true,
      'data': {},
    });
  }

  Future<http.StreamedResponse> _jsonResponse(Map<String, dynamic> payload) async {
    final body = utf8.encode(jsonEncode(payload));
    return http.StreamedResponse(
      Stream<List<int>>.fromIterable([body]),
      200,
      headers: {'content-type': 'application/json'},
    );
  }
}

void main() {
  testWidgets('usage details refreshes when realtime event arrives', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await SmtSessionStore.instance.load();
    await SmtSessionStore.instance.saveSession(
      sessionId: 'session-1',
      esiid: '12345678901234567',
      jwtToken: 'jwt-1',
      userId: 1,
    );

    final httpClient = _FakeHttpClient();
    final apiClient = SmtApiClient(httpClient: httpClient);
    final realtimeClient = _FakeRealtimeClient();

    await tester.pumpWidget(
      MaterialApp(
        home: UsageDetailsScreen(
          apiClient: apiClient,
          realtimeClient: realtimeClient,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final before = httpClient.userUsageHistoryCalls;
    expect(before, greaterThan(0));

    realtimeClient.emit();
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pumpAndSettle();

    expect(httpClient.userUsageHistoryCalls, greaterThan(before));
  });
}
