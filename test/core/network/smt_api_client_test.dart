import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_meter_texas/core/network/smt_api_client.dart';
import 'package:smart_meter_texas/core/session/smt_session_store.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SmtSessionStore.instance.load();
  });

  test('requests use 12 second timeout constant', () {
    expect(SmtApiClient.requestTimeout, const Duration(seconds: 12));
  });

  test('new session header updates store', () async {
    final store = SmtSessionStore.instance;
    await store.saveSession(
      sessionId: 'old-session',
      esiid: '123',
      jwtToken: 'jwt',
      userId: 1,
    );

    final client = MockClient((request) async {
      return http.Response(
        jsonEncode({
          'success': true,
          'data': {'userId': 1, 'esiid': '123'}
        }),
        200,
        headers: {'x-smt-new-session-id': 'new-session'},
      );
    });
    final api = SmtApiClient(httpClient: client, sessionStore: store);
    await api.getMe();
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(store.sessionId, 'new-session');
  });
}
