import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> pumpApp(
  WidgetTester tester, {
  required Widget child,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: child,
    ),
  );
}
