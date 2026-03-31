class MockSmtSessionStore {
  String? sessionId;
  String? esiid;
  String? meterNumber;
  String? jwtToken;
  int? userId;
  DateTime? meterReadLockedUntil;

  Future<void> saveSession({
    required String sessionId,
    String? esiid,
    String? meterNumber,
    String? jwtToken,
    int? userId,
  }) async {
    this.sessionId = sessionId;
    this.esiid = esiid;
    this.meterNumber = meterNumber;
    this.jwtToken = jwtToken;
    this.userId = userId;
  }
}
