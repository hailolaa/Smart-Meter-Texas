class MockSmtApiClient {
  Map<String, dynamic> usageResponse = {};
  Map<String, dynamic> historyResponse = {};
  Map<String, dynamic> trendResponse = {};
  Map<String, dynamic> rateLimitResponse = {};

  Future<Map<String, dynamic>> getUsage() async => usageResponse;
  Future<Map<String, dynamic>> getUserUsageHistory({int days = 30}) async => historyResponse;
  Future<Map<String, dynamic>> getEnergyTrends() async => trendResponse;
  Future<Map<String, dynamic>> getOdrRateLimit() async => rateLimitResponse;
}
