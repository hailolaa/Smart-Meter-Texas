class TrialLogic {
  const TrialLogic._();

  static bool isTrialActive(DateTime? startedAt, {DateTime? now}) {
    if (startedAt == null) return false;
    final current = now ?? DateTime.now();
    return current.isBefore(startedAt.add(const Duration(days: 7)));
  }

  static int daysRemaining(DateTime? startedAt, {DateTime? now}) {
    if (startedAt == null) return 0;
    final current = now ?? DateTime.now();
    final expiry = startedAt.add(const Duration(days: 7));
    final remaining = expiry.difference(current).inDays + 1;
    if (remaining < 0) return 0;
    return remaining;
  }
}
