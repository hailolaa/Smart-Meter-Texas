import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_meter_texas/features/alerts/presentation/screens/alerts_screen.dart';
import 'package:smart_meter_texas/features/energy/presentation/screens/energy_screen.dart';
import 'package:smart_meter_texas/core/navigation/presentation/screens/main_scaffold.dart';

void main() {
  testWidgets('EnergyScreen disposes cleanly', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: EnergyScreen()));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    expect(true, isTrue);
  });

  testWidgets('AlertsScreen disposes cleanly', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: AlertsScreen()));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    expect(true, isTrue);
  });

  testWidgets('MainScaffold disposes cleanly', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: MainScaffold()));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    expect(true, isTrue);
  });
}
