import '../../../../core/network/smt_api_client.dart';
import '../../../../core/session/smt_session_store.dart';
import '../../domain/entities/usage_history_overview.dart';

class BackendHistoryRepository {
  BackendHistoryRepository({
    SmtApiClient? apiClient,
    SmtSessionStore? sessionStore,
  })  : _apiClient = apiClient ?? SmtApiClient(),
        _sessionStore = sessionStore ?? SmtSessionStore.instance;

  final SmtApiClient _apiClient;
  final SmtSessionStore _sessionStore;

  /// Fetches usage overview from the DB-backed endpoint (instant, cached data).
  Future<UsageHistoryOverview> fetchOverview() async {
    final jwtToken = _sessionStore.jwtToken;
    if (jwtToken == null || jwtToken.isEmpty) {
      throw Exception('Not logged in. Please log in again.');
    }

    final response = await _apiClient.getUserUsageHistory(days: 30);
    final data = response['data'] as Map<String, dynamic>? ?? {};

    final yesterday = data['yesterday'] as Map<String, dynamic>? ?? {};
    final last7 = data['last7Days'] as Map<String, dynamic>? ?? {};
    final last30 = data['last30Days'] as Map<String, dynamic>? ?? {};
    final meterRead = data['latestMeterRead'] as Map<String, dynamic>?;

    return UsageHistoryOverview(
      yesterdayKwh: _toDouble(yesterday['kwh']),
      last7DaysKwh: _toDouble(last7['kwh']),
      last30DaysKwh: _toDouble(last30['kwh']),
      yesterdayCost: _toDouble(yesterday['cost']),
      last7DaysCost: _toDouble(last7['cost']),
      last30DaysCost: _toDouble(last30['cost']),
      yesterdayDays: _toInt(yesterday['days']),
      last7Days: _toInt(last7['days']),
      last30Days: _toInt(last30['days']),
      latestDate: data['latestDate']?.toString(),
      latestMeterReadKwh:
          meterRead != null ? _toDouble(meterRead['readingKwh']) : null,
      latestMeterReadAt: meterRead?['readAt']?.toString(),
    );
  }

  double _toDouble(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0.0;
    return 0.0;
  }

  int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }
}
