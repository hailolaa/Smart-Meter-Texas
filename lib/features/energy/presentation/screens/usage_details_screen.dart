import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/network/energy_realtime_client.dart';
import '../../../../core/settings/app_settings_store.dart';
import '../../../../core/network/smt_api_client.dart';
import '../../../../core/session/smt_session_store.dart';
import '../../../../core/theme/app_theme.dart';
import '../widgets/usage_trend_bar_chart.dart';

class UsageDetailsScreen extends StatefulWidget {
  const UsageDetailsScreen({
    super.key,
    this.refreshNonce,
    this.apiClient,
    this.realtimeClient,
  });

  final int? refreshNonce;
  final SmtApiClient? apiClient;
  final EnergyRealtimeClient? realtimeClient;

  @override
  State<UsageDetailsScreen> createState() => _UsageDetailsScreenState();
}

class _UsageDetailsScreenState extends State<UsageDetailsScreen> {
  double _ratePerKwh = AppSettingsStore.instance.ratePerKwh;
  late final SmtApiClient _apiClient;
  late final EnergyRealtimeClient _realtimeClient;
  late final bool _ownsRealtimeClient;
  final List<String> _periods = const ['Hourly', 'Daily', 'Monthly'];
  int _selectedPeriod = 1;
  late Future<_UsageDetailsData> _detailsFuture;
  _UsageDetailsData? _cachedData;
  bool? _showRefreshIndicator = false;
  StreamSubscription<void>? _settingsSubscription;
  StreamSubscription<EnergyRealtimeMessage>? _realtimeSubscription;
  Timer? _realtimeDebounce;
  bool _refreshing = false;

  // User-picked date for Hourly tab interval data (null = use latest).
  DateTime? _pickedHourlyDate;

  @override
  void initState() {
    super.initState();
    _apiClient = widget.apiClient ?? SmtApiClient();
    _ownsRealtimeClient = widget.realtimeClient == null;
    _realtimeClient = widget.realtimeClient ?? WebSocketEnergyRealtimeClient();
    _detailsFuture = _load();
    _settingsSubscription = AppSettingsStore.instance.changes.listen((_) {
      if (!mounted) return;
      setState(() {
        _ratePerKwh = AppSettingsStore.instance.ratePerKwh;
      });
    });
    _startRealtime();
  }

  @override
  void dispose() {
    _settingsSubscription?.cancel();
    _realtimeDebounce?.cancel();
    _realtimeSubscription?.cancel();
    _realtimeClient.disconnect();
    if (_ownsRealtimeClient) {
      _realtimeClient.dispose();
    }
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant UsageDetailsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldNonce = oldWidget.refreshNonce ?? 0;
    final newNonce = widget.refreshNonce ?? 0;
    if (oldNonce != newNonce) {
      _refresh();
    }
  }

  // ---------------------------------------------------------------------------
  // Data loading
  // ---------------------------------------------------------------------------

  Future<_UsageDetailsData> _load() async {
    await AppSettingsStore.instance.load();
    _ratePerKwh = AppSettingsStore.instance.ratePerKwh;
    final response = await _apiClient.getUserUsageHistory(days: 90);
    final data = response['data'] as Map<String, dynamic>? ?? {};
    final rawPoints = data['dailyPoints'];
    final latestDateRaw = data['latestDate']?.toString();
    final dbLatestDate = DateTime.tryParse(latestDateRaw ?? '') ?? DateTime.now();

    // Live ODR info — used to supplement the daily chart with today's reading.
    final meterRead = data['latestMeterRead'] as Map<String, dynamic>?;
    double? odrKwh;
    DateTime? odrDate;
    if (meterRead != null) {
      final readAtRaw = meterRead['readAt']?.toString();
      final readAt = DateTime.tryParse(readAtRaw ?? '');
      final kwh = _toDouble(meterRead['readingKwh']);
      if (readAt != null && kwh != null && kwh > 0) {
        odrDate = DateTime(readAt.year, readAt.month, readAt.day);
        odrKwh = kwh;
      }
    }

    // Fetch interval data for the selected date (user-picked or DB latest).
    // SMT interval data lags 1-2 days, so the live ODR day has no intervals.
    final intervalDate = _pickedHourlyDate ?? dbLatestDate;
    List? rawIntervalPoints;
    try {
      final intervalResponse = await _apiClient.getUsageHistory(
        granularity: '15m',
        startDate: _fmtSmtDate(intervalDate),
        endDate: _fmtSmtDate(intervalDate),
      );
      rawIntervalPoints =
          (intervalResponse['data']?['result']?['points'] ?? intervalResponse['data']?['points'])
              as List?;
    } catch (_) {
      rawIntervalPoints = null;
    }

    final points = <_DailyPoint>[];
    if (rawPoints is List) {
      for (final item in rawPoints) {
        if (item is! Map) continue;
        final dateRaw = item['date']?.toString();
        final kwhRaw = item['kwh'];
        final date = DateTime.tryParse(dateRaw ?? '');
        final kwh = _toDouble(kwhRaw);
        if (date != null && kwh != null) {
          points.add(_DailyPoint(date, kwh));
        }
      }
    }

    final intervalPoints = <_IntervalPoint>[];
    if (rawIntervalPoints != null) {
      for (final item in rawIntervalPoints) {
        if (item is! Map) continue;
        final tsRaw = item['timestamp']?.toString();
        final usageRaw = item['usage'];
        final ts = DateTime.tryParse(tsRaw ?? '');
        final usage = _toDouble(usageRaw);
        if (ts != null && usage != null) {
          intervalPoints.add(_IntervalPoint(ts, usage));
        }
      }
    }

    points.sort((a, b) => a.date.compareTo(b.date));
    intervalPoints.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return _UsageDetailsData(
      points: points,
      intervalPoints: intervalPoints,
      dbLatestDate: dbLatestDate,
      odrKwh: odrKwh,
      odrDate: odrDate,
    );
  }

  Future<void> _refresh() async {
    if (_refreshing) return;
    _refreshing = true;
    setState(() {
      _showRefreshIndicator = _cachedData != null;
      _detailsFuture = _load();
    });
    try {
      final updated = await _detailsFuture;
      if (!mounted) return;
      setState(() {
        _cachedData = updated;
        _showRefreshIndicator = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _showRefreshIndicator = false;
      });
    } finally {
      _refreshing = false;
    }
  }

  void _startRealtime() {
    final token = SmtSessionStore.instance.jwtToken;
    if (token == null || token.isEmpty) return;
    try {
      _realtimeSubscription = _realtimeClient.connect(jwtToken: token).listen(
        (event) {
          if (event.type != 'history_changed' && event.type != 'energy_snapshot') {
            return;
          }
          if (!mounted) return;
          _realtimeDebounce?.cancel();
          _realtimeDebounce = Timer(const Duration(milliseconds: 700), _refresh);
        },
        onError: (_) {},
      );
    } catch (_) {}
  }

  // ---------------------------------------------------------------------------
  // Chart data builders
  // ---------------------------------------------------------------------------

  _ChartData _buildChartData(_UsageDetailsData data) {
    final points = data.points;
    final intervalPoints = data.intervalPoints;

    if (_selectedPeriod != 0 && points.isEmpty) {
      return const _ChartData(labels: [], values: [], peakLabel: '--', highestCost: 0);
    }

    // --- Hourly (period 0) ---
    // Aggregate 15-min intervals into 24 full hourly buckets for the DB latest
    // date (the day that actually has interval data).
    if (_selectedPeriod == 0) {
      if (intervalPoints.isEmpty) {
        return const _ChartData(
          labels: [],
          values: [],
          peakLabel: 'Unavailable',
          highestCost: 0,
        );
      }

      final anchorDay = _pickedHourlyDate ?? data.dbLatestDate ?? DateTime.now();
      final day = DateTime(anchorDay.year, anchorDay.month, anchorDay.day);
      final hourly = <int, double>{};
      for (final pt in intervalPoints) {
        if (pt.timestamp.year != day.year ||
            pt.timestamp.month != day.month ||
            pt.timestamp.day != day.day) {
          continue;
        }
        hourly[pt.timestamp.hour] = (hourly[pt.timestamp.hour] ?? 0) + pt.kwh;
      }

      final dayPoints = List.generate(24, (i) {
        return MapEntry(day.add(Duration(hours: i)), hourly[i] ?? 0);
      });
      var peak = dayPoints.first;
      for (final entry in dayPoints) {
        if (entry.value > peak.value) peak = entry;
      }
      return _ChartData(
        labels: dayPoints.map((e) => _hourLabel(e.key)).toList(),
        values: dayPoints.map((e) => e.value).toList(),
        peakLabel: _hourClockLabel(peak.key),
        highestCost: peak.value * _ratePerKwh,
        dateSubtitle: _formatDateSubtitle(day),
      );
    }

    // --- Daily (period 1) ---
    // Show 7 days of daily data, injecting live ODR as today's bar if ahead.
    if (_selectedPeriod == 1) {
      final byDay = <DateTime, double>{};
      for (final p in points) {
        final day = DateTime(p.date.year, p.date.month, p.date.day);
        byDay[day] = (byDay[day] ?? 0) + p.kwh;
      }

      final dbEnd = points.isNotEmpty
          ? DateTime(points.last.date.year, points.last.date.month, points.last.date.day)
          : DateTime.now();
      DateTime chartEnd = dbEnd;

      // Inject live ODR for today if it's ahead of the DB.
      if (data.odrDate != null && data.odrKwh != null && data.odrKwh! > 0) {
        final odrDay = DateTime(data.odrDate!.year, data.odrDate!.month, data.odrDate!.day);
        if (odrDay.isAfter(dbEnd)) {
          byDay[odrDay] = data.odrKwh!;
          chartEnd = odrDay;
        } else if (odrDay.isAtSameMomentAs(dbEnd)) {
          byDay[odrDay] = (byDay[odrDay] ?? 0) > data.odrKwh! ? byDay[odrDay]! : data.odrKwh!;
        }
      }

      final sliced = List.generate(7, (i) {
        final day = chartEnd.subtract(Duration(days: 6 - i));
        return _DailyPoint(day, byDay[day] ?? 0);
      });
      final peak = sliced.reduce((a, b) => a.kwh >= b.kwh ? a : b);
      return _ChartData(
        labels: sliced.map((e) => _dayLabel(e.date)).toList(),
        values: sliced.map((e) => e.kwh).toList(),
        peakLabel: _dateLabel(peak.date),
        highestCost: peak.kwh * _ratePerKwh,
      );
    }

    // --- Monthly (period 2) ---
    final monthly = <String, double>{};
    for (final pt in points) {
      final key = '${pt.date.year}-${pt.date.month.toString().padLeft(2, '0')}';
      monthly[key] = (monthly[key] ?? 0) + pt.kwh;
    }
    final entries = monthly.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    final recent = entries.length > 6 ? entries.sublist(entries.length - 6) : entries;
    if (recent.isEmpty) {
      return const _ChartData(labels: [], values: [], peakLabel: '--', highestCost: 0);
    }
    var peakEntry = recent.first;
    for (final entry in recent) {
      if (entry.value > peakEntry.value) peakEntry = entry;
    }

    return _ChartData(
      labels: recent.map((e) => _monthLabel(e.key)).toList(),
      values: recent.map((e) => e.value).toList(),
      peakLabel: _monthLabel(peakEntry.key),
      highestCost: peakEntry.value * _ratePerKwh,
    );
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: FutureBuilder<_UsageDetailsData>(
          future: _detailsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData &&
                _cachedData == null) {
              return const Center(
                child: CircularProgressIndicator(color: AppColors.primaryBlue),
              );
            }

            if (snapshot.hasError && _cachedData == null) {
              final message = snapshot.error.toString().replaceFirst('Exception: ', '');
              return _StateCard(
                title: 'Usage details unavailable',
                message: message,
                actionLabel: 'Try again',
                onPressed: _refresh,
              );
            }

            final data = snapshot.data ??
                _cachedData ??
                const _UsageDetailsData(points: [], intervalPoints: []);
            _cachedData = data;
            final chart = _buildChartData(data);

            return Stack(
              children: [
                RefreshIndicator(
                  onRefresh: _refresh,
                  color: AppColors.primaryBlue,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Usage Details',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            color: AppColors.textMain,
                            letterSpacing: -1.1,
                          ),
                        ),
                        const SizedBox(height: 22),
                        _buildPeriodSwitcher(),
                        const SizedBox(height: 16),
                        // Date picker row — visible for Hourly tab
                        if (_selectedPeriod == 0)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Row(
                              children: [
                                GestureDetector(
                                  onTap: () => _openHourlyDatePicker(data),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryBlue
                                          .withValues(alpha: 0.10),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: AppColors.primaryBlue
                                            .withValues(alpha: 0.25),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.calendar_today_rounded,
                                          size: 14,
                                          color: AppColors.primaryBlue,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          chart.dateSubtitle ??
                                              _formatDateSubtitle(
                                                  data.dbLatestDate ??
                                                      DateTime.now()),
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.primaryBlue,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        const Icon(
                                          Icons.arrow_drop_down_rounded,
                                          size: 18,
                                          color: AppColors.primaryBlue,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                if (_pickedHourlyDate != null) ...[
                                  const SizedBox(width: 8),
                                  GestureDetector(
                                    onTap: () {
                                      setState(() => _pickedHourlyDate = null);
                                      _refresh();
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: AppColors.background,
                                        borderRadius:
                                            BorderRadius.circular(8),
                                      ),
                                      child: const Icon(Icons.close_rounded,
                                          size: 14,
                                          color: AppColors.textMuted),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          )
                        else
                          const SizedBox(height: 6),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          switchInCurve: Curves.easeOut,
                          child: Row(
                            key: ValueKey('metrics_${_selectedPeriod}_${chart.peakLabel}_${chart.highestCost}'),
                            children: [
                              Expanded(
                                child: _MetricCard(
                                  icon: Icons.access_time_rounded,
                                  title: _selectedPeriod == 0 ? 'PEAK\nHOUR' : _selectedPeriod == 2 ? 'PEAK\nMONTH' : 'PEAK\nDAY',
                                  value: chart.peakLabel,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _MetricCard(
                                  icon: Icons.attach_money_rounded,
                                  title: 'HIGHEST\nCOST',
                                  value: '\$${chart.highestCost.toStringAsFixed(2)}',
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        _buildTrendCard(chart),
                        const SizedBox(height: 20),
                        const Text(
                          'ElectricToday is an independent application and is not affiliated with, '
                          'endorsed by, sponsored by, or associated with Smart Meter Texas, any electric '
                          'utility, electricity provider, or network operator. All electricity usage '
                          'data is accessed in read-only form only after user consent.',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 14,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 120),
                      ],
                    ),
                  ),
                ),
                if (_showRefreshIndicator == true)
                  const Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: LinearProgressIndicator(
                      minHeight: 2,
                      color: AppColors.primaryBlue,
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildPeriodSwitcher() {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: List.generate(_periods.length, (index) {
          final isActive = _selectedPeriod == index;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedPeriod = index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isActive ? AppColors.textMain : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  _periods[index],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: isActive ? Colors.white : AppColors.textMuted,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildTrendCard(_ChartData chart) {
    final showCurrency = _selectedPeriod == 2;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _selectedPeriod == 2
                          ? 'Monthly Usage Trend'
                          : _selectedPeriod == 0
                              ? 'Hourly Usage'
                              : 'Usage Trend',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textMain,
                        letterSpacing: -0.3,
                      ),
                    ),
                    if (chart.dateSubtitle != null && chart.dateSubtitle!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          chart.dateSubtitle!,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.circle, size: 12, color: AppColors.primaryBlue),
                    const SizedBox(width: 8),
                    Text(
                      showCurrency ? 'COST' : 'kWh',
                      style: const TextStyle(
                        color: AppColors.textMain,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (_selectedPeriod == 0 && chart.values.isEmpty)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.warningOrange.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'Hourly interval data is not available for the selected date. Try picking a different day.',
                style: TextStyle(
                  color: AppColors.textMain,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            child: SizedBox(
              key: ValueKey('trend_${_selectedPeriod}_${_pickedHourlyDate?.toIso8601String() ?? "latest"}'),
              height: 360,
              child: UsageTrendBarChart(
                values: showCurrency
                    ? chart.values.map((v) => v * _ratePerKwh).toList()
                    : chart.values,
                labels: chart.labels,
                showCurrency: showCurrency,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Date picker for Hourly tab
  // ---------------------------------------------------------------------------

  Future<void> _openHourlyDatePicker(_UsageDetailsData data) async {
    final lastDate = data.dbLatestDate ?? DateTime.now();
    final firstDate = lastDate.subtract(const Duration(days: 90));
    final initial = _pickedHourlyDate ?? lastDate;

    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isAfter(lastDate) ? lastDate : initial,
      firstDate: firstDate,
      lastDate: lastDate,
      helpText: 'Select date for hourly data',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primaryBlue,
              onPrimary: Colors.white,
              surface: AppColors.cardBackground,
              onSurface: AppColors.textMain,
            ),
            dialogTheme: const DialogThemeData(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(24)),
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && mounted) {
      setState(() => _pickedHourlyDate = picked);
      _refresh();
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  String _dayLabel(DateTime date) {
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return names[date.weekday - 1];
  }

  String _dateLabel(DateTime date) {
    return '${date.month}/${date.day}';
  }

  String _monthLabel(String key) {
    final parts = key.split('-');
    if (parts.length != 2) return key;
    final month = int.tryParse(parts[1]) ?? 1;
    const short = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return short[(month - 1).clamp(0, 11)];
  }

  String _hourLabel(DateTime date) {
    final hour = date.hour;
    if (hour == 0) return '12a';
    if (hour < 12) return '${hour}a';
    if (hour == 12) return '12p';
    return '${hour - 12}p';
  }

  String _hourClockLabel(DateTime date) {
    final hour = date.hour;
    if (hour == 0) return '12:00 AM';
    if (hour < 12) return '$hour:00 AM';
    if (hour == 12) return '12:00 PM';
    return '${hour - 12}:00 PM';
  }

  String _formatDateSubtitle(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return '${days[date.weekday - 1]}, ${months[date.month - 1]} ${date.day}';
  }

  double? _toDouble(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  String _fmtSmtDate(DateTime d) {
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    final yyyy = d.year.toString();
    return '$mm/$dd/$yyyy';
  }
}

class _DailyPoint {
  const _DailyPoint(this.date, this.kwh);
  final DateTime date;
  final double kwh;
}

class _UsageDetailsData {
  const _UsageDetailsData({
    required this.points,
    required this.intervalPoints,
    this.dbLatestDate,
    this.odrKwh,
    this.odrDate,
  });
  final List<_DailyPoint> points;
  final List<_IntervalPoint> intervalPoints;

  /// Latest date with actual interval/history data in the DB.
  final DateTime? dbLatestDate;

  /// Live ODR kWh — may be for a day ahead of history.
  final double? odrKwh;

  /// The day the ODR reading belongs to.
  final DateTime? odrDate;
}

class _IntervalPoint {
  const _IntervalPoint(this.timestamp, this.kwh);
  final DateTime timestamp;
  final double kwh;
}

class _ChartData {
  const _ChartData({
    required this.labels,
    required this.values,
    required this.peakLabel,
    required this.highestCost,
    this.dateSubtitle,
  });

  final List<String> labels;
  final List<double> values;
  final String peakLabel;
  final double highestCost;
  /// Shows which day the chart data comes from (e.g. "Wed, Mar 29").
  final String? dateSubtitle;
}

class _StateCard extends StatelessWidget {
  const _StateCard({
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onPressed,
  });

  final String title;
  final String message;
  final String actionLabel;
  final Future<void> Function() onPressed;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textMain,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  onPressed();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(actionLabel, style: const TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.textMuted),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  height: 1.25,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.textMain,
              fontSize: 30,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
