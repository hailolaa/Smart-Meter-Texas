import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('applicationId is not com.example', () {
    final file = File('android/app/build.gradle.kts');
    final text = file.readAsStringSync();
    expect(text.contains('applicationId = "com.example'), isFalse);
  });

  test('android label is ElectricToday and INTERNET permission exists', () {
    final file = File('android/app/src/main/AndroidManifest.xml');
    final text = file.readAsStringSync();
    expect(text.contains('android:label="ElectricToday"'), isTrue);
    expect(text.contains('android.permission.INTERNET'), isTrue);
  });

  test('pubspec version is >= 1.0.0', () {
    final file = File('pubspec.yaml');
    final text = file.readAsStringSync();
    expect(text.contains('version: 1.0.0+1'), isTrue);
  });
}
