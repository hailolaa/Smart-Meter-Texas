import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/network/energy_realtime_client.dart';
import '../../../../core/network/smt_api_client.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/session/smt_session_store.dart';
import '../../../../core/theme/app_date_picker.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/texas_time.dart';
import 'usage_line_chart.dart';

class UsagePatternCard extends StatefulWidget {
  const UsagePatternCard({super.key});

  @override
  State<UsagePatternCard> createState() => _UsagePatternCardState();
}

class _UsagePatternCardState extends State<UsagePatternCard> {
  String selectedFilter = '1 hr';
  final _apiClient = SmtApiClient();
  bool _loading = true;
  List<double> _values = const [];
  List<String> _labels = const [];
  String _dateSubtitle = '';
  Map<String, _PatternData>? _patternCache = <String, _PatternData>{};
  int? _requestSeq = 0;

  // Cached anchor info from the backend summary.
  _HistoryAnchor? _cachedAnchor;
  DateTime? _anchorFetchedAt;

  // User-picked date for interval charts (null = use latest from history).
  DateTime? _pickedDate;

  final EnergyRealtimeClient _realtimeClient = WebSocketEnergyRealtimeClient();
  StreamSubscription<EnergyRealtimeMessage>? _realtimeSubscription;
  Timer? _realtimeDebounce;

  @override
  void initState() {
    super.initState();
    _loadPattern();
    _startRealtime();
  }

  @override
  void dispose() {
    _realtimeDebounce?.cancel();
    _realtimeSubscription?.cancel();
    _realtimeClient.disconnect();
    _realtimeClient.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Data loading
  // ---------------------------------------------------------------------------

  Future<void> _loadPattern({
    bool forceRefresh = false,
    bool silent = false,
  }) async {
    final requestedFilter = selectedFilter;
    final reqId = (_requestSeq ?? 0) + 1;
    _requestSeq = reqId;
    final hadData = _values.isNotEmpty;
    if (!silent) {
      setState(() {
        _loading = !hadData;
      });
    }

    try {
      final anchor = await _getHistoryAnchor(forceRefresh: forceRefresh);
      final cache = _patternCache ??= <String, _PatternData>{};
      final effectiveDay =
          (requestedFilter == '15 min' || requestedFilter == '1 hr')
          ? (_pickedDate ?? anchor.dbLatestDate)
          : anchor.dbLatestDate;
      final cacheKey =
          '${requestedFilter}_${effectiveDay.toIso8601String().split('T').first}';
      if (!forceRefresh) {
        final cached = cache[cacheKey];
        if (cached != null) {
          if (!mounted ||
              reqId != (_requestSeq ?? 0) ||
              selectedFilter != requestedFilter)
          {
            return;
          }
          setState(() {
            _values = cached.values;
            _labels = cached.labels;
            _dateSubtitle = cached.subtitle;
            _loading = false;
          });
          // Revalidate in the background to keep data fresh without blocking UX.
          unawaited(_loadPattern(forceRefresh: true, silent: true));
          return;
        }
      }

      // -----------------------------------------------------------------------
      // KEY LOGIC:
      //   15-min / 1-hr  → use _pickedDate if set, else dbLatestDate (the
      //                     latest day that actually has SMT interval data).
      //   24h daily       → use DB daily points + inject live ODR as today's bar.
      // -----------------------------------------------------------------------
      String granularity;
      DateTime start;
      DateTime end;

      if (requestedFilter == '15 min') {
        granularity = '15m';
        final targetDay = _pickedDate ?? anchor.dbLatestDate;
        start = targetDay;
        end = targetDay;
      } else if (requestedFilter == '1 hr') {
        granularity = '1h';
        final targetDay = _pickedDate ?? anchor.dbLatestDate;
        start = targetDay;
        end = targetDay;
      } else {
        granularity = '1d';
        end = anchor.dbLatestDate;
        start = anchor.dbLatestDate.subtract(const Duration(days: 6));
      }

      final response = await _apiClient.getUsageHistory(
        granularity: granularity,
        startDate: _fmtSmtDate(start),
        endDate: _fmtSmtDate(end),
      );

      final rawPoints =
          (response['data']?['result']?['points'] ??
                  response['data']?['points'])
              as List?;
      final points = <_Point>[];
      if (rawPoints != null) {
        for (final item in rawPoints) {
          if (item is! Map) continue;
          final ts = DateTime.tryParse(item['timestamp']?.toString() ?? '');
          final usage = _toDouble(item['usage']);
          if (ts == null || usage == null) continue;
          points.add(_Point(ts, usage));
        }
      }

      points.sort((a, b) => a.ts.compareTo(b.ts));
      late final List<_Point> chartPoints;
      late final String subtitle;

      if (requestedFilter == '15 min') {
        final targetDay = _pickedDate ?? anchor.dbLatestDate;
        chartPoints = _buildFullDaySeries(
          points: points,
          anchorDate: targetDay,
          stepMinutes: 15,
          slots: 96,
        );
        subtitle = _formatDateSubtitle(targetDay);
      } else if (requestedFilter == '1 hr') {
        final targetDay = _pickedDate ?? anchor.dbLatestDate;
        chartPoints = _buildFullDaySeries(
          points: points,
          anchorDate: targetDay,
          stepMinutes: 60,
          slots: 24,
        );
        subtitle = _formatDateSubtitle(targetDay);
      } else {
        chartPoints = _buildDailySeriesWithOdr(
          points: points,
          anchorDate: anchor.dbLatestDate,
          odrKwh: anchor.odrKwh,
          odrDate: anchor.odrDate,
        );
        subtitle = '';
      }

      final nextValues = chartPoints.map((e) => e.usage).toList();
      final nextLabels = chartPoints
          .map((e) => _labelForFilter(e.ts, requestedFilter))
          .toList();
      cache[cacheKey] = _PatternData(
        values: nextValues,
        labels: nextLabels,
        subtitle: subtitle,
      );
      if (cache.length > 12) {
        cache.remove(cache.keys.first);
      }

      if (!mounted ||
          reqId != (_requestSeq ?? 0) ||
          selectedFilter != requestedFilter)
      {
        return;
      }
      setState(() {
        _values = nextValues;
        _labels = nextLabels;
        _dateSubtitle = subtitle;
        _loading = false;
      });
    } on AppException catch (e) {
      if (!mounted) return;
      if (!silent) {
        setState(() => _loading = false);
        _showThemedToast(e.message);
      }
    } catch (e) {
      if (!mounted) return;
      if (!silent) {
        setState(() => _loading = false);
        _showThemedToast(e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Anchor resolution — always gives the DB history date (where interval data
  // actually exists) plus the live ODR reading for daily-chart injection.
  // ---------------------------------------------------------------------------

  Future<_HistoryAnchor> _getHistoryAnchor({bool forceRefresh = false}) async {
    final fetchedAt = _anchorFetchedAt;
    final cached = _cachedAnchor;
    if (!forceRefresh &&
        cached != null &&
        fetchedAt != null &&
        DateTime.now().difference(fetchedAt) < const Duration(minutes: 2)) {
      return cached;
    }
    // Only latestDate/latestMeterRead are needed here; smaller payload is faster.
    final summaryResponse = await _apiClient.getUserUsageHistory(days: 7);
    final summaryData = summaryResponse['data'] as Map<String, dynamic>? ?? {};
    final latestDateRaw = summaryData['latestDate']?.toString();
    final dbLatestDate =
        DateTime.tryParse(latestDateRaw ?? '') ?? TexasTime.today();

    // Live ODR info — used only in the 24h daily chart.
    final meterRead = summaryData['latestMeterRead'] as Map<String, dynamic>?;
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

    final anchor = _HistoryAnchor(
      dbLatestDate: dbLatestDate,
      odrKwh: odrKwh,
      odrDate: odrDate,
    );
    _cachedAnchor = anchor;
    _anchorFetchedAt = DateTime.now();
    return anchor;
  }

  // ---------------------------------------------------------------------------
  // Series builders
  // ---------------------------------------------------------------------------

  /// Build a zero-filled series for a full day at `stepMinutes` granularity.
  List<_Point> _buildFullDaySeries({
    required List<_Point> points,
    required DateTime anchorDate,
    required int stepMinutes,
    required int slots,
  }) {
    final day = DateTime(anchorDate.year, anchorDate.month, anchorDate.day);
    final buckets = <int, double>{};
    for (final pt in points) {
      if (!_sameDay(pt.ts, day)) continue;
      final minutes = pt.ts.hour * 60 + pt.ts.minute;
      final index = (minutes / stepMinutes).floor().clamp(0, slots - 1);
      buckets[index] = (buckets[index] ?? 0) + pt.usage;
    }
    return List.generate(slots, (i) {
      final ts = day.add(Duration(minutes: i * stepMinutes));
      return _Point(ts, buckets[i] ?? 0);
    });
  }

  /// Build a 7-day daily series, injecting today's live ODR reading if it's
  /// a newer day than the DB history.
  List<_Point> _buildDailySeriesWithOdr({
    required List<_Point> points,
    required DateTime anchorDate,
    required double? odrKwh,
    required DateTime? odrDate,
  }) {
    final byDay = <DateTime, double>{};
    for (final pt in points) {
      final day = DateTime(pt.ts.year, pt.ts.month, pt.ts.day);
      byDay[day] = (byDay[day] ?? 0) + pt.usage;
    }

    // Inject ODR as today's point if it's after the history anchor.
    final dbEnd = DateTime(anchorDate.year, anchorDate.month, anchorDate.day);
    DateTime chartEnd = dbEnd;
    if (odrDate != null && odrKwh != null && odrKwh > 0) {
      final odrDay = DateTime(odrDate.year, odrDate.month, odrDate.day);
      if (odrDay.isAfter(dbEnd)) {
        // ODR is for a day not yet in history — add it.
        byDay[odrDay] = odrKwh;
        chartEnd = odrDay;
      } else if (odrDay.isAtSameMomentAs(dbEnd)) {
        // ODR is for the same day — use the larger value (ODR may be more
        // recent intra-day than the history sync).
        byDay[odrDay] = (byDay[odrDay] ?? 0) > odrKwh ? byDay[odrDay]! : odrKwh;
      }
    }

    return List.generate(7, (i) {
      final day = chartEnd.subtract(Duration(days: 6 - i));
      return _Point(day, byDay[day] ?? 0);
    });
  }

  // ---------------------------------------------------------------------------
  // Realtime
  // ---------------------------------------------------------------------------

  void _startRealtime() {
    final token = SmtSessionStore.instance.jwtToken;
    if (token == null || token.isEmpty) return;
    try {
      _realtimeSubscription = _realtimeClient.connect(jwtToken: token).listen((
        event,
      ) {
        if (event.type != 'history_changed' &&
            event.type != 'energy_snapshot') {
          return;
        }
        if (!mounted) return;
        _realtimeDebounce?.cancel();
        _realtimeDebounce = Timer(
          const Duration(milliseconds: 700),
          () => _loadPattern(forceRefresh: true, silent: true),
        );
      }, onError: (_) {});
    } catch (_) {
      // Existing manual/filter refresh remains fallback.
    }
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.cardBackground,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.show_chart,
                        color: AppColors.textMain,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Flexible(
                      child: Text(
                        "Usage Pattern",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textMain,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              // Time Toggle Container
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: ['15 min', '1 hr', '24h'].map((filter) {
                    final isSelected = selectedFilter == filter;
                    return GestureDetector(
                      onTap: () {
                        if (selectedFilter == filter) return;
                        setState(() {
                          selectedFilter = filter;
                          // Clear picked date when switching to 24h daily tab.
                          if (filter == '24h') _pickedDate = null;
                        });
                        _loadPattern();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.white : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.05),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                        child: Text(
                          filter,
                          style: TextStyle(
                            color: isSelected
                                ? AppColors.textMain
                                : AppColors.textMuted,
                            fontSize: 10,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.w800,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Date picker row — visible only for 15 min / 1 hr tabs
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            alignment: Alignment.topLeft,
            child: (selectedFilter == '15 min' || selectedFilter == '1 hr')
                ? Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: _openDatePicker,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primaryBlue.withValues(
                                alpha: 0.10,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors.primaryBlue.withValues(
                                  alpha: 0.25,
                                ),
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
                                AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 200),
                                  child: Text(
                                    _dateSubtitle.isNotEmpty
                                        ? _dateSubtitle
                                        : 'Pick date',
                                    key: ValueKey(_dateSubtitle),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primaryBlue,
                                    ),
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
                        if (_pickedDate != null) ...[
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () {
                              setState(() => _pickedDate = null);
                              _loadPattern(forceRefresh: true);
                            },
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: AppColors.background,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.close_rounded,
                                size: 14,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  )
                : const SizedBox(height: 16),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            child: _loading && _values.isEmpty
                ? const SizedBox(
                    key: ValueKey('loading'),
                    height: 220,
                    child: Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primaryBlue,
                      ),
                    ),
                  )
                : SizedBox(
                    key: ValueKey(
                      'chart_${selectedFilter}_${_pickedDate?.toIso8601String() ?? "latest"}',
                    ),
                    height: 220,
                    child: UsageLineChart(
                      filter: selectedFilter,
                      values: _values,
                      labels: _labels,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Date picker
  // ---------------------------------------------------------------------------

  Future<void> _openDatePicker() async {
    final anchor = _cachedAnchor;
    // Keep calendar synced to Texas "today" even when DB latest lags by a day.
    final texasToday = TexasTime.today();
    final historyLastDate = anchor?.dbLatestDate ?? texasToday;
    final lastDate = historyLastDate.isBefore(texasToday) ? texasToday : historyLastDate;
    // Allow going back up to 90 days.
    final firstDate = lastDate.subtract(const Duration(days: 90));
    final initial = _pickedDate ?? lastDate;

    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isAfter(lastDate) ? lastDate : initial,
      firstDate: firstDate,
      lastDate: lastDate,
      currentDate: texasToday,
      helpText: 'Select date for interval data',
      builder: buildAppDatePicker,
    );

    if (picked != null && mounted) {
      setState(() => _pickedDate = picked);
      _loadPattern(forceRefresh: true);
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  void _showThemedToast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFFEF4444),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          elevation: 6,
          duration: const Duration(seconds: 4),
        ),
      );
  }

  String _fmtSmtDate(DateTime d) {
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    final yyyy = d.year.toString();
    return '$mm/$dd/$yyyy';
  }

  String _labelForFilter(DateTime ts, String filter) {
    if (filter == '15 min') {
      final hh = ts.hour.toString().padLeft(2, '0');
      final mm = ts.minute.toString().padLeft(2, '0');
      return '$hh:$mm';
    }
    if (filter == '1 hr') {
      final h = ts.hour;
      if (h == 0) return '12a';
      if (h < 12) return '${h}a';
      if (h == 12) return '12p';
      return '${h - 12}p';
    }
    // 24h — show weekday + day number for context
    return _weekdayShort(ts);
  }

  String _formatDateSubtitle(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return '${days[date.weekday - 1]}, ${months[date.month - 1]} ${date.day}';
  }

  String _weekdayShort(DateTime date) {
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return names[date.weekday - 1];
  }

  bool _sameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  double? _toDouble(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }
}

class _Point {
  const _Point(this.ts, this.usage);
  final DateTime ts;
  final double usage;
}

class _PatternData {
  const _PatternData({
    required this.values,
    required this.labels,
    this.subtitle = '',
  });

  final List<double> values;
  final List<String> labels;
  final String subtitle;
}

/// Separates the DB history date (where interval data exists) from the live
/// ODR reading (used only to supplement the 24h daily chart).
class _HistoryAnchor {
  const _HistoryAnchor({required this.dbLatestDate, this.odrKwh, this.odrDate});

  /// Most recent date in the daily_usage DB table — interval data exists here.
  final DateTime dbLatestDate;

  /// Live ODR kWh (may be for today, which has no interval data yet).
  final double? odrKwh;

  /// The day the ODR reading belongs to.
  final DateTime? odrDate;
}
