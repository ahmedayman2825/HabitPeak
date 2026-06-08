import 'dart:math';

import '../../../core/database/app_database.dart';
import '../../../core/utils/habit_clock.dart';
import '../../habits/data/habit_repository.dart';
import '../../habits/domain/habit.dart';
import '../../habits/domain/habit_entry.dart';
import '../../settings/domain/app_settings.dart';
import '../domain/analytics_summary.dart';

class AnalyticsRepository {
  AnalyticsRepository({
    required AppDatabase database,
    required HabitRepository habits,
  }) : _database = database,
       _habits = habits;

  final AppDatabase _database;
  final HabitRepository _habits;

  Future<AnalyticsSummary> loadSummary({
    required AnalyticsWindow window,
    required DateTime now,
    required AppSettings settings,
  }) async {
    final day = HabitClock.habitDay(now, resetMinutes: settings.resetMinutes);
    final range = _rangeFor(window, day);
    final habits = await _habits.getAllHabits(includeArchived: true);
    final scheduledCount = _scheduledCountInRange(habits, range.$1, range.$2);
    final completedCount = await _completedCount(
      HabitClock.dayKey(range.$1),
      HabitClock.dayKey(range.$2),
    );
    final trackedSeconds = await _trackedSeconds(range.$1, range.$2);
    final weeklyStart = HabitClock.startOfWeek(day);
    final weeklyTracked = await _trackedSeconds(
      weeklyStart,
      weeklyStart.add(const Duration(days: 6)),
    );
    final monthlyStart = HabitClock.startOfMonth(day);
    final monthlyTracked = await _trackedSeconds(
      monthlyStart,
      DateTime(day.year, day.month + 1, 0),
    );
    final trendStart = window == AnalyticsWindow.daily
        ? day.subtract(const Duration(days: 6))
        : range.$1;
    final completionTrends = await _completionTrends(
      habits,
      trendStart,
      range.$2,
    );
    final timeTrends = await _timeTrends(
      window == AnalyticsWindow.daily
          ? day.subtract(const Duration(days: 13))
          : range.$1,
      range.$2,
    );
    final bestStreak = await _bestStreak(habits, day);
    final weakest = await _weakestHabits(
      habits.where((habit) => !habit.isArchived).toList(),
      range.$1,
      range.$2,
    );
    final mostSkippedDay = await _mostSkippedDay(range.$1, range.$2);
    final longestSession = await _longestSession(range.$1, range.$2);
    final completionPercent = scheduledCount == 0
        ? 0.0
        : completedCount / scheduledCount;
    final dailyScore = (completionPercent * 100).round().clamp(0, 100);
    final weeklyScore = _scoreFromTrends(completionTrends);
    final productivityScore = _productivityScore(
      completionPercent: completionPercent,
      trackedSeconds: weeklyTracked,
    );
    final lifeBalanceScore = await _lifeBalanceScore(day);

    return AnalyticsSummary(
      window: window,
      startDay: range.$1,
      endDay: range.$2,
      scheduledCount: scheduledCount,
      completedCount: completedCount,
      completionPercent: completionPercent,
      trackedSeconds: trackedSeconds,
      weeklyTrackedSeconds: weeklyTracked,
      monthlyTrackedSeconds: monthlyTracked,
      longestSessionSeconds: longestSession,
      bestStreak: bestStreak,
      weakestHabits: weakest,
      mostSkippedDay: mostSkippedDay,
      productivityScore: productivityScore,
      dailyScore: dailyScore,
      weeklyScore: weeklyScore,
      lifeBalanceScore: lifeBalanceScore,
      completionTrends: completionTrends,
      timeTrends: timeTrends,
    );
  }

  (DateTime, DateTime) _rangeFor(AnalyticsWindow window, DateTime day) {
    switch (window) {
      case AnalyticsWindow.daily:
        return (day, day);
      case AnalyticsWindow.weekly:
        final start = HabitClock.startOfWeek(day);
        return (start, start.add(const Duration(days: 6)));
      case AnalyticsWindow.monthly:
        return (
          HabitClock.startOfMonth(day),
          DateTime(day.year, day.month + 1, 0),
        );
    }
  }

  int _scheduledCount(List<Habit> habits, DateTime day) {
    return habits.where((habit) => habit.isScheduledOn(day)).length;
  }

  int _scheduledCountInRange(List<Habit> habits, DateTime start, DateTime end) {
    var count = 0;
    for (final day in HabitClock.daysBetween(start, end)) {
      count += _scheduledCount(habits, day);
    }
    return count;
  }

  Future<int> _completedCount(String startDay, String endDay) async {
    final db = await _database.instance;
    final rows = await db.rawQuery(
      '''
      SELECT COUNT(*) AS value
      FROM habit_entries
      WHERE day BETWEEN ? AND ? AND status = ?
      ''',
      <Object?>[startDay, endDay, HabitEntryStatus.completed.name],
    );
    return rows.first['value'] as int? ?? 0;
  }

  Future<int> _trackedSeconds(DateTime start, DateTime end) async {
    final db = await _database.instance;
    final rows = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(timer_seconds), 0) AS value
      FROM habit_entries
      WHERE day BETWEEN ? AND ?
      ''',
      <Object?>[HabitClock.dayKey(start), HabitClock.dayKey(end)],
    );
    return rows.first['value'] as int? ?? 0;
  }

  Future<List<CompletionTrend>> _completionTrends(
    List<Habit> habits,
    DateTime start,
    DateTime end,
  ) async {
    final db = await _database.instance;
    final rows = await db.rawQuery(
      '''
      SELECT day, COUNT(*) AS completed
      FROM habit_entries
      WHERE day BETWEEN ? AND ? AND status = ?
      GROUP BY day
      ''',
      <Object?>[
        HabitClock.dayKey(start),
        HabitClock.dayKey(end),
        HabitEntryStatus.completed.name,
      ],
    );
    final completedByDay = <String, int>{
      for (final row in rows) row['day'] as String: row['completed'] as int,
    };
    return HabitClock.daysBetween(start, end).map((day) {
      final key = HabitClock.dayKey(day);
      return CompletionTrend(
        day: day,
        completed: completedByDay[key] ?? 0,
        scheduled: _scheduledCount(habits, day),
      );
    }).toList();
  }

  Future<List<TimeTrend>> _timeTrends(DateTime start, DateTime end) async {
    final db = await _database.instance;
    final rows = await db.rawQuery(
      '''
      SELECT day, COALESCE(SUM(timer_seconds), 0) AS seconds
      FROM habit_entries
      WHERE day BETWEEN ? AND ?
      GROUP BY day
      ''',
      <Object?>[HabitClock.dayKey(start), HabitClock.dayKey(end)],
    );
    final secondsByDay = <String, int>{
      for (final row in rows) row['day'] as String: row['seconds'] as int,
    };
    return HabitClock.daysBetween(start, end).map((day) {
      final key = HabitClock.dayKey(day);
      return TimeTrend(day: day, seconds: secondsByDay[key] ?? 0);
    }).toList();
  }

  Future<int> _bestStreak(List<Habit> habits, DateTime day) async {
    var best = 0;
    for (final habit in habits) {
      best = max(best, await _habits.calculateStreak(habit, day));
    }
    return best;
  }

  Future<List<String>> _weakestHabits(
    List<Habit> habits,
    DateTime start,
    DateTime end,
  ) async {
    final db = await _database.instance;
    final result = <({String name, double rate})>[];
    for (final habit in habits) {
      var scheduled = 0;
      for (final day in HabitClock.daysBetween(start, end)) {
        if (habit.isScheduledOn(day)) {
          scheduled++;
        }
      }
      if (scheduled == 0) {
        continue;
      }
      final rows = await db.rawQuery(
        '''
        SELECT COUNT(*) AS completed
        FROM habit_entries
        WHERE habit_id = ? AND day BETWEEN ? AND ? AND status = ?
        ''',
        <Object?>[
          habit.id,
          HabitClock.dayKey(start),
          HabitClock.dayKey(end),
          HabitEntryStatus.completed.name,
        ],
      );
      final completed = rows.first['completed'] as int? ?? 0;
      result.add((name: habit.name, rate: completed / scheduled));
    }
    result.sort((a, b) => a.rate.compareTo(b.rate));
    return result.take(3).map((item) => item.name).toList();
  }

  Future<String> _mostSkippedDay(DateTime start, DateTime end) async {
    final db = await _database.instance;
    final rows = await db.query(
      'habit_entries',
      columns: <String>['day'],
      where: 'day BETWEEN ? AND ? AND status IN (?, ?)',
      whereArgs: <Object?>[
        HabitClock.dayKey(start),
        HabitClock.dayKey(end),
        HabitEntryStatus.skipped.name,
        HabitEntryStatus.missed.name,
      ],
    );
    if (rows.isEmpty) {
      return 'None yet';
    }
    final counts = <int, int>{};
    for (final row in rows) {
      final weekday = HabitClock.parseDayKey(row['day'] as String).weekday;
      counts[weekday] = (counts[weekday] ?? 0) + 1;
    }
    final weekday = counts.entries
        .reduce((a, b) => a.value >= b.value ? a : b)
        .key;
    return const <int, String>{
      1: 'Monday',
      2: 'Tuesday',
      3: 'Wednesday',
      4: 'Thursday',
      5: 'Friday',
      6: 'Saturday',
      7: 'Sunday',
    }[weekday]!;
  }

  Future<int> _longestSession(DateTime start, DateTime end) async {
    final db = await _database.instance;
    final rows = await db.rawQuery(
      '''
      SELECT COALESCE(MAX(accumulated_seconds), 0) AS value
      FROM timer_sessions
      WHERE day BETWEEN ? AND ?
      ''',
      <Object?>[HabitClock.dayKey(start), HabitClock.dayKey(end)],
    );
    return rows.first['value'] as int? ?? 0;
  }

  Future<HabitAnalyticsSummary> loadHabitSummary({
    required Habit habit,
    required DateTime now,
    required AppSettings settings,
  }) async {
    final today = HabitClock.habitDay(now, resetMinutes: settings.resetMinutes);
    final db = await _database.instance;
    final entryRows = await db.query(
      'habit_entries',
      where: 'habit_id = ?',
      whereArgs: <Object?>[habit.id],
      orderBy: 'day ASC',
    );
    final firstEntryDay = entryRows.isEmpty
        ? null
        : HabitClock.parseDayKey(entryRows.first['day'] as String);
    final firstDay = _latestDate(
      habit.schedule.startDate ?? firstEntryDay ?? habit.createdAt,
      DateTime(2000),
    );
    final archiveDay = habit.archivedAt == null
        ? null
        : DateTime(
            habit.archivedAt!.year,
            habit.archivedAt!.month,
            habit.archivedAt!.day,
          );
    final endBySchedule = habit.schedule.endDate;
    var lastDay = today;
    if (endBySchedule != null && endBySchedule.isBefore(lastDay)) {
      lastDay = endBySchedule;
    }
    if (archiveDay != null && archiveDay.isBefore(lastDay)) {
      lastDay = archiveDay;
    }
    final safeLastDay = lastDay.isBefore(firstDay) ? firstDay : lastDay;

    var scheduledCount = 0;
    for (final day in HabitClock.daysBetween(firstDay, safeLastDay)) {
      if (habit.schedule.isScheduledOn(day)) {
        scheduledCount++;
      }
    }

    final completedCount = entryRows
        .where((row) => row['status'] == HabitEntryStatus.completed.name)
        .length;
    final skippedCount = entryRows
        .where((row) => row['status'] == HabitEntryStatus.skipped.name)
        .length;
    final missedCount = max(0, scheduledCount - completedCount - skippedCount);
    final totalNumber = entryRows.fold<int>(
      0,
      (sum, row) => sum + (row['number_value'] as int? ?? 0),
    );
    final totalTimer = entryRows.fold<int>(
      0,
      (sum, row) => sum + (row['timer_seconds'] as int? ?? 0),
    );
    final longestSessionRows = await db.rawQuery(
      '''
      SELECT COALESCE(MAX(accumulated_seconds), 0) AS value
      FROM timer_sessions
      WHERE habit_id = ?
      ''',
      <Object?>[habit.id],
    );
    final completionPercent = scheduledCount == 0
        ? 0.0
        : completedCount / scheduledCount;
    final trendStart = safeLastDay.subtract(const Duration(days: 29));
    final completedDays = {
      for (final row in entryRows)
        if (row['status'] == HabitEntryStatus.completed.name)
          row['day'] as String,
    };
    final secondsByDay = <String, int>{};
    for (final row in entryRows) {
      final key = row['day'] as String;
      secondsByDay[key] =
          (secondsByDay[key] ?? 0) + (row['timer_seconds'] as int? ?? 0);
    }

    final canRestore = await _habits.canRestoreStreak(habit.id, now, settings);

    return HabitAnalyticsSummary(
      habitName: habit.name,
      scheduledCount: scheduledCount,
      completedCount: completedCount,
      missedCount: missedCount,
      skippedCount: skippedCount,
      completionPercent: completionPercent,
      currentStreak: await _habits.calculateStreak(habit, today),
      totalNumberValue: totalNumber,
      totalTimerSeconds: totalTimer,
      longestSessionSeconds: longestSessionRows.first['value'] as int? ?? 0,
      firstDay: firstDay,
      lastDay: safeLastDay,
      completionTrends: HabitClock.daysBetween(trendStart, safeLastDay).map((
        day,
      ) {
        final key = HabitClock.dayKey(day);
        return CompletionTrend(
          day: day,
          completed: completedDays.contains(key) ? 1 : 0,
          scheduled: habit.schedule.isScheduledOn(day) ? 1 : 0,
        );
      }).toList(),
      timeTrends: HabitClock.daysBetween(trendStart, safeLastDay).map((day) {
        final key = HabitClock.dayKey(day);
        return TimeTrend(day: day, seconds: secondsByDay[key] ?? 0);
      }).toList(),
      canRestore: canRestore,
    );
  }

  int _scoreFromTrends(List<CompletionTrend> trends) {
    final scheduled = trends.fold<int>(
      0,
      (sum, trend) => sum + trend.scheduled,
    );
    if (scheduled == 0) {
      return 0;
    }
    final completed = trends.fold<int>(
      0,
      (sum, trend) => sum + trend.completed,
    );
    return ((completed / scheduled) * 100).round().clamp(0, 100);
  }

  int _productivityScore({
    required double completionPercent,
    required int trackedSeconds,
  }) {
    final completionScore = completionPercent * 70;
    final timeScore =
        min(trackedSeconds / const Duration(hours: 7).inSeconds, 1) * 30;
    return (completionScore + timeScore).round().clamp(0, 100);
  }

  Future<int> _lifeBalanceScore(DateTime day) async {
    final db = await _database.instance;
    final start = day.subtract(const Duration(days: 6));
    final rows = await db.rawQuery(
      '''
      SELECT habit_id, COALESCE(SUM(timer_seconds), 0) AS seconds
      FROM habit_entries
      WHERE day BETWEEN ? AND ? AND timer_seconds > 0
      GROUP BY habit_id
      ''',
      <Object?>[HabitClock.dayKey(start), HabitClock.dayKey(day)],
    );
    if (rows.length <= 1) {
      return rows.isEmpty ? 0 : 60;
    }
    final seconds = rows.map((row) => row['seconds'] as int).toList();
    final total = seconds.fold<int>(0, (sum, value) => sum + value);
    if (total == 0) {
      return 0;
    }
    final maxShare = seconds.reduce(max) / total;
    return ((1 - maxShare) * 125).round().clamp(0, 100);
  }

  DateTime _latestDate(DateTime a, DateTime b) {
    final first = DateTime(a.year, a.month, a.day);
    final second = DateTime(b.year, b.month, b.day);
    return first.isAfter(second) ? first : second;
  }
}
