import 'package:intl/intl.dart';

class HabitClock {
  HabitClock._();

  static final DateFormat _dayFormat = DateFormat('yyyy-MM-dd');

  static String dayKey(DateTime date, {int resetMinutes = 0}) {
    return _dayFormat.format(habitDay(date, resetMinutes: resetMinutes));
  }

  static DateTime habitDay(DateTime date, {int resetMinutes = 0}) {
    final resetToday = DateTime(
      date.year,
      date.month,
      date.day,
      resetMinutes ~/ 60,
      resetMinutes % 60,
    );
    final shifted = date.isBefore(resetToday)
        ? date.subtract(const Duration(days: 1))
        : date;
    return DateTime(shifted.year, shifted.month, shifted.day);
  }

  static DateTime parseDayKey(String key) {
    final parts = key.split('-').map(int.parse).toList();
    return DateTime(parts[0], parts[1], parts[2]);
  }

  static String displayDay(DateTime date) =>
      DateFormat('EEE, MMM d').format(date);

  static bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  static DateTime startOfWeek(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    return day.subtract(Duration(days: day.weekday - DateTime.monday));
  }

  static DateTime startOfMonth(DateTime date) {
    return DateTime(date.year, date.month);
  }

  static DateTime resetBoundaryAfterDay(String dayKey, int resetMinutes) {
    final day = parseDayKey(dayKey);
    return DateTime(
      day.year,
      day.month,
      day.day,
    ).add(Duration(days: 1, minutes: resetMinutes));
  }

  static Iterable<DateTime> daysBetween(DateTime start, DateTime end) sync* {
    var cursor = DateTime(start.year, start.month, start.day);
    final last = DateTime(end.year, end.month, end.day);
    while (!cursor.isAfter(last)) {
      yield cursor;
      cursor = cursor.add(const Duration(days: 1));
    }
  }
}
