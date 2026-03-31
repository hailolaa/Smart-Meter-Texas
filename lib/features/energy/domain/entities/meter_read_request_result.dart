class MeterReadRequestResult {
  const MeterReadRequestResult({
    required this.message,
    this.lockedUntil,
  });

  final String message;
  final DateTime? lockedUntil;
}
