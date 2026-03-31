import '../../../../core/network/smt_api_client.dart';
import '../../../../core/session/smt_session_store.dart';

class SessionInfo {
  const SessionInfo({
    required this.sessionId,
    this.defaultEsiid,
    this.jwtToken,
    this.userId,
    this.meterNumber,
  });

  final String sessionId;
  final String? defaultEsiid;
  final String? jwtToken;
  final int? userId;
  final String? meterNumber;
}

class SmtAuthRepository {
  SmtAuthRepository({SmtApiClient? apiClient, SmtSessionStore? sessionStore})
    : _apiClient = apiClient ?? SmtApiClient(),
      _sessionStore = sessionStore ?? SmtSessionStore.instance;

  final SmtApiClient _apiClient;
  final SmtSessionStore _sessionStore;

  Future<SessionInfo> login({
    required String username,
    required String password,
    String? esiid,
  }) async {
    // Use the new auth endpoint that verifies SMT creds AND creates DB user
    final response = await _apiClient.authLogin(
      username: username,
      password: password,
      esiid: esiid,
    );

    final data = response['data'] as Map<String, dynamic>? ?? {};
    final token = (data['token'] ?? '').toString();
    final smtSessionId = (data['smtSessionId'] ?? '').toString();
    final userId = data['userId'] is int ? data['userId'] as int : null;
    final role = data['role']?.toString().trim().toLowerCase();
    final meterNumber = data['meterNumber']?.toString();

    if (token.isEmpty) {
      throw Exception('Login succeeded but no token was returned by backend.');
    }

    final backendEsiid = _extractFirstString(response, [
      'defaultEsiid',
      'esiid',
      'ESIID',
    ]);
    final resolvedEsiid = backendEsiid ?? esiid?.trim() ?? _sessionStore.esiid;

    await _sessionStore.saveSession(
      sessionId: smtSessionId.isNotEmpty ? smtSessionId : token,
      esiid: resolvedEsiid,
      meterNumber: (meterNumber?.isNotEmpty ?? false) ? meterNumber : null,
      jwtToken: token,
      userId: userId,
      userRole: (role?.isNotEmpty ?? false) ? role : _sessionStore.userRole,
      smtUsername: username,
    );

    return SessionInfo(
      sessionId: smtSessionId.isNotEmpty ? smtSessionId : token,
      defaultEsiid: resolvedEsiid,
      jwtToken: token,
      userId: userId,
      meterNumber: (meterNumber?.isNotEmpty ?? false) ? meterNumber : null,
    );
  }

  Future<SessionInfo?> checkSession() async {
    final jwtToken = _sessionStore.jwtToken;
    if (jwtToken == null || jwtToken.isEmpty) {
      // No JWT means user is not authenticated for app-level routes.
      await _sessionStore.clear();
      return null;
    }

    try {
      final response = await _apiClient.getMe();
      final data = response['data'] as Map<String, dynamic>? ?? {};
      final esiid = (data['esiid'] ?? _sessionStore.esiid)?.toString();
      final userId = data['userId'] is int
          ? data['userId'] as int
          : _sessionStore.userId;
      final role = data['role']?.toString().trim().toLowerCase();
      final meterNumber = data['meterNumber']?.toString();
      final smtUsername = data['smtUsername']?.toString();

      // Admin users can be backend-role accounts without SMT session.
      final isAdmin = (role?.isNotEmpty ?? false)
          ? role == 'admin'
          : ((_sessionStore.userRole ?? '').toLowerCase() == 'admin');

      // For non-admin users, validate/recover SMT session before app routing.
      if (!isAdmin) {
        await _apiClient.getSessionStatus();
      }

      await _sessionStore.saveSession(
        sessionId: _sessionStore.sessionId ?? jwtToken,
        esiid: (esiid?.isNotEmpty ?? false) ? esiid : _sessionStore.esiid,
        meterNumber: (meterNumber?.isNotEmpty ?? false)
            ? meterNumber
            : _sessionStore.meterNumber,
        jwtToken: jwtToken,
        userId: userId,
        userRole: (role?.isNotEmpty ?? false) ? role : _sessionStore.userRole,
        smtUsername: (smtUsername?.isNotEmpty ?? false)
            ? smtUsername
            : _sessionStore.smtUsername,
      );

      return SessionInfo(
        sessionId: _sessionStore.sessionId ?? jwtToken,
        defaultEsiid: (esiid?.isNotEmpty ?? false)
            ? esiid
            : _sessionStore.esiid,
        jwtToken: jwtToken,
        userId: userId,
        meterNumber: (meterNumber?.isNotEmpty ?? false)
            ? meterNumber
            : _sessionStore.meterNumber,
      );
    } catch (_) {
      // JWT invalid/expired or user check failed: force login screen.
      await _sessionStore.clear();
      return null;
    }
  }

  Future<void> logout() async {
    try {
      await _apiClient.logout();
    } catch (_) {
      // Idempotent backend logout; we still clear local session.
    } finally {
      await _sessionStore.clear();
    }
  }

  Future<void> clearLocalSession() => _sessionStore.clear();

  String? _extractFirstString(dynamic node, List<String> keys) {
    if (node == null) return null;
    if (node is Map) {
      for (final key in keys) {
        final value = node[key];
        if (value is String && value.trim().isNotEmpty) return value.trim();
      }
      for (final entry in node.entries) {
        final found = _extractFirstString(entry.value, keys);
        if (found != null) return found;
      }
    }
    if (node is List) {
      for (final item in node) {
        final found = _extractFirstString(item, keys);
        if (found != null) return found;
      }
    }
    return null;
  }
}
