import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import '../session/smt_session_store.dart';

/// Persists unread-alert state per user scope (ESIID) so badge state survives
/// app restarts and relogin.
class AlertsUnreadStore {
  AlertsUnreadStore._();
  static final AlertsUnreadStore instance = AlertsUnreadStore._();

  static const _digestPrefix = 'alerts_digest_';
  static const _unreadPrefix = 'alerts_unread_';
  static const _readIdsPrefix = 'alerts_read_ids_';

  final StreamController<bool> _changes = StreamController<bool>.broadcast();

  Stream<bool> get changes => _changes.stream;

  String _scope() => SmtSessionStore.instance.esiid ?? 'global';
  String _digestKey(String scope) => '$_digestPrefix$scope';
  String _unreadKey(String scope) => '$_unreadPrefix$scope';
  String _readIdsKey(String scope) => '$_readIdsPrefix$scope';

  Future<bool> hasUnread() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_unreadKey(_scope())) ?? false;
  }

  Future<Set<String>> getReadIds() async {
    final prefs = await SharedPreferences.getInstance();
    final values = prefs.getStringList(_readIdsKey(_scope())) ?? const <String>[];
    return values.toSet();
  }

  /// Syncs stored unread/read state against the latest actionable alert set.
  /// Read IDs remain persistent across app restarts/relogin for stable alert IDs.
  Future<bool> syncSnapshot({
    required String digest,
    required List<String> actionableAlertIds,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final scope = _scope();
    final digestKey = _digestKey(scope);
    final unreadKey = _unreadKey(scope);
    final readIdsKey = _readIdsKey(scope);

    final previousUnread = prefs.getBool(unreadKey) ?? false;

    if (actionableAlertIds.isEmpty) {
      await prefs.setString(digestKey, '');
      await prefs.setStringList(readIdsKey, const <String>[]);
      await prefs.setBool(unreadKey, false);
      if (previousUnread) _changes.add(false);
      return false;
    }

    final readIds = (prefs.getStringList(readIdsKey) ?? const <String>[]).toSet();
    final actionableSet = actionableAlertIds.toSet();
    final prunedReadIds = readIds.where(actionableSet.contains).toSet();
    await prefs.setString(digestKey, digest);
    await prefs.setStringList(readIdsKey, prunedReadIds.toList());

    final unread = actionableAlertIds.any((id) => !prunedReadIds.contains(id));
    await prefs.setBool(unreadKey, unread);
    if (unread != previousUnread) _changes.add(unread);
    return unread;
  }

  /// Updates unread state based on the latest actionable alert digest.
  /// If digest changes, we mark unread=true. If there are no actionable alerts,
  /// unread is reset to false.
  Future<bool> updateFromDigest({
    required String digest,
    required bool hasActionableAlerts,
  }) async {
    // Backward-compatible wrapper.
    return syncSnapshot(
      digest: digest,
      actionableAlertIds: hasActionableAlerts ? <String>[digest] : const <String>[],
    );
  }

  Future<bool> markRead({
    required String alertId,
    required List<String> actionableAlertIds,
  }) async {
    if (actionableAlertIds.isEmpty) {
      await markAllRead();
      return false;
    }

    final prefs = await SharedPreferences.getInstance();
    final scope = _scope();
    final unreadKey = _unreadKey(scope);
    final readIdsKey = _readIdsKey(scope);
    final previousUnread = prefs.getBool(unreadKey) ?? false;

    final readIds = (prefs.getStringList(readIdsKey) ?? const <String>[]).toSet();
    readIds.add(alertId);
    await prefs.setStringList(readIdsKey, readIds.toList());

    final unread = actionableAlertIds.any((id) => !readIds.contains(id));
    await prefs.setBool(unreadKey, unread);
    if (unread != previousUnread) _changes.add(unread);
    return unread;
  }

  Future<void> markAllRead() async {
    final prefs = await SharedPreferences.getInstance();
    final scope = _scope();
    final unreadKey = _unreadKey(scope);
    final readIdsKey = _readIdsKey(scope);
    await prefs.setBool(unreadKey, false);
    final existing = prefs.getStringList(readIdsKey) ?? const <String>[];
    if (existing.isNotEmpty) {
      await prefs.setStringList(readIdsKey, const <String>[]);
    }
    _changes.add(false);
  }
}

