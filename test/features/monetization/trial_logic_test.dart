import 'package:flutter_test/flutter_test.dart';
import 'package:smart_meter_texas/features/monetization/domain/trial_logic.dart';

void main() {
  final now = DateTime.utc(2026, 1, 8);

  test('trial is active within 7 days of start', () {
    final start = now.subtract(const Duration(days: 3));
    expect(TrialLogic.isTrialActive(start, now: now), isTrue);
  });

  test('trial is expired after 7 days', () {
    final start = now.subtract(const Duration(days: 8));
    expect(TrialLogic.isTrialActive(start, now: now), isFalse);
  });

  test('trial days remaining calculates correctly', () {
    final start = now.subtract(const Duration(days: 5));
    expect(TrialLogic.daysRemaining(start, now: now), 3);
  });

  test('edge: trial expires at exact 7-day boundary', () {
    final start = now.subtract(const Duration(days: 7));
    expect(TrialLogic.isTrialActive(start, now: now), isFalse);
  });

  test('null trialStartDate treats as no trial', () {
    expect(TrialLogic.isTrialActive(null, now: now), isFalse);
    expect(TrialLogic.daysRemaining(null, now: now), 0);
  });
}
