import '../../../../core/network/smt_api_client.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/session/smt_session_store.dart';
import '../../../../core/settings/app_settings_store.dart';
import '../../domain/entities/energy_summary.dart';
import '../../domain/entities/meter_read_request_result.dart';
import '../../domain/repositories/energy_repository.dart';

class BackendEnergyRepository implements EnergyRepository {
  static const double _defaultRatePerKwh = 0.15;
  static const double _defaultDailyBudget = 8.0;

  BackendEnergyRepository({
    SmtApiClient? apiClient,
    SmtSessionStore? sessionStore,
  })  : _apiClient = apiClient ?? SmtApiClient(),
        _sessionStore = sessionStore ?? SmtSessionStore.instance;

  final SmtApiClient _apiClient;
  final SmtSessionStore _sessionStore;

  @override
  Future<EnergySummary> getEnergySummary() async {
    // Ensure settings are loaded (cheap no-op on subsequent calls)
    await AppSettingsStore.instance.load();
    final ratePerKwh = AppSettingsStore.instance.ratePerKwh;
    final dailyBudget = AppSettingsStore.instance.dailyBudget;

    final sessionId = _sessionStore.sessionId;
    final esiid = _sessionStore.esiid;

    if (sessionId == null || sessionId.isEmpty) {
      throw Exception('Session expired. Please log in again.');
    }
    if (esiid == null || esiid.isEmpty) {
      throw Exception('ESIID is missing. Please re-login and provide a valid ESIID.');
    }

    Map result = const {};
    String providerMessage = '';
    var usageKwh = 0.0;
    String? readAt;

    try {
      final response = await _apiClient.getUsage(esiid: esiid);
      result = (response['data']?['result'] ?? response['data'] ?? {}) as Map;
      providerMessage = (result['responseMessage'] ?? '').toString();
      usageKwh = _pickNum(result, const ['usage', 'odrusage', 'kwh']) ?? 0.0;
      readAt = result['readAt']?.toString();
    } on AppException catch (e) {
      // If SMT session is unavailable, keep dashboard functional using cached DB read.
      if (e.code != 'SMT_SESSION_EXPIRED' && e.code != 'SMT_UNAUTHORIZED') rethrow;
      providerMessage = e.message;
    }

    // On app restart, SMT can momentarily return empty/zero ODR data even though
    // we already have a recent meter read in DB. Fall back to DB-backed latest read
    // to avoid showing 0 to the user.
    final fallback = await _getLatestStoredMeterRead();
    if (fallback != null) {
      final fallbackKwh = fallback.$1;
      final fallbackReadAt = fallback.$2;
      // Prefer the latest stored meter-read snapshot when it is ahead of
      // current live payload so ODR updates appear immediately.
      if (usageKwh <= 0 || fallbackKwh > usageKwh) {
        usageKwh = fallbackKwh;
        readAt = fallbackReadAt ?? readAt;
      } else if ((readAt == null || readAt.isEmpty) && fallbackReadAt != null) {
        readAt = fallbackReadAt;
      }
    }

    final appliedRate = ratePerKwh > 0 ? ratePerKwh : _defaultRatePerKwh;
    // Use user-configured rate for all spend math so edits on Account
    // immediately reflect across the Energy screen.
    final currentSpend = usageKwh * appliedRate;
    final remainingAmount =
        (dailyBudget - currentSpend).clamp(0.0, dailyBudget).toDouble();
    final centsPerKwh = usageKwh > 0
        ? (currentSpend / usageKwh) * 100
        : (appliedRate * 100);
    final hasOdrData = usageKwh > 0 || (readAt != null && readAt.isNotEmpty);

    // Fetch real trend data from the DB-backed endpoint
    final trends = await _fetchEnergyTrends();

    return EnergySummary(
      currentSpend: currentSpend,
      totalBudget: dailyBudget > 0 ? dailyBudget : _defaultDailyBudget,
      usedPercentage: (dailyBudget <= 0)
          ? 0
          : (currentSpend / (dailyBudget > 0 ? dailyBudget : _defaultDailyBudget)),
      percentVsYesterday: trends.percentVsYesterday,
      remainingAmount: remainingAmount,
      airConditionerCost: currentSpend * 0.45,
      kwhToday: usageKwh,
      kwhTrend: trends.kwhTrend,
      centsPerKwh: centsPerKwh,
      centsTrend: trends.costTrend,
      hasOdrData: hasOdrData,
      providerMessage: providerMessage.isEmpty ? null : providerMessage,
      readAt: readAt,
    );
  }

  /// Fetches trend calculations from the backend.
  /// Returns neutral (0) trends on any error to avoid blocking the UI.
  Future<_TrendData> _fetchEnergyTrends() async {
    try {
      final response = await _apiClient.getEnergyTrends();
      final data = response['data'] as Map<String, dynamic>? ?? {};
      return _TrendData(
        kwhTrend: _toDouble(data['kwhTrend']) ?? 0.0,
        costTrend: _toDouble(data['costTrend']) ?? 0.0,
        percentVsYesterday: _toDouble(data['percentVsYesterday']) ?? 0.0,
      );
    } catch (_) {
      // Best-effort; don't block the summary if trends fail
      return const _TrendData(kwhTrend: 0, costTrend: 0, percentVsYesterday: 0);
    }
  }

  Future<(double, String?)?> _getLatestStoredMeterRead() async {
    try {
      final response = await _apiClient.getUserMeterReads(limit: 1);
      final reads = response['data']?['reads'];
      if (reads is! List || reads.isEmpty) return null;
      final latest = reads.first;
      if (latest is! Map) return null;

      final kwh = _pickNum(latest, const ['reading_kwh', 'readingKwh', 'usage', 'kwh']);
      if (kwh == null || kwh <= 0) return null;
      final readAt = (latest['read_at'] ?? latest['readAt'])?.toString();
      return (kwh, readAt);
    } catch (_) {
      // DB fallback is best-effort; ignore failures and keep SMT response.
      return null;
    }
  }

  @override
  Future<MeterReadRequestResult> requestCurrentMeterRead({String? meterNumber}) async {
    final sessionId = _sessionStore.sessionId;
    final esiid = _sessionStore.esiid;
    final resolvedMeterNumber = (meterNumber?.trim().isNotEmpty ?? false)
        ? meterNumber!.trim()
        : _sessionStore.meterNumber;

    if (sessionId == null || sessionId.isEmpty) {
      throw Exception('Session expired. Please log in again.');
    }
    if (esiid == null || esiid.isEmpty) {
      throw Exception('ESIID is missing. Please re-login and provide a valid ESIID.');
    }
    if (resolvedMeterNumber == null || resolvedMeterNumber.isEmpty) {
      throw Exception('Meter number is required to request a current meter read.');
    }
    await _sessionStore.saveMeterNumber(resolvedMeterNumber);

    final response = await _apiClient.requestCurrentMeterRead(
      esiid: esiid,
      meterNumber: resolvedMeterNumber,
    );
    final result = response['data']?['result'];
    final rateLimit = response['meta']?['rateLimit'];
    DateTime? lockedUntil;
    final hourRemaining = rateLimit?['perHour']?['remaining'];
    final dayRemaining = rateLimit?['perDay']?['remaining'];
    if (hourRemaining is num && hourRemaining <= 0) {
      lockedUntil = DateTime.now().add(const Duration(hours: 1));
    } else if (dayRemaining is num && dayRemaining <= 0) {
      lockedUntil = DateTime.now().add(const Duration(hours: 24));
    }
    final message =
        (result?['message'] ??
                result?['responseMessage'] ??
                result?['statusReason'] ??
                'Meter read request submitted for further processing.')
            .toString();
    return MeterReadRequestResult(
      message: message,
      lockedUntil: lockedUntil,
    );
  }

  double? _pickNum(Map data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];
      final parsed = _toDouble(value);
      if (parsed != null) return parsed;
    }
    return null;
  }

  double? _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) {
      final cleaned = value.replaceAll(RegExp(r'[^0-9.\-]'), '');
      return double.tryParse(cleaned);
    }
    return null;
  }
}

/// Lightweight container for trend percentages fetched from the backend.
class _TrendData {
  final double kwhTrend;
  final double costTrend;
  final double percentVsYesterday;

  const _TrendData({
    required this.kwhTrend,
    required this.costTrend,
    required this.percentVsYesterday,
  });
}
