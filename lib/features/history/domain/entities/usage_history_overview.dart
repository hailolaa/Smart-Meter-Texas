class UsageHistoryOverview {
  const UsageHistoryOverview({
    required this.yesterdayKwh,
    required this.last7DaysKwh,
    required this.last30DaysKwh,
    required this.yesterdayCost,
    required this.last7DaysCost,
    required this.last30DaysCost,
    this.latestDate,
    this.latestMeterReadKwh,
    this.latestMeterReadAt,
    this.yesterdayDays = 0,
    this.last7Days = 0,
    this.last30Days = 0,
  });

  final double yesterdayKwh;
  final double last7DaysKwh;
  final double last30DaysKwh;
  final double yesterdayCost;
  final double last7DaysCost;
  final double last30DaysCost;

  /// The most recent date with data in the DB (YYYY-MM-DD).
  final String? latestDate;

  /// Latest on-demand meter read value.
  final double? latestMeterReadKwh;
  final String? latestMeterReadAt;

  /// Number of days with data in each range.
  final int yesterdayDays;
  final int last7Days;
  final int last30Days;

  bool get hasAnyUsage => yesterdayKwh > 0 || last7DaysKwh > 0 || last30DaysKwh > 0;
}
