import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_meter_texas/core/session/smt_session_store.dart';
import 'package:smart_meter_texas/features/onboarding/presentation/screens/meter_details.dart';
import 'package:flutter/material.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SmtSessionStore.instance.load();
  });

  GoRouter buildRouter() {
    return GoRouter(
      routes: [
        GoRoute(path: '/', builder: (context, state) => const MeterDetailsScreen()),
        GoRoute(path: '/provider', builder: (context, state) => const SizedBox.shrink()),
      ],
    );
  }

  testWidgets('meter number input saves to SmtSessionStore on confirm', (tester) async {
    await tester.pumpWidget(MaterialApp.router(routerConfig: buildRouter()));
    await tester.enterText(find.byType(TextField).first, '1234567890');
    await tester.tap(find.text('Confirm & Continue'));
    await tester.pumpAndSettle();
    expect(SmtSessionStore.instance.meterNumber, '1234567890');
  });

  testWidgets('empty meter number shows validation error', (tester) async {
    await tester.pumpWidget(MaterialApp.router(routerConfig: buildRouter()));
    await tester.tap(find.text('Confirm & Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Please enter your meter number.'), findsOneWidget);
  });
}
