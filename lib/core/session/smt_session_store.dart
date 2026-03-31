import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';

class SmtSessionStore {
  SmtSessionStore._();

  static final SmtSessionStore instance = SmtSessionStore._();

  static const _sessionIdKey = 'smt_session_id';
  static const _esiidKey = 'smt_esiid';
  static const _meterNumberKey = 'smt_meter_number';
  static const _jwtTokenKey = 'smt_jwt_token';
  static const _userIdKey = 'smt_user_id';
  static const _userRoleKey = 'smt_user_role';
  static const _smtUsernameKey = 'smt_username';
  static const _meterReadLockedUntilKey = 'smt_meter_read_locked_until';

  String? _sessionId;
  String? _esiid;
  String? _meterNumber;
  String? _jwtToken;
  int? _userId;
  String? _userRole;
  String? _smtUsername;
  DateTime? _meterReadLockedUntil;

  String? get sessionId => _sessionId;
  String? get esiid => _esiid;
  String? get meterNumber => _meterNumber;
  String? get jwtToken => _jwtToken;
  int? get userId => _userId;
  String? get userRole => _userRole;
  String? get smtUsername => _smtUsername;
  DateTime? get meterReadLockedUntil => _meterReadLockedUntil;

  Future<void> load() async {
    final prefs = await _safeGetPrefs();
    if (prefs == null) return;
    _sessionId = prefs.getString(_sessionIdKey);
    _esiid = prefs.getString(_esiidKey);
    _meterNumber = prefs.getString(_meterNumberKey);
    _jwtToken = prefs.getString(_jwtTokenKey);
    _userId = prefs.getInt(_userIdKey);
    _userRole = prefs.getString(_userRoleKey);
    _smtUsername = prefs.getString(_smtUsernameKey);
    final lockRaw = prefs.getString(_meterReadLockedUntilKey);
    final parsedLock = lockRaw != null ? DateTime.tryParse(lockRaw) : null;
    if (parsedLock != null && DateTime.now().isBefore(parsedLock)) {
      _meterReadLockedUntil = parsedLock;
    } else {
      _meterReadLockedUntil = null;
      if (lockRaw != null) {
        await prefs.remove(_meterReadLockedUntilKey);
      }
    }
  }

  Future<void> saveSession({
    required String sessionId,
    String? esiid,
    String? meterNumber,
    String? jwtToken,
    int? userId,
    String? userRole,
    String? smtUsername,
  }) async {
    _sessionId = sessionId;
    final cleanedEsiid = esiid?.trim();
    if (cleanedEsiid != null && cleanedEsiid.isNotEmpty) {
      _esiid = cleanedEsiid;
    }
    _meterNumber = meterNumber ?? _meterNumber;
    _jwtToken = jwtToken ?? _jwtToken;
    _userId = userId ?? _userId;
    _userRole = userRole ?? _userRole;
    _smtUsername = smtUsername ?? _smtUsername;
    final prefs = await _safeGetPrefs();
    if (prefs == null) return;
    await prefs.setString(_sessionIdKey, sessionId);
    if (_esiid != null && _esiid!.isNotEmpty) {
      await prefs.setString(_esiidKey, _esiid!);
    }
    if (_meterNumber != null && _meterNumber!.isNotEmpty) {
      await prefs.setString(_meterNumberKey, _meterNumber!);
    }
    if (_jwtToken != null && _jwtToken!.isNotEmpty) {
      await prefs.setString(_jwtTokenKey, _jwtToken!);
    }
    if (_userId != null) {
      await prefs.setInt(_userIdKey, _userId!);
    }
    if (_userRole != null && _userRole!.isNotEmpty) {
      await prefs.setString(_userRoleKey, _userRole!);
    }
    if (_smtUsername != null && _smtUsername!.isNotEmpty) {
      await prefs.setString(_smtUsernameKey, _smtUsername!);
    }
  }

  Future<void> saveMeterNumber(String meterNumber) async {
    final cleaned = meterNumber.trim();
    if (cleaned.isEmpty) return;
    _meterNumber = cleaned;
    final prefs = await _safeGetPrefs();
    if (prefs == null) return;
    await prefs.setString(_meterNumberKey, cleaned);
  }

  Future<void> saveMeterReadLock(DateTime? lockedUntil) async {
    _meterReadLockedUntil = lockedUntil;
    final prefs = await _safeGetPrefs();
    if (prefs == null) return;

    if (lockedUntil == null || DateTime.now().isAfter(lockedUntil)) {
      await prefs.remove(_meterReadLockedUntilKey);
      _meterReadLockedUntil = null;
      return;
    }

    await prefs.setString(
      _meterReadLockedUntilKey,
      lockedUntil.toIso8601String(),
    );
  }

  Future<void> clearMeterReadLock() => saveMeterReadLock(null);

  Future<void> clear() async {
    _sessionId = null;
    _esiid = null;
    _meterNumber = null;
    _jwtToken = null;
    _userId = null;
    _userRole = null;
    _smtUsername = null;
    _meterReadLockedUntil = null;
    final prefs = await _safeGetPrefs();
    if (prefs == null) return;
    await prefs.remove(_sessionIdKey);
    await prefs.remove(_esiidKey);
    await prefs.remove(_meterNumberKey);
    await prefs.remove(_jwtTokenKey);
    await prefs.remove(_userIdKey);
    await prefs.remove(_userRoleKey);
    await prefs.remove(_smtUsernameKey);
    await prefs.remove(_meterReadLockedUntilKey);
  }

  Future<SharedPreferences?> _safeGetPrefs() async {
    try {
      return await SharedPreferences.getInstance();
    } on MissingPluginException {
      // Keep session in memory when plugin registration is unavailable.
      return null;
    }
  }
}
