import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/alerts/alerts_unread_store.dart';
import '../../../../core/network/energy_realtime_client.dart';
import '../../../../core/network/smt_api_client.dart';
import '../../../../core/session/smt_session_store.dart';
import '../../../../core/settings/app_settings_store.dart';
import '../../../../core/theme/app_theme.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({
    super.key,
    this.refreshNonce,
    this.onUnreadChanged,
    this.apiClient,
  });

  final int? refreshNonce;
  final ValueChanged<bool>? onUnreadChanged;
  final SmtApiClient? apiClient;

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  late final SmtApiClient _apiClient;
  late final EnergyRealtimeClient _realtimeClient;
  late Future<List<_AlertItem>> _alertsFuture;
  Set<String> _currentActionableIds = <String>{};
  Timer? _pollTimer;
  Timer? _realtimeDebounce;
  StreamSubscription<EnergyRealtimeMessage>? _realtimeSub;
  bool _refreshing = false;

  // Staggered entrance animation
  late AnimationController _staggerController;
  late List<Animation<double>> _slideAnimations;
  late List<Animation<double>> _fadeAnimations;
  bool _hasAnimated = false;

  // Alert prefs
  late bool _costLimitOn;
  late bool _peakHourOn;
  late bool _weeklySummaryOn;

  @override
  void initState() {
    super.initState();
    _apiClient = widget.apiClient ?? SmtApiClient();
    _realtimeClient = WebSocketEnergyRealtimeClient();
    WidgetsBinding.instance.addObserver(this);

    // Load prefs
    final settings = AppSettingsStore.instance;
    _costLimitOn = settings.alertCostLimit;
    _peakHourOn = settings.alertPeakHour;
    _weeklySummaryOn = settings.alertWeeklySummary;

    // Stagger: 7 items max (title, 3 prefs, "Recent" header, alert1, alert2)
    _staggerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _buildAnimations(7);

    _alertsFuture = _loadAlerts();
    _startPolling();
    _startRealtime();
  }

  void _buildAnimations(int count) {
    _slideAnimations = List.generate(count, (i) {
      final start = (i * 0.10).clamp(0.0, 0.7);
      final end = (start + 0.45).clamp(0.0, 1.0);
      return Tween<double>(begin: 36, end: 0).animate(
        CurvedAnimation(
          parent: _staggerController,
          curve: Interval(start, end, curve: Curves.easeOutCubic),
        ),
      );
    });
    _fadeAnimations = List.generate(count, (i) {
      final start = (i * 0.10).clamp(0.0, 0.7);
      final end = (start + 0.35).clamp(0.0, 1.0);
      return Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(
          parent: _staggerController,
          curve: Interval(start, end, curve: Curves.easeOut),
        ),
      );
    });
  }

  void _triggerEntrance() {
    if (!_hasAnimated) {
      _hasAnimated = true;
      _staggerController.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _staggerController.dispose();
    _pollTimer?.cancel();
    _realtimeDebounce?.cancel();
    _realtimeSub?.cancel();
    _realtimeClient.disconnect();
    _realtimeClient.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refresh();
    }
  }

  @override
  void didUpdateWidget(covariant AlertsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldNonce = oldWidget.refreshNonce ?? 0;
    final newNonce = widget.refreshNonce ?? 0;
    if (oldNonce != newNonce) {
      _refresh();
    }
  }

  Future<void> _refresh() async {
    if (_refreshing) return;
    _refreshing = true;
    setState(() {
      _alertsFuture = _loadAlerts();
    });
    try {
      await _alertsFuture;
    } finally {
      _refreshing = false;
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (!mounted) return;
      _refresh();
    });
  }

  void _startRealtime() {
    final token = _resolveJwtToken();
    if (token == null || token.isEmpty) return;
    try {
      _realtimeSub = _realtimeClient.connect(jwtToken: token).listen((event) {
        if (event.type != 'alerts_changed' && event.type != 'energy_snapshot') {
          return;
        }
        if (!mounted) return;
        _realtimeDebounce?.cancel();
        _realtimeDebounce = Timer(const Duration(milliseconds: 600), _refresh);
      }, onError: (_) {});
    } catch (_) {}
  }

  String? _resolveJwtToken() {
    return SmtSessionStore.instance.jwtToken;
  }

  Future<List<_AlertItem>> _loadAlerts() async {
    await AppSettingsStore.instance.load();
    final alerts = <_AlertItem>[];
    final chunks = await Future.wait<List<_AlertItem>>([
      _buildUsageHistoryAlerts(),
      if (_costLimitOn) _buildBudgetAlerts(),
      _buildTrendAlerts(),
      _buildRateLimitAlerts(),
    ]);
    for (final chunk in chunks) {
      alerts.addAll(chunk);
    }

    final actionable = alerts.where((a) => a.isUnread).toList();
    final actionableIds = actionable.map((a) => a.id).toList();
    final digest = actionable.map((a) => '${a.title}|${a.timeAgo}').join('||');
    final store = AlertsUnreadStore.instance;
    final hasUnread = await store.syncSnapshot(
      digest: digest,
      actionableAlertIds: actionableIds,
    );
    final readIds = await store.getReadIds();
    _currentActionableIds = actionableIds.toSet();
    widget.onUnreadChanged?.call(hasUnread);

    return alerts
        .map((a) => a.copyWith(isUnread: a.isUnread && !readIds.contains(a.id)))
        .toList();
  }

  // ── Alert builders ─────────────────────────────────────────────────────────

  List<_UsagePoint> _parseDailyPoints(dynamic raw) {
    if (raw is! List) return const [];
    final points = <_UsagePoint>[];
    for (final entry in raw) {
      if (entry is! Map) continue;
      final dateRaw = entry['date']?.toString() ?? entry['day']?.toString();
      final usageRaw = entry['kwh'] ?? entry['usage'];
      if (dateRaw == null || usageRaw == null) continue;
      final date = DateTime.tryParse(dateRaw);
      final kwh = _toDouble(usageRaw);
      if (date == null || kwh == null) continue;
      points.add(_UsagePoint(date: date, kwh: kwh));
    }
    points.sort((a, b) => a.date.compareTo(b.date));
    return points;
  }

  String _relativeDateLabel(DateTime date) {
    final today = DateTime.now();
    final localDate = DateTime(date.year, date.month, date.day);
    final localToday = DateTime(today.year, today.month, today.day);
    final diff = localToday.difference(localDate).inDays;
    if (diff <= 0) return 'TODAY';
    if (diff == 1) return 'YESTERDAY';
    if (diff < 7) return '$diff DAYS AGO';
    return '${date.month}/${date.day}/${date.year}';
  }

  double? _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  double? _pickNum(Map data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];
      final parsed = _toDouble(value);
      if (parsed != null) return parsed;
    }
    return null;
  }

  Future<List<_AlertItem>> _buildUsageHistoryAlerts() async {
    try {
      final historyResponse = await _apiClient.getUserUsageHistory(days: 14);
      final historyData =
          historyResponse['data'] as Map<String, dynamic>? ?? {};
      final pointsRaw = historyData['dailyPoints'];
      final points = _parseDailyPoints(pointsRaw);
      if (points.isEmpty) return const <_AlertItem>[];

      final latest = points.last;
      final recent = points.reversed.take(7).toList();
      final avgKwh = recent.isEmpty
          ? 0.0
          : recent.map((e) => e.kwh).reduce((a, b) => a + b) / recent.length;
      if (avgKwh <= 0 || latest.kwh < avgKwh * 1.25)
        return const <_AlertItem>[];

      final pct = (((latest.kwh - avgKwh) / avgKwh) * 100).round();
      // Use only the date for a stable ID — percentage may shift between refreshes.
      final dayKey =
          '${latest.date.year}_${latest.date.month}_${latest.date.day}';
      return <_AlertItem>[
        _AlertItem(
          id: _alertId('high_usage', dayKey),
          title: 'High usage detected at ${_formatTime(latest.date)}',
          subtitle:
              '${latest.kwh.toStringAsFixed(1)} kWh — $pct% above your 7-day average',
          details:
              'Your latest day usage is noticeably higher than your recent baseline. '
              'Consider checking heavy appliances and thermostat settings.',
          timeAgo: _relativeDateLabel(latest.date),
          icon: Icons.warning_amber_rounded,
          iconColor: const Color(0xFFD97706),
          iconBgColor: const Color(0xFFFEF3C7),
          isUnread: true,
        ),
      ];
    } catch (_) {
      return const <_AlertItem>[];
    }
  }

  Future<List<_AlertItem>> _buildBudgetAlerts() async {
    try {
      final usageResponse = await _apiClient.getUsage();
      final usageResult = usageResponse['data']?['result'];
      if (usageResult is! Map) return const <_AlertItem>[];

      final usageKwh =
          _pickNum(usageResult, const ['usage', 'odrusage', 'kwh']) ?? 0.0;
      final budget = AppSettingsStore.instance.dailyBudget;
      final rate = AppSettingsStore.instance.ratePerKwh;
      final spend = usageKwh * rate;
      final ratio = budget > 0 ? (spend / budget) : 0.0;

      // Use today's date only so the ID stays stable across refreshes.
      final todayKey =
          '${DateTime.now().year}_${DateTime.now().month}_${DateTime.now().day}';
      if (ratio >= 1.0) {
        return <_AlertItem>[
          _AlertItem(
            id: _alertId('budget_exceeded', todayKey),
            title:
                "Budget exceeded by \$${(spend - budget).toStringAsFixed(2)}",
            subtitle:
                'Spend: \$${spend.toStringAsFixed(2)} / Budget: \$${budget.toStringAsFixed(2)}',
            details:
                'Estimated spend is \$${spend.toStringAsFixed(2)} versus a daily budget of '
                '\$${budget.toStringAsFixed(2)}. Review current consumption or raise budget if needed.',
            timeAgo: 'TODAY',
            icon: Icons.error_outline_rounded,
            iconColor: const Color(0xFFB91C1C),
            iconBgColor: const Color(0xFFFEE2E2),
            isUnread: true,
          ),
        ];
      }
      if (ratio >= 0.85) {
        final pct = (ratio * 100).round();
        return <_AlertItem>[
          _AlertItem(
            id: _alertId('budget_warning', todayKey),
            title: 'Approaching daily budget ($pct% used)',
            subtitle:
                '\$${spend.toStringAsFixed(2)} of \$${budget.toStringAsFixed(2)} used',
            details:
                'You are approaching your daily budget cap. Small usage reductions now can '
                'help avoid going over budget by end of day.',
            timeAgo: 'TODAY',
            icon: Icons.account_balance_wallet_rounded,
            iconColor: const Color(0xFFD97706),
            iconBgColor: const Color(0xFFFEF3C7),
            isUnread: true,
          ),
        ];
      }
      return const <_AlertItem>[];
    } catch (_) {
      return const <_AlertItem>[];
    }
  }

  Future<List<_AlertItem>> _buildTrendAlerts() async {
    try {
      final trendResponse = await _apiClient.getEnergyTrends();
      final trendData = trendResponse['data'] as Map<String, dynamic>? ?? {};
      final pctVsYesterday = _toDouble(trendData['percentVsYesterday']) ?? 0.0;
      final costTrend = _toDouble(trendData['costTrend']) ?? 0.0;
      final alerts = <_AlertItem>[];

      final trendDayKey =
          '${DateTime.now().year}_${DateTime.now().month}_${DateTime.now().day}';
      if (pctVsYesterday >= 0.10) {
        final pct = (pctVsYesterday * 100).round();
        alerts.add(
          _AlertItem(
            id: _alertId('spend_vs_yesterday', trendDayKey),
            title: 'Spend up $pct% vs yesterday',
            subtitle: "Today's estimated spend is higher than yesterday",
            details:
                'Compared with yesterday, your projected spend has increased. '
                'Check peak-time usage or high-draw appliances.',
            timeAgo: 'TODAY',
            icon: Icons.trending_up_rounded,
            iconColor: const Color(0xFFD97706),
            iconBgColor: const Color(0xFFFEF3C7),
            isUnread: true,
          ),
        );
      }
      if (costTrend >= 0.10) {
        final pct = (costTrend * 100).round();
        alerts.add(
          _AlertItem(
            id: _alertId('cost_weekly_trend', trendDayKey),
            title: 'Weekly usage up $pct%',
            subtitle: 'Average daily usage this week is rising',
            details:
                'Your weekly trend is rising. Monitoring recurring loads may help bring this down.',
            timeAgo: 'THIS WEEK',
            icon: Icons.insights_rounded,
            iconColor: AppColors.primaryBlue,
            iconBgColor: const Color(0xFFD8EAFE),
          ),
        );
      }
      return alerts;
    } catch (_) {
      return const <_AlertItem>[];
    }
  }

  Future<List<_AlertItem>> _buildRateLimitAlerts() async {
    try {
      final lockResponse = await _apiClient.getOdrRateLimit();
      final data = lockResponse['data'] as Map<String, dynamic>? ?? {};
      final perHour =
          data['perHour'] as Map<String, dynamic>? ?? const <String, dynamic>{};
      final perDay =
          data['perDay'] as Map<String, dynamic>? ?? const <String, dynamic>{};
      final hourRemaining = (perHour['remaining'] as num?)?.toInt() ?? 0;
      final dayRemaining = (perDay['remaining'] as num?)?.toInt() ?? 0;
      final lockedUntilRaw = data['lockedUntil'];
      final lockedUntil = lockedUntilRaw is String
          ? DateTime.tryParse(lockedUntilRaw)?.toLocal()
          : null;
      if (lockedUntil == null || !DateTime.now().isBefore(lockedUntil)) {
        return const <_AlertItem>[];
      }
      final remaining = lockedUntil.difference(DateTime.now());
      final mins = remaining.inMinutes.clamp(1, 24 * 60);
      final waitText = mins >= 60 ? '~${(mins / 60).ceil()}h' : '~${mins}m';
      // Use lock type (hour/day) for stable IDs across refreshes while locked.
      final lockKey = hourRemaining <= 0
          ? 'hourly'
          : (dayRemaining <= 0 ? 'daily' : 'active');
      return <_AlertItem>[
        _AlertItem(
          id: _alertId('rate_limit', lockKey),
          title: 'Meter read rate-limited',
          subtitle: 'You can request again in $waitText',
          details:
              'Smart Meter Texas currently limits on-demand read frequency. '
              'Please wait until the cooldown period ends before trying again.',
          timeAgo: 'NOW',
          icon: Icons.schedule_rounded,
          iconColor: AppColors.primaryBlue,
          iconBgColor: const Color(0xFFD8EAFE),
        ),
      ];
    } catch (_) {
      return const <_AlertItem>[];
    }
  }

  String _formatTime(DateTime d) {
    final h = d.hour;
    final m = d.minute.toString().padLeft(2, '0');
    if (h == 0) return '12:$m AM';
    if (h < 12) return '$h:$m AM';
    if (h == 12) return '12:$m PM';
    return '${h - 12}:$m PM';
  }

  String _alertId(String type, String suffix) {
    final normalized = '${type}_$suffix'
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9_]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    return normalized;
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primaryBlue,
          onRefresh: _refresh,
          child: FutureBuilder<List<_AlertItem>>(
            future: _alertsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return const _AlertsLoadingSkeleton();
              }

              final alerts = snapshot.data ?? const <_AlertItem>[];
              // Cache resolved list for instant read-state updates on tap.
              _resolvedAlerts = alerts;

              WidgetsBinding.instance.addPostFrameCallback((_) {
                _triggerEntrance();
              });

              return AnimatedBuilder(
                animation: _staggerController,
                builder: (context, _) {
                  return SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Title ──
                        _animatedItem(
                          index: 0,
                          child: const Text(
                            'Alerts',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              color: AppColors.textMain,
                              letterSpacing: -1.2,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // ── Preference toggles ──
                        _animatedItem(
                          index: 1,
                          child: _AlertPrefCard(
                            icon: Icons.attach_money_rounded,
                            iconColor: AppColors.primaryBlue,
                            iconBgColor: const Color(0xFFDBEAFE),
                            title: 'Daily cost limit',
                            subtitle: 'Alert when over limit',
                            value: _costLimitOn,
                            onChanged: (v) {
                              setState(() => _costLimitOn = v);
                              AppSettingsStore.instance.setAlertCostLimit(v);
                              _refresh();
                            },
                          ),
                        ),
                        const SizedBox(height: 12),

                        _animatedItem(
                          index: 2,
                          child: _AlertPrefCard(
                            icon: Icons.access_time_rounded,
                            iconColor: const Color(0xFFF97316),
                            iconBgColor: const Color(0xFFFEF3C7),
                            title: 'Peak hour alert',
                            subtitle: 'Notify before peak times',
                            value: _peakHourOn,
                            onChanged: (v) {
                              setState(() => _peakHourOn = v);
                              AppSettingsStore.instance.setAlertPeakHour(v);
                            },
                          ),
                        ),
                        const SizedBox(height: 12),

                        _animatedItem(
                          index: 3,
                          child: _AlertPrefCard(
                            icon: Icons.calendar_today_rounded,
                            iconColor: const Color(0xFF8B5CF6),
                            iconBgColor: const Color(0xFFEDE9FE),
                            title: 'Weekly summary',
                            subtitle: 'Email report',
                            value: _weeklySummaryOn,
                            onChanged: (v) {
                              setState(() => _weeklySummaryOn = v);
                              AppSettingsStore.instance.setAlertWeeklySummary(
                                v,
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 32),

                        // ── Recent Alerts header ──
                        _animatedItem(
                          index: 4,
                          child: const Text(
                            'Recent Alerts',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: AppColors.textMain,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // ── Alert list ──
                        if (alerts.isEmpty)
                          _animatedItem(
                            index: 5,
                            child: const _AlertsEmptyState(),
                          )
                        else
                          ...alerts.asMap().entries.map((entry) {
                            final animIdx = (5 + entry.key).clamp(
                              0,
                              _slideAnimations.length - 1,
                            );
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: _animatedItem(
                                index: animIdx,
                                child: _buildAlertCard(entry.value),
                              ),
                            );
                          }),

                        const SizedBox(height: 100),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _animatedItem({required int index, required Widget child}) {
    final safeIdx = index.clamp(0, _slideAnimations.length - 1);
    return Transform.translate(
      offset: Offset(0, _slideAnimations[safeIdx].value),
      child: Opacity(opacity: _fadeAnimations[safeIdx].value, child: child),
    );
  }

  Widget _buildAlertCard(_AlertItem alert) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _onAlertTap(alert),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: alert.iconBgColor,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(alert.icon, color: alert.iconColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    alert.title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textMain,
                      height: 1.3,
                    ),
                  ),
                  if (alert.subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      alert.subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted.withValues(alpha: 0.8),
                        height: 1.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 6),
                  Text(
                    alert.timeAgo,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.primaryBlue.withValues(alpha: 0.7),
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
            if (alert.isUnread) ...[
              const SizedBox(width: 10),
              Container(
                margin: const EdgeInsets.only(top: 6),
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.redAccent,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Keep a local copy of resolved alerts so we can update read-state instantly.
  List<_AlertItem>? _resolvedAlerts;

  Future<void> _onAlertTap(_AlertItem alert) async {
    final hasUnread = await AlertsUnreadStore.instance.markRead(
      alertId: alert.id,
      actionableAlertIds: _currentActionableIds.toList(),
    );
    widget.onUnreadChanged?.call(hasUnread);
    if (!mounted) return;
    // Immediately reflect read-state locally (no network round-trip needed).
    if (_resolvedAlerts != null) {
      _resolvedAlerts = _resolvedAlerts!
          .map((a) => a.id == alert.id ? a.copyWith(isUnread: false) : a)
          .toList();
      setState(() {
        _alertsFuture = Future.value(_resolvedAlerts);
      });
    }

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.cardBackground,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.textMuted.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: alert.iconBgColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(alert.icon, color: alert.iconColor, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            alert.title,
                            style: const TextStyle(
                              color: AppColors.textMain,
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              height: 1.3,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            alert.timeAgo,
                            style: TextStyle(
                              color: AppColors.primaryBlue.withValues(
                                alpha: 0.7,
                              ),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  alert.details,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─── Alert Preference Toggle Card ────────────────────────────────────────────

class _AlertPrefCard extends StatelessWidget {
  const _AlertPrefCard({
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: iconBgColor,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textMain,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeThumbColor: Colors.white,
            activeTrackColor: AppColors.primaryBlue,
          ),
        ],
      ),
    );
  }
}

// ─── Loading Skeleton ────────────────────────────────────────────────────────

class _AlertsLoadingSkeleton extends StatefulWidget {
  const _AlertsLoadingSkeleton();

  @override
  State<_AlertsLoadingSkeleton> createState() => _AlertsLoadingSkeletonState();
}

class _AlertsLoadingSkeletonState extends State<_AlertsLoadingSkeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (context, _) {
        return ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          children: [
            _shimmerBlock(height: 38, width: 120),
            const SizedBox(height: 24),
            _shimmerBlock(height: 72),
            const SizedBox(height: 12),
            _shimmerBlock(height: 72),
            const SizedBox(height: 12),
            _shimmerBlock(height: 72),
            const SizedBox(height: 32),
            _shimmerBlock(height: 28, width: 160),
            const SizedBox(height: 16),
            _shimmerBlock(height: 88),
          ],
        );
      },
    );
  }

  Widget _shimmerBlock({required double height, double? width}) {
    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: const [
            Color(0xFFE5E7EB),
            Color(0xFFF3F4F6),
            Color(0xFFE5E7EB),
          ],
          stops: [
            (_shimmerController.value - 0.3).clamp(0.0, 1.0),
            _shimmerController.value.clamp(0.0, 1.0),
            (_shimmerController.value + 0.3).clamp(0.0, 1.0),
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
    );
  }
}

// ─── Empty state ─────────────────────────────────────────────────────────────

class _AlertsEmptyState extends StatelessWidget {
  const _AlertsEmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.primaryGreen.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              Icons.check_circle_outline_rounded,
              size: 28,
              color: AppColors.primaryGreen.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'All clear!',
            style: TextStyle(
              color: AppColors.textMain,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'No alerts right now. Pull down to refresh.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textMuted.withValues(alpha: 0.8),
              fontSize: 13,
              fontWeight: FontWeight.w500,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Models ──────────────────────────────────────────────────────────────────

class _UsagePoint {
  const _UsagePoint({required this.date, required this.kwh});
  final DateTime date;
  final double kwh;
}

class _AlertItem {
  const _AlertItem({
    required this.id,
    required this.title,
    this.subtitle = '',
    required this.details,
    required this.timeAgo,
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
    this.isUnread = false,
  });

  final String id;
  final String title;
  final String subtitle;
  final String details;
  final String timeAgo;
  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;
  final bool isUnread;

  _AlertItem copyWith({
    String? id,
    String? title,
    String? subtitle,
    String? details,
    String? timeAgo,
    IconData? icon,
    Color? iconColor,
    Color? iconBgColor,
    bool? isUnread,
  }) {
    return _AlertItem(
      id: id ?? this.id,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      details: details ?? this.details,
      timeAgo: timeAgo ?? this.timeAgo,
      icon: icon ?? this.icon,
      iconColor: iconColor ?? this.iconColor,
      iconBgColor: iconBgColor ?? this.iconBgColor,
      isUnread: isUnread ?? this.isUnread,
    );
  }
}
