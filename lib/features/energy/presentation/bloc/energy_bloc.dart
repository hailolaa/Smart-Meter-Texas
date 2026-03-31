import 'dart:async';
import 'dart:math' as math;
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/network/energy_realtime_client.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/network/smt_api_client.dart';
import '../../../../core/settings/app_settings_store.dart';
import '../../../../core/session/smt_session_store.dart';
import '../../domain/entities/energy_summary.dart';
import '../../domain/repositories/energy_repository.dart';
import 'energy_event.dart';
import 'energy_state.dart';

/// Internal event: fired by a timer when the rate-limit lock expires.
class _RateLimitExpired extends EnergyEvent {}
class _RealtimeSnapshotReceived extends EnergyEvent {
  _RealtimeSnapshotReceived(this.message);
  final EnergyRealtimeMessage message;
}

class EnergyBloc extends Bloc<EnergyEvent, EnergyState> {
  final EnergyRepository repository;
  final SmtSessionStore _sessionStore;
  final SmtApiClient _apiClient;
  final EnergyRealtimeClient _realtimeClient;
  static EnergySummary? _warmSummaryCache;
  EnergySummary? _lastLoadedSummary;
  DateTime? _meterReadLockedUntil;
  Timer? _lockExpiryTimer;
  StreamSubscription<EnergyRealtimeMessage>? _realtimeSubscription;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  int _lastRealtimeSequence = 0;

  EnergyBloc({
    required this.repository,
    SmtSessionStore? sessionStore,
    SmtApiClient? apiClient,
    EnergyRealtimeClient? realtimeClient,
  })  : _sessionStore = sessionStore ?? SmtSessionStore.instance,
        _apiClient = apiClient ?? SmtApiClient(),
        _realtimeClient = realtimeClient ?? WebSocketEnergyRealtimeClient(),
        super(EnergyInitial()) {
    _meterReadLockedUntil = _sessionStore.meterReadLockedUntil;
    _lastLoadedSummary = _warmSummaryCache;
    on<LoadEnergyData>(_onLoadEnergyData);
    on<RefreshEnergyData>(_onLoadEnergyData);
    on<RequestCurrentMeterRead>(_onRequestCurrentMeterRead);
    on<_RateLimitExpired>(_onRateLimitExpired);
    on<_RealtimeSnapshotReceived>(_onRealtimeSnapshotReceived);
    // If a lock was restored from prefs, schedule its auto-expiry.
    _scheduleLockExpiry();
    _connectRealtime();
  }

  @override
  Future<void> close() async {
    _lockExpiryTimer?.cancel();
    _reconnectTimer?.cancel();
    await _realtimeSubscription?.cancel();
    _realtimeClient.disconnect();
    await _realtimeClient.dispose();
    return super.close();
  }

  Future<void> _onLoadEnergyData(
    EnergyEvent event,
    Emitter<EnergyState> emit,
  ) async {
    final baseline = _lastLoadedSummary;
    if (baseline == null) {
      emit(EnergyLoading());
    } else {
      // Keep content visible during refresh/reload for smoother UX.
      // Apply current local budget so we never flash a stale budget value.
      final patched = _applyLocalBudget(baseline);
      emit(EnergyLoaded(patched, meterReadLockedUntil: _effectiveLock()));
    }
    // Don't block summary loading on rate-limit sync; run both in parallel.
    final syncFuture = _syncRateLimitFromBackend();
    await _loadAndEmit(emit);
    await syncFuture;
    final latest = _lastLoadedSummary;
    if (latest != null) {
      final patched = _applyLocalBudget(latest);
      _lastLoadedSummary = patched;
      emit(EnergyLoaded(patched, meterReadLockedUntil: _effectiveLock()));
    }
    _connectRealtime();
  }

  Future<void> _onRequestCurrentMeterRead(
    RequestCurrentMeterRead event,
    Emitter<EnergyState> emit,
  ) async {
    final baseline = _lastLoadedSummary;
    final activeLock = _effectiveLock();
    if (activeLock != null) {
      emit(
        EnergyActionSuccess(
          _buildRateLimitMessage(activeLock),
          summary: baseline,
          toastType: ToastType.warning,
        ),
      );
      if (baseline != null) {
        emit(EnergyLoaded(baseline, meterReadLockedUntil: activeLock));
      }
      return;
    }

    if (baseline == null) {
      emit(EnergyLoading());
    } else {
      emit(
        EnergyRequestInProgress(
          baseline,
          message: 'Reading your meter — this may take a moment...',
          meterReadLockedUntil: _effectiveLock(),
        ),
      );
    }

    try {
      final result = await repository.requestCurrentMeterRead(
        meterNumber: event.meterNumber,
      );
      if (result.lockedUntil != null) {
        _meterReadLockedUntil = result.lockedUntil;
        await _sessionStore.saveMeterReadLock(_meterReadLockedUntil);
        _scheduleLockExpiry();
      }

      // Poll usage a few times; SMT ODR updates are asynchronous.
      for (var attempt = 0; attempt < 6; attempt++) {
        await Future.delayed(const Duration(seconds: 5));
        final summary = await repository.getEnergySummary();
        if (_isNewReading(summary, baseline)) {
          emit(EnergyActionSuccess('Your latest meter read is ready!', summary: summary, toastType: ToastType.success));
          _emitBySummary(summary, emit);
          return;
        }
        if (baseline != null) {
          final elapsedSeconds = (attempt + 1) * 5;
          emit(
            EnergyRequestInProgress(
              baseline,
              message: 'Checking for updates... ${elapsedSeconds}s',
              meterReadLockedUntil: _effectiveLock(),
            ),
          );
        }
      }

      if (baseline != null) {
        emit(
          EnergyActionSuccess(
            'Your read is on its way! Pull down to refresh shortly.',
            summary: baseline,
            toastType: ToastType.info,
          ),
        );
        emit(EnergyLoaded(baseline, meterReadLockedUntil: _effectiveLock()));
        return;
      }

      await _loadAndEmit(emit);
    } on AppException catch (e) {
      if (e.code == 'SMT_RATE_LIMIT') {
        _meterReadLockedUntil = _lockFromRateLimitDetails(e.details);
        await _sessionStore.saveMeterReadLock(_meterReadLockedUntil);
        _scheduleLockExpiry();
        emit(
          EnergyActionSuccess(
            _buildRateLimitMessage(_meterReadLockedUntil),
            summary: baseline,
            toastType: ToastType.warning,
          ),
        );
        if (baseline != null) {
          emit(EnergyLoaded(baseline, meterReadLockedUntil: _effectiveLock()));
          return;
        }
        emit(
          EnergyLoaded(
            _fallbackSummary(),
            meterReadLockedUntil: _effectiveLock(),
          ),
        );
        return;
      }
      emit(
        EnergyActionSuccess(
          _friendlyError(e.message),
          summary: baseline ?? _lastLoadedSummary ?? _fallbackSummary(),
          isError: true,
          toastType: ToastType.error,
        ),
      );
      emit(
        EnergyLoaded(
          baseline ?? _lastLoadedSummary ?? _fallbackSummary(),
          meterReadLockedUntil: _effectiveLock(),
        ),
      );
    } catch (e) {
      final raw = e.toString().replaceFirst('Exception: ', '');
      emit(
        EnergyActionSuccess(
          _friendlyError(raw),
          summary: baseline ?? _lastLoadedSummary ?? _fallbackSummary(),
          isError: true,
          toastType: ToastType.error,
        ),
      );
      emit(
        EnergyLoaded(
          baseline ?? _lastLoadedSummary ?? _fallbackSummary(),
          meterReadLockedUntil: _effectiveLock(),
        ),
      );
    }
  }

  Future<void> _loadAndEmit(Emitter<EnergyState> emit) async {
    try {
      final summary = await repository.getEnergySummary();
      _emitBySummary(summary, emit);
    } catch (e) {
      final raw = e.toString().replaceFirst('Exception: ', '');
      emit(
        EnergyActionSuccess(
          _friendlyError(raw),
          summary: _lastLoadedSummary ?? _fallbackSummary(),
          isError: true,
          toastType: ToastType.error,
        ),
      );
      emit(
        EnergyLoaded(
          _lastLoadedSummary ?? _fallbackSummary(),
          meterReadLockedUntil: _effectiveLock(),
        ),
      );
    }
  }

  void _emitBySummary(EnergySummary summary, Emitter<EnergyState> emit) {
    // SMT can briefly return 0 usage right after an ODR poll/update window.
    // If we already have a non-zero reading, keep it unless a genuinely newer
    // read arrives.
    if (_shouldKeepPreviousSummary(summary)) {
      final patched = _applyLocalBudget(_lastLoadedSummary!);
      emit(EnergyLoaded(patched, meterReadLockedUntil: _effectiveLock()));
      return;
    }

    if (!summary.hasOdrData && _lastLoadedSummary != null) {
      final patched = _applyLocalBudget(_lastLoadedSummary!);
      emit(EnergyLoaded(patched, meterReadLockedUntil: _effectiveLock()));
      return;
    }
    final patched = _applyLocalBudget(summary);
    _lastLoadedSummary = patched;
    _warmSummaryCache = patched;
    emit(EnergyLoaded(patched, meterReadLockedUntil: _effectiveLock()));
  }

  /// Override totalBudget, rate, and derived fields with the user's local
  /// settings so that locally adjusted values take effect immediately without
  /// waiting for a backend round-trip.
  EnergySummary _applyLocalBudget(EnergySummary s) {
    final settings = AppSettingsStore.instance;
    final budget = settings.dailyBudget;
    final rate = settings.ratePerKwh;
    final rateCents = rate * 100;
    final spend = s.kwhToday * rate;
    final remaining = (budget - spend).clamp(0.0, budget);
    final usedPct = budget > 0 ? spend / budget : 0.0;
    return EnergySummary(
      currentSpend: double.parse(spend.toStringAsFixed(2)),
      totalBudget: budget,
      usedPercentage: usedPct,
      percentVsYesterday: s.percentVsYesterday,
      remainingAmount: double.parse(remaining.toStringAsFixed(2)),
      airConditionerCost: double.parse((spend * 0.45).toStringAsFixed(2)),
      kwhToday: s.kwhToday,
      kwhTrend: s.kwhTrend,
      centsPerKwh: rateCents,
      centsTrend: s.centsTrend,
      hasOdrData: s.hasOdrData,
      providerMessage: s.providerMessage,
      readAt: s.readAt,
    );
  }

  bool _shouldKeepPreviousSummary(EnergySummary incoming) {
    final previous = _lastLoadedSummary;
    if (previous == null) return false;

    // After a new ODR, SMT resets odrusage to 0 even though readAt advances.
    // Always keep the previous non-zero reading until a genuinely positive
    // incoming value arrives, regardless of whether the timestamp changed.
    if (incoming.kwhToday <= 0 && previous.kwhToday > 0) {
      return true;
    }

    return false;
  }

  bool _isNewReading(EnergySummary latest, EnergySummary? baseline) {
    if (!latest.hasOdrData) return false;
    // After a new ODR, SMT resets odrusage to 0 while the read processes.
    // Don't count a 0-kWh response as a valid "new reading".
    if (latest.kwhToday <= 0) return false;
    if (baseline == null) return true;
    return latest.readAt != baseline.readAt || latest.kwhToday != baseline.kwhToday;
  }

  /// Best-effort: fetch the authoritative rate-limit state from the backend
  /// so the local lock is accurate even after Flutter or backend restarts.
  Future<void> _syncRateLimitFromBackend() async {
    try {
      final response = await _apiClient.getOdrRateLimit();
      final data = response['data'];
      if (data == null) return;
      final lockedUntilRaw = data['lockedUntil'];
      if (lockedUntilRaw is String) {
        final backendLock = DateTime.tryParse(lockedUntilRaw)?.toLocal();
        if (backendLock != null && DateTime.now().isBefore(backendLock)) {
          // Backend says we're still rate-limited.
          _meterReadLockedUntil = backendLock;
          await _sessionStore.saveMeterReadLock(backendLock);
          _scheduleLockExpiry();
          return;
        }
      }
      // Backend says we're NOT rate-limited — clear any stale local lock.
      if (_meterReadLockedUntil != null) {
        _meterReadLockedUntil = null;
        await _sessionStore.clearMeterReadLock();
        _lockExpiryTimer?.cancel();
      }
    } catch (_) {
      // Best-effort; keep local prefs as fallback.
    }
  }

  Future<void> _onRateLimitExpired(
    _RateLimitExpired event,
    Emitter<EnergyState> emit,
  ) async {
    _meterReadLockedUntil = null;
    await _sessionStore.clearMeterReadLock();
    final summary = _lastLoadedSummary ?? _fallbackSummary();
    emit(EnergyLoaded(summary, meterReadLockedUntil: null));
  }

  void _connectRealtime() {
    final token = _sessionStore.jwtToken;
    if (token == null || token.isEmpty) return;
    if (_realtimeSubscription != null) return;
    try {
      _realtimeSubscription = _realtimeClient.connect(jwtToken: token).listen(
        (message) {
          _reconnectAttempts = 0;
          add(_RealtimeSnapshotReceived(message));
        },
        onError: (_) {
          _scheduleReconnect();
        },
        onDone: _scheduleReconnect,
        cancelOnError: false,
      );
    } catch (_) {
      // On web, a failed websocket handshake can throw synchronously.
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    _realtimeSubscription?.cancel();
    _realtimeSubscription = null;
    _realtimeClient.disconnect();
    if (_reconnectTimer?.isActive ?? false) return;
    final seconds = math.min(30, math.pow(2, _reconnectAttempts).toInt());
    _reconnectAttempts = (_reconnectAttempts + 1).clamp(1, 6);
    _reconnectTimer = Timer(Duration(seconds: seconds), _performRealtimeReconnect);
  }

  Future<void> _performRealtimeReconnect() async {
    if (isClosed) return;
    _connectRealtime();
    // Keep lock state in sync after reconnect attempts; content refresh will
    // come from incoming snapshots or manual pull-to-refresh.
    await _syncRateLimitFromBackend();
  }

  void _onRealtimeSnapshotReceived(
    _RealtimeSnapshotReceived event,
    Emitter<EnergyState> emit,
  ) {
    if (event.message.type != 'energy_snapshot') return;
    if (event.message.sequence <= _lastRealtimeSequence) return;
    _lastRealtimeSequence = event.message.sequence;
    final summary = _summaryFromRealtime(event.message.data);
    // Reuse existing guardrails so transient zero snapshots from SMT do not
    // overwrite a known good non-zero read.
    _emitBySummary(summary, emit);
  }

  /// Schedule a timer that fires exactly when the current rate-limit lock
  /// expires, automatically re-enabling the refresh button without user action.
  void _scheduleLockExpiry() {
    _lockExpiryTimer?.cancel();
    final lock = _meterReadLockedUntil;
    if (lock == null) return;
    final remaining = lock.difference(DateTime.now());
    if (remaining.isNegative || remaining == Duration.zero) {
      // Already expired — fire immediately.
      add(_RateLimitExpired());
      return;
    }
    _lockExpiryTimer = Timer(remaining, () => add(_RateLimitExpired()));
  }

  DateTime? _effectiveLock() {
    final lock = _meterReadLockedUntil;
    if (lock == null) return null;
    if (DateTime.now().isAfter(lock)) {
      _meterReadLockedUntil = null;
      _sessionStore.clearMeterReadLock();
      return null;
    }
    return lock;
  }

  DateTime? _lockFromRateLimitDetails(dynamic details) {
    if (details is! Map) return DateTime.now().add(const Duration(hours: 1));
    final retryAtRaw = details['retryAt'];
    if (retryAtRaw is String) {
      final retryAt = DateTime.tryParse(retryAtRaw);
      if (retryAt != null) return retryAt.toLocal();
    }
    final retryAfter = details['retryAfterSeconds'];
    if (retryAfter is num) {
      return DateTime.now().add(Duration(seconds: retryAfter.toInt()));
    }
    final window = details['window']?.toString().toLowerCase();
    if (window == 'day') return DateTime.now().add(const Duration(hours: 24));
    return DateTime.now().add(const Duration(hours: 1));
  }

  String _buildRateLimitMessage(DateTime? lockedUntil) {
    if (lockedUntil == null) {
      return 'You\'ve reached the read limit — please try again later.';
    }
    final diff = lockedUntil.difference(DateTime.now());
    final minutes = diff.inMinutes.clamp(1, 24 * 60);
    if (minutes >= 60) {
      final hours = (minutes / 60).ceil();
      return 'Read limit reached. You can try again in ~${hours}h.';
    }
    return 'Read limit reached. You can try again in ~${minutes}m.';
  }

  /// Converts raw technical error messages into something a regular user
  /// would understand.
  String _friendlyError(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('session expired') || lower.contains('session_expired')) {
      return 'Your session has expired. Please log in again.';
    }
    if (lower.contains('unauthorized') || lower.contains('401')) {
      return 'Authentication failed — please sign in again.';
    }
    if (lower.contains('timeout') || lower.contains('timed out')) {
      return 'The request timed out. Check your connection and try again.';
    }
    if (lower.contains('no internet') || lower.contains('socketexception') || lower.contains('network')) {
      return 'No internet connection. Please check your network.';
    }
    if (lower.contains('esiid') && lower.contains('missing')) {
      return 'Account info is missing. Please log in again.';
    }
    if (lower.contains('internal server')) {
      return 'Something went wrong on our end. Please try again.';
    }
    // If it's already reasonably short and clear, return as-is.
    if (raw.length <= 80) return raw;
    return 'Something went wrong. Pull down to retry.';
  }

  EnergySummary _fallbackSummary() {
    final settings = AppSettingsStore.instance;
    final budget = settings.dailyBudget;
    final centsPerKwh = settings.ratePerKwh * 100;
    return EnergySummary(
      currentSpend: 0,
      totalBudget: budget,
      usedPercentage: 0,
      percentVsYesterday: 0,
      remainingAmount: budget,
      airConditionerCost: 0,
      kwhToday: 0,
      kwhTrend: 0,
      centsPerKwh: centsPerKwh,
      centsTrend: 0,
      hasOdrData: false,
      providerMessage: 'Waiting for meter data...',
      readAt: null,
    );
  }

  EnergySummary _summaryFromRealtime(Map<String, dynamic> data) {
    final settings = AppSettingsStore.instance;
    final budget = settings.dailyBudget;
    final fallbackRateCents = settings.ratePerKwh * 100;
    return EnergySummary(
      currentSpend: _readDouble(data, 'currentSpend'),
      totalBudget: _readDouble(data, 'totalBudget', fallback: budget),
      usedPercentage: _readDouble(data, 'usedPercentage'),
      percentVsYesterday: _readDouble(data, 'percentVsYesterday'),
      remainingAmount: _readDouble(data, 'remainingAmount'),
      airConditionerCost: _readDouble(data, 'airConditionerCost'),
      kwhToday: _readDouble(data, 'kwhToday'),
      kwhTrend: _readDouble(data, 'kwhTrend'),
      centsPerKwh: _readDouble(data, 'centsPerKwh', fallback: fallbackRateCents),
      centsTrend: _readDouble(data, 'centsTrend'),
      hasOdrData: data['hasOdrData'] == true,
      providerMessage: data['providerMessage']?.toString(),
      readAt: data['readAt']?.toString(),
    );
  }

  double _readDouble(Map<String, dynamic> data, String key, {double fallback = 0}) {
    final value = data[key];
    if (value is num) return value.toDouble();
    if (value is String) {
      return double.tryParse(value) ?? fallback;
    }
    return fallback;
  }
}
