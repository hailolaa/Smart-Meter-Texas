class TexasTime {
  TexasTime._();

  static const Duration _cstOffset = Duration(hours: -6);
  static const Duration _cdtOffset = Duration(hours: -5);

  /// Returns the current wall-clock time in Texas (America/Chicago).
  static DateTime now() => _fromUtc(DateTime.now().toUtc());

  /// Returns today's date in Texas with the time normalized to midnight.
  static DateTime today() {
    final current = now();
    return DateTime(current.year, current.month, current.day);
  }

  static DateTime _fromUtc(DateTime utc) {
    final shiftedUtc = utc.add(_isDstInTexasUtc(utc) ? _cdtOffset : _cstOffset);
    return DateTime(
      shiftedUtc.year,
      shiftedUtc.month,
      shiftedUtc.day,
      shiftedUtc.hour,
      shiftedUtc.minute,
      shiftedUtc.second,
      shiftedUtc.millisecond,
      shiftedUtc.microsecond,
    );
  }

  static bool _isDstInTexasUtc(DateTime utc) {
    final year = utc.year;
    final dstStartDay = _nthWeekdayOfMonthUtc(
      year: year,
      month: 3,
      weekday: DateTime.sunday,
      occurrence: 2,
    );
    final dstEndDay = _nthWeekdayOfMonthUtc(
      year: year,
      month: 11,
      weekday: DateTime.sunday,
      occurrence: 1,
    );

    // Central DST starts at 2:00 AM local CST => 08:00 UTC.
    final dstStartUtc = DateTime.utc(year, 3, dstStartDay, 8);
    // Central DST ends at 2:00 AM local CDT => 07:00 UTC.
    final dstEndUtc = DateTime.utc(year, 11, dstEndDay, 7);

    return !utc.isBefore(dstStartUtc) && utc.isBefore(dstEndUtc);
  }

  static int _nthWeekdayOfMonthUtc({
    required int year,
    required int month,
    required int weekday,
    required int occurrence,
  }) {
    final firstDay = DateTime.utc(year, month, 1);
    final delta = (weekday - firstDay.weekday + 7) % 7;
    return 1 + delta + (occurrence - 1) * 7;
  }
}
