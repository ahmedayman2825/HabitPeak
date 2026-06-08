import 'dart:convert';

enum RecurrenceType {
  daily,
  dailyBetweenDates,
  oneTime,
  weekly,
  monthly,
  custom,
}

class RecurrenceRule {
  const RecurrenceRule({
    required this.type,
    this.startDate,
    this.endDate,
    this.selectedWeekdays = const <int>[],
    this.excludedWeekdays = const <int>[],
    this.monthDays = const <int>[],
    this.intervalDays,
  });

  factory RecurrenceRule.daily({List<int> excludedWeekdays = const <int>[]}) {
    return RecurrenceRule(
      type: RecurrenceType.daily,
      excludedWeekdays: excludedWeekdays,
    );
  }

  factory RecurrenceRule.fromMap(Map<String, Object?> map) {
    return RecurrenceRule(
      type: RecurrenceType.values.byName(map['recurrence_type'] as String),
      startDate: _parseDate(map['start_date'] as String?),
      endDate: _parseDate(map['end_date'] as String?),
      selectedWeekdays: _decodeIntList(map['selected_weekdays'] as String?),
      excludedWeekdays: _decodeIntList(map['excluded_weekdays'] as String?),
      monthDays: _decodeIntList(map['month_days'] as String?),
      intervalDays: map['interval_days'] as int?,
    );
  }

  factory RecurrenceRule.fromJson(Map<String, Object?> json) {
    return RecurrenceRule(
      type: RecurrenceType.values.byName(json['type'] as String),
      startDate: _parseDate(json['startDate'] as String?),
      endDate: _parseDate(json['endDate'] as String?),
      selectedWeekdays: (json['selectedWeekdays'] as List? ?? const <Object?>[])
          .cast<int>(),
      excludedWeekdays: (json['excludedWeekdays'] as List? ?? const <Object?>[])
          .cast<int>(),
      monthDays: (json['monthDays'] as List? ?? const <Object?>[]).cast<int>(),
      intervalDays: json['intervalDays'] as int?,
    );
  }

  final RecurrenceType type;
  final DateTime? startDate;
  final DateTime? endDate;
  final List<int> selectedWeekdays;
  final List<int> excludedWeekdays;
  final List<int> monthDays;
  final int? intervalDays;

  bool isScheduledOn(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    if (startDate != null && day.isBefore(_dateOnly(startDate!))) {
      return false;
    }
    if (endDate != null && day.isAfter(_dateOnly(endDate!))) {
      return false;
    }
    if (excludedWeekdays.contains(day.weekday)) {
      return false;
    }

    switch (type) {
      case RecurrenceType.daily:
        return true;
      case RecurrenceType.dailyBetweenDates:
        return startDate != null && endDate != null;
      case RecurrenceType.oneTime:
        return startDate != null && _sameDay(day, startDate!);
      case RecurrenceType.weekly:
        return selectedWeekdays.contains(day.weekday);
      case RecurrenceType.monthly:
        return monthDays.contains(day.day);
      case RecurrenceType.custom:
        return _matchesCustom(day);
    }
  }

  Map<String, Object?> toMap(String habitId) {
    return <String, Object?>{
      'habit_id': habitId,
      'recurrence_type': type.name,
      'start_date': _encodeDate(startDate),
      'end_date': _encodeDate(endDate),
      'selected_weekdays': jsonEncode(selectedWeekdays),
      'excluded_weekdays': jsonEncode(excludedWeekdays),
      'month_days': jsonEncode(monthDays),
      'interval_days': intervalDays,
    };
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'type': type.name,
      'startDate': _encodeDate(startDate),
      'endDate': _encodeDate(endDate),
      'selectedWeekdays': selectedWeekdays,
      'excludedWeekdays': excludedWeekdays,
      'monthDays': monthDays,
      'intervalDays': intervalDays,
    };
  }

  RecurrenceRule copyWith({
    RecurrenceType? type,
    DateTime? startDate,
    DateTime? endDate,
    List<int>? selectedWeekdays,
    List<int>? excludedWeekdays,
    List<int>? monthDays,
    int? intervalDays,
  }) {
    return RecurrenceRule(
      type: type ?? this.type,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      selectedWeekdays: selectedWeekdays ?? this.selectedWeekdays,
      excludedWeekdays: excludedWeekdays ?? this.excludedWeekdays,
      monthDays: monthDays ?? this.monthDays,
      intervalDays: intervalDays ?? this.intervalDays,
    );
  }

  bool _matchesCustom(DateTime day) {
    final weekdayMatches =
        selectedWeekdays.isEmpty || selectedWeekdays.contains(day.weekday);
    final monthDayMatches = monthDays.isEmpty || monthDays.contains(day.day);
    final interval = intervalDays;
    if (interval == null || interval <= 1) {
      return weekdayMatches && monthDayMatches;
    }
    final anchor = startDate ?? DateTime(day.year, day.month, day.day);
    final delta = day.difference(_dateOnly(anchor)).inDays;
    return delta >= 0 &&
        delta % interval == 0 &&
        weekdayMatches &&
        monthDayMatches;
  }

  static DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  static bool _sameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  static String? _encodeDate(DateTime? date) {
    if (date == null) {
      return null;
    }
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  static DateTime? _parseDate(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }
    final parts = value.split('-').map(int.parse).toList();
    return DateTime(parts[0], parts[1], parts[2]);
  }

  static List<int> _decodeIntList(String? value) {
    if (value == null || value.isEmpty) {
      return const <int>[];
    }
    return (jsonDecode(value) as List).cast<int>();
  }
}
