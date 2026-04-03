import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../errors/app_exception.dart';
import '../session/smt_session_store.dart';
import 'api_envelope.dart';

class SmtApiClient {
  SmtApiClient({http.Client? httpClient, SmtSessionStore? sessionStore})
    : _httpClient = httpClient ?? http.Client(),
      _sessionStore = sessionStore ?? SmtSessionStore.instance;

  final http.Client _httpClient;
  final SmtSessionStore _sessionStore;
  static const Duration requestTimeout = Duration(seconds: 12);
  static const Duration _usageHistoryCacheTtl = Duration(seconds: 45);
  static final Map<int, _UsageHistoryCacheEntry> _usageHistoryCache =
      <int, _UsageHistoryCacheEntry>{};
  static final Map<int, Future<Map<String, dynamic>>> _usageHistoryInFlight =
      <int, Future<Map<String, dynamic>>>{};

  Uri _uri(String path) => Uri.parse('${AppConfig.backendBaseUrl}$path');

  Map<String, String> _headers({
    bool withSession = false,
    bool withJwt = false,
  }) {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (AppConfig.backendApiKey.isNotEmpty) {
      headers['x-api-key'] = AppConfig.backendApiKey;
    }
    if (withSession && (_sessionStore.sessionId?.isNotEmpty ?? false)) {
      headers['x-smt-session-id'] = _sessionStore.sessionId!;
    }
    if (withJwt && (_sessionStore.jwtToken?.isNotEmpty ?? false)) {
      headers['Authorization'] = 'Bearer ${_sessionStore.jwtToken!}';
    }
    return headers;
  }

  Map<String, dynamic> _decode(http.Response response) {
    final body = response.body.isEmpty ? '{}' : response.body;
    final decodedRaw = jsonDecode(body);
    if (decodedRaw is! Map<String, dynamic>) {
      throw AppException(
        code: 'SMT_REQUEST_ERROR',
        message: 'Unexpected response format.',
        statusCode: response.statusCode,
      );
    }
    final envelope = ApiEnvelope<Map<String, dynamic>>.fromJson(
      decodedRaw,
      (raw) => raw is Map<String, dynamic> ? raw : <String, dynamic>{},
    );
    if (!envelope.success || response.statusCode >= 400) {
      throw AppException(
        code: envelope.error?.code.isNotEmpty == true
            ? envelope.error!.code
            : 'SMT_REQUEST_ERROR',
        message: envelope.error?.message ?? 'Request failed',
        statusCode: response.statusCode,
        details: envelope.error?.details,
      );
    }
    return decodedRaw;
  }

  /// Maximum retries when a 429 (Too Many Requests) response is received.
  static const int _maxRetries = 2;

  Future<Map<String, dynamic>> _post(
    String path, {
    required Map<String, dynamic> payload,
    bool withSession = false,
    bool withJwt = false,
  }) async {
    for (int attempt = 0; attempt <= _maxRetries; attempt++) {
      final response = await _httpClient
          .post(
            _uri(path),
            headers: _headers(withSession: withSession, withJwt: withJwt),
            body: jsonEncode(payload),
          )
          .timeout(requestTimeout);
      if (response.statusCode == 429 && attempt < _maxRetries) {
        await _backoff(response, attempt);
        continue;
      }
      _handleNewSessionHeader(response);
      return _decode(response);
    }
    // Unreachable, but satisfies the type checker.
    throw AppException(
      code: 'SMT_RATE_LIMIT',
      message: 'Too many requests. Please try again shortly.',
    );
  }

  Future<Map<String, dynamic>> _get(
    String path, {
    bool withSession = false,
    bool withJwt = false,
    Duration? timeout,
  }) async {
    final effectiveTimeout = timeout ?? requestTimeout;
    for (int attempt = 0; attempt <= _maxRetries; attempt++) {
      final response = await _httpClient
          .get(
            _uri(path),
            headers: _headers(withSession: withSession, withJwt: withJwt),
          )
          .timeout(effectiveTimeout);
      if (response.statusCode == 429 && attempt < _maxRetries) {
        await _backoff(response, attempt);
        continue;
      }
      _handleNewSessionHeader(response);
      return _decode(response);
    }
    throw AppException(
      code: 'SMT_RATE_LIMIT',
      message: 'Too many requests. Please try again shortly.',
    );
  }

  /// Wait before retrying a 429 response. Respects `Retry-After` header if
  /// present, otherwise uses exponential back-off (1s, 2s).
  Future<void> _backoff(http.Response response, int attempt) async {
    final retryAfter = response.headers['retry-after'];
    final seconds = retryAfter != null
        ? int.tryParse(retryAfter) ?? (attempt + 1)
        : (attempt + 1);
    await Future<void>.delayed(Duration(seconds: seconds));
  }

  /// If the backend auto-re-logged in on our behalf it sends back the new
  /// session ID via a response header. Update the local store so subsequent
  /// requests use the fresh session.
  void _handleNewSessionHeader(http.Response response) {
    final newSessionId = response.headers['x-smt-new-session-id'];
    if (newSessionId != null && newSessionId.isNotEmpty) {
      _sessionStore.saveSession(
        sessionId: newSessionId,
        esiid: _sessionStore.esiid,
        jwtToken: _sessionStore.jwtToken,
        userId: _sessionStore.userId,
      );
    }
  }

  Future<Map<String, dynamic>> getSessionStatus() async {
    return _get('/api/smt/session', withSession: true, withJwt: true);
  }

  Future<Map<String, dynamic>> login({
    required String username,
    required String password,
    String? esiid,
  }) async {
    final payload = {
      'username': username,
      'password': password,
      if (esiid != null && esiid.isNotEmpty) 'ESIID': esiid,
      'rememberMe': 'true',
    };
    return _post('/api/smt/login', payload: payload);
  }

  Future<Map<String, dynamic>> logout() async {
    return _post(
      '/api/smt/logout',
      payload: const {},
      withSession: true,
      withJwt: true,
    );
  }

  Future<Map<String, dynamic>> getUsage({String? esiid}) async {
    final payload = <String, dynamic>{};
    final resolvedEsiid = esiid ?? _sessionStore.esiid;
    if (resolvedEsiid != null && resolvedEsiid.isNotEmpty) {
      payload['ESIID'] = resolvedEsiid;
    }

    return _post(
      '/api/smt/usage',
      payload: payload,
      withSession: true,
      withJwt: true,
    );
  }

  Future<Map<String, dynamic>> getUsageHistory({
    required String granularity,
    String? esiid,
    String? startDate,
    String? endDate,
  }) async {
    final payload = <String, dynamic>{
      'granularity': granularity,
      if (esiid != null && esiid.isNotEmpty) 'ESIID': esiid,
    };
    if (startDate != null) payload['startDate'] = startDate;
    if (endDate != null) payload['endDate'] = endDate;

    return _post(
      '/api/smt/usage/history',
      payload: payload,
      withSession: true,
      withJwt: true,
    );
  }

  Future<Map<String, dynamic>> requestCurrentMeterRead({
    required String esiid,
    required String meterNumber,
  }) {
    return _post(
      '/api/smt/meter-read/request',
      payload: {'ESIID': esiid, 'MeterNumber': meterNumber},
      withSession: true,
      withJwt: true,
    );
  }

  // ----- App auth (JWT-based, stores user in DB) -----

  Future<Map<String, dynamic>> authLogin({
    required String username,
    required String password,
    String? esiid,
  }) async {
    final payload = <String, dynamic>{
      'username': username,
      'password': password,
      if (esiid != null && esiid.isNotEmpty) 'ESIID': esiid,
    };
    final response = await _httpClient
        .post(
          _uri('/api/auth/login'),
          headers: _headers(),
          body: jsonEncode(payload),
        )
        .timeout(requestTimeout);
    _handleNewSessionHeader(response);
    return _decode(response);
  }

  Future<Map<String, dynamic>> getMe() async {
    final response = await _httpClient
        .get(_uri('/api/auth/me'), headers: _headers(withJwt: true))
        .timeout(requestTimeout);
    _handleNewSessionHeader(response);
    return _decode(response);
  }

  // ----- DB-backed endpoints (JWT-protected) -----

  Future<Map<String, dynamic>> getUserUsageHistory({int days = 30}) async {
    final cached = _usageHistoryCache[days];
    final now = DateTime.now();
    if (cached != null &&
        now.difference(cached.fetchedAt) < _usageHistoryCacheTtl) {
      return cached.payload;
    }

    final existing = _usageHistoryInFlight[days];
    if (existing != null) return existing;

    final future = () async {
      try {
        final payload = await _get(
          '/api/user/usage/history?days=$days',
          withJwt: true,
          timeout: const Duration(seconds: 20),
        );
        _usageHistoryCache[days] = _UsageHistoryCacheEntry(
          payload: payload,
          fetchedAt: DateTime.now(),
        );
        return payload;
      } catch (_) {
        // Graceful fallback for charts/cards when backend is rate-limited.
        if (cached != null) return cached.payload;
        rethrow;
      } finally {
        _usageHistoryInFlight.remove(days);
      }
    }();

    _usageHistoryInFlight[days] = future;
    return future;
  }

  Future<Map<String, dynamic>> getUserMeterReads({int limit = 20}) async {
    final response = await _httpClient
        .get(
          _uri('/api/user/meter-reads?limit=$limit'),
          headers: _headers(withJwt: true),
        )
        .timeout(requestTimeout);
    _handleNewSessionHeader(response);
    return _decode(response);
  }

  Future<Map<String, dynamic>> getOdrRateLimit() async {
    final response = await _httpClient
        .get(_uri('/api/user/odr-rate-limit'), headers: _headers(withJwt: true))
        .timeout(requestTimeout);
    _handleNewSessionHeader(response);
    return _decode(response);
  }

  Future<Map<String, dynamic>> getEnergyTrends() async {
    final response = await _httpClient
        .get(_uri('/api/user/energy-trends'), headers: _headers(withJwt: true))
        .timeout(requestTimeout);
    _handleNewSessionHeader(response);
    return _decode(response);
  }

  Future<Map<String, dynamic>> getEnergySnapshot() async {
    final response = await _httpClient
        .get(
          _uri('/api/user/energy/snapshot'),
          headers: _headers(withJwt: true),
        )
        .timeout(requestTimeout);
    _handleNewSessionHeader(response);
    return _decode(response);
  }

  Future<Map<String, dynamic>> updateEsiid(String esiid) async {
    return _put('/api/user/esiid', payload: {'esiid': esiid});
  }

  // ----- Providers -----

  Future<List<Map<String, dynamic>>> getProviders() async {
    // Cache-bust to ensure fresh seeded data appears immediately
    final ts = DateTime.now().millisecondsSinceEpoch;
    final resp = await _get('/api/providers?t=$ts');
    final data = resp['data'];
    if (data is List) {
      return data.cast<Map<String, dynamic>>();
    }
    return const <Map<String, dynamic>>[];
  }

  Future<Map<String, dynamic>?> getCheapestProvider({int usageKwh = 1000}) async {
    final resp = await _get('/api/providers/cheapest?usage=$usageKwh');
    return resp['data'] as Map<String, dynamic>?;
  }

  Future<Map<String, dynamic>> updateProviderName(String providerName) async {
    return _put('/api/user/provider', payload: {'providerName': providerName});
  }

  Future<Map<String, dynamic>> _put(
    String path, {
    required Map<String, dynamic> payload,
  }) async {
    for (int attempt = 0; attempt <= _maxRetries; attempt++) {
      final response = await _httpClient
          .put(
            _uri(path),
            headers: _headers(withJwt: true),
            body: jsonEncode(payload),
          )
          .timeout(requestTimeout);
      if (response.statusCode == 429 && attempt < _maxRetries) {
        await _backoff(response, attempt);
        continue;
      }
      _handleNewSessionHeader(response);
      return _decode(response);
    }
    throw AppException(
      code: 'SMT_RATE_LIMIT',
      message: 'Too many requests. Please try again shortly.',
    );
  }
}

class _UsageHistoryCacheEntry {
  const _UsageHistoryCacheEntry({
    required this.payload,
    required this.fetchedAt,
  });

  final Map<String, dynamic> payload;
  final DateTime fetchedAt;
}
