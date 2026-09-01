import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/utils/habit_clock.dart';
import '../../settings/domain/app_settings.dart';
import '../../timer/domain/timer_session.dart';
import '../domain/habit.dart';
import '../domain/habit_entry.dart';
import '../domain/habit_with_entry.dart';
import 'habit_repository.dart';

class LocalHabitRepository implements HabitRepository {
  LocalHabitRepository(this._database, {this.onChanged});

  final AppDatabase _database;
  final void Function()? onChanged;
  final Uuid _uuid = const Uuid();

  @override
  Future<List<Habit>> getAllHabits({bool includeArchived = false}) async {
    final db = await _database.instance;
    // Single JOIN query replaces N+1 individual SELECTs for schedules+targets.
    final rows = await db.rawQuery('''
      SELECT h.*, s.recurrence_type, s.start_date, s.end_date,
             s.selected_weekdays, s.excluded_weekdays, s.month_days, s.interval_days,
             t.number_target, t.timer_target_seconds
      FROM habits h
      INNER JOIN habit_schedules s ON s.habit_id = h.id
      LEFT JOIN habit_targets t ON t.habit_id = h.id
      ${includeArchived ? '' : 'WHERE h.archived_at IS NULL'}
      ORDER BY h.sort_order ASC, h.created_at ASC
    ''');
    return rows.map((row) {
      return Habit.fromRows(
        habit: row,
        schedule: row,
        target: row,
      );
    }).toList();
  }

  @override
  Future<Habit?> getHabit(String habitId) async {
    final db = await _database.instance;
    final rows = await db.rawQuery('''
      SELECT h.*, s.recurrence_type, s.start_date, s.end_date,
             s.selected_weekdays, s.excluded_weekdays, s.month_days, s.interval_days,
             t.number_target, t.timer_target_seconds
      FROM habits h
      INNER JOIN habit_schedules s ON s.habit_id = h.id
      LEFT JOIN habit_targets t ON t.habit_id = h.id
      WHERE h.id = ?
      LIMIT 1
    ''', <Object?>[habitId]);
    if (rows.isEmpty) {
      return null;
    }
    return Habit.fromRows(
      habit: rows.first,
      schedule: rows.first,
      target: rows.first,
    );
  }

  @override
  Future<List<HabitWithEntry>> getTodayHabits(
    DateTime now,
    AppSettings settings,
  ) async {
    final day = HabitClock.habitDay(now, resetMinutes: settings.resetMinutes);
    final dayKey = HabitClock.dayKey(now, resetMinutes: settings.resetMinutes);
    final habits = await getAllHabits();
    final scheduled = habits.where((habit) => habit.isScheduledOn(day)).toList();
    if (scheduled.isEmpty) {
      return const <HabitWithEntry>[];
    }

    final db = await _database.instance;
    final habitIds = scheduled.map((h) => h.id).toList();

    // Batch-fetch today's entries for all habits in one query.
    final entryRows = await db.query(
      'habit_entries',
      where: 'day = ? AND habit_id IN (${_placeholders(habitIds.length)})',
      whereArgs: <Object?>[dayKey, ...habitIds],
    );
    final entriesByHabitId = <String, HabitEntry>{};
    for (final row in entryRows) {
      final entry = HabitEntry.fromMap(row);
      entriesByHabitId[entry.habitId] = entry;
    }

    // Batch-fetch active timer sessions for all habits in one query.
    final timerRows = await db.query(
      'timer_sessions',
      where: 'is_active = 1 AND habit_id IN (${_placeholders(habitIds.length)})',
      whereArgs: habitIds,
    );
    final sessionsByHabitId = <String, TimerSession>{};
    for (final row in timerRows) {
      final session = TimerSession.fromMap(row);
      sessionsByHabitId[session.habitId] = session;
    }

    // Batch-fetch streak restoration data for all habits.
    final yearMonth = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    final restoreCountRows = await db.rawQuery(
      'SELECT habit_id, COUNT(*) as cnt FROM streak_restorations '
      'WHERE habit_id IN (${_placeholders(habitIds.length)}) AND restored_at LIKE ? '
      'GROUP BY habit_id',
      <Object?>[...habitIds, '$yearMonth%'],
    );
    final restoreCountByHabit = <String, int>{};
    for (final row in restoreCountRows) {
      restoreCountByHabit[row['habit_id'] as String] = row['cnt'] as int;
    }

    // Batch-fetch completed entry days for streak calculation.
    final streakRows = await db.rawQuery(
      'SELECT habit_id, day FROM habit_entries '
      'WHERE status = ? AND habit_id IN (${_placeholders(habitIds.length)})',
      <Object?>[HabitEntryStatus.completed.name, ...habitIds],
    );
    final completedDaysByHabit = <String, Set<String>>{};
    for (final row in streakRows) {
      final hid = row['habit_id'] as String;
      (completedDaysByHabit[hid] ??= <String>{}).add(row['day'] as String);
    }

    // Find the last scheduled day before today for restore-check.
    DateTime? findLastScheduledDay(Habit habit) {
      DateTime cursor = day.subtract(const Duration(days: 1));
      for (int i = 0; i < 30; i++) {
        if (habit.isScheduledOn(cursor)) {
          return cursor;
        }
        cursor = cursor.subtract(const Duration(days: 1));
      }
      return null;
    }

    // Batch-fetch restored days for all habits to check restore eligibility.
    final restoredDayRows = await db.query(
      'streak_restorations',
      where: 'habit_id IN (${_placeholders(habitIds.length)})',
      whereArgs: habitIds,
    );
    final restoredDaysByHabit = <String, Set<String>>{};
    for (final row in restoredDayRows) {
      final hid = row['habit_id'] as String;
      (restoredDaysByHabit[hid] ??= <String>{}).add(row['restored_day'] as String);
    }

    final visible = <HabitWithEntry>[];
    for (final habit in scheduled) {
      final entry = entriesByHabitId[habit.id];
      final completedDays = completedDaysByHabit[habit.id] ?? const <String>{};
      final streak = _calculateStreakFromDays(habit, day, completedDays);
      final activeSession = sessionsByHabitId[habit.id];
      final savedSeconds = entry?.timerSeconds ?? 0;
      final activeSeconds = activeSession?.elapsedSecondsAt(now) ?? 0;
      final canRestore = _canRestoreStreakBatched(
        habit: habit,
        now: now,
        settings: settings,
        completedDays: completedDays,
        restoredDays: restoredDaysByHabit[habit.id] ?? const <String>{},
        monthlyCount: restoreCountByHabit[habit.id] ?? 0,
        findLastScheduledDay: findLastScheduledDay,
      );
      visible.add(
        HabitWithEntry(
          habit: habit,
          entry: entry,
          streak: streak,
          activeTimerSeconds: activeSeconds,
          savedTimerSeconds: savedSeconds,
          timerIsRunning: activeSession?.isActive ?? false,
          timerIsPaused: activeSession?.isPaused ?? false,
          canRestore: canRestore,
        ),
      );
    }
    return visible;
  }

  /// Pure in-memory streak calculation using pre-fetched completed days.
  int _calculateStreakFromDays(
    Habit habit,
    DateTime fromDay,
    Set<String> completedDays,
  ) {
    var streak = 0;
    var cursor = DateTime(fromDay.year, fromDay.month, fromDay.day);
    for (var checked = 0; checked < 730; checked++) {
      if (!habit.schedule.isScheduledOn(cursor)) {
        cursor = cursor.subtract(const Duration(days: 1));
        continue;
      }
      if (!completedDays.contains(HabitClock.dayKey(cursor))) {
        break;
      }
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  /// In-memory restore eligibility check using pre-fetched data.
  bool _canRestoreStreakBatched({
    required Habit habit,
    required DateTime now,
    required AppSettings settings,
    required Set<String> completedDays,
    required Set<String> restoredDays,
    required int monthlyCount,
    required DateTime? Function(Habit) findLastScheduledDay,
  }) {
    final lastScheduledDay = findLastScheduledDay(habit);
    if (lastScheduledDay == null) return false;
    final lastDayKey = HabitClock.dayKey(lastScheduledDay);

    // Check 24 hours grace period from the reset boundary of the missed day.
    final resetBoundary = HabitClock.resetBoundaryAfterDay(lastDayKey, settings.resetMinutes);
    if (now.isBefore(resetBoundary) || now.isAfter(resetBoundary.add(const Duration(hours: 24)))) {
      return false;
    }

    // Check if that day was already completed.
    if (completedDays.contains(lastDayKey)) {
      return false;
    }

    // Check if that day has already been restored.
    if (restoredDays.contains(lastDayKey)) {
      return false;
    }

    // Monthly limit check.
    if (monthlyCount >= 2) {
      return false;
    }

    return true;
  }

  @override
  Future<String> saveHabit(Habit habit) async {
    final db = await _database.instance;
    final revisionId = _uuid.v7();
    await db.transaction((txn) async {
      await txn.insert(
        'habits',
        habit.toHabitMap(),
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
      await txn.update(
        'habits',
        habit.toHabitMap(),
        where: 'id = ?',
        whereArgs: <Object?>[habit.id],
      );
      await txn.insert(
        'habit_schedules',
        habit.schedule.toMap(habit.id),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await txn.insert(
        'habit_targets',
        habit.toTargetMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await txn.insert(
        'habit_revisions',
        habit.toRevisionMap(revisionId, DateTime.now()),
      );
    });
    onChanged?.call();
    return revisionId;
  }

  @override
  Future<void> archiveHabit(String habitId) async {
    final db = await _database.instance;
    await db.update(
      'habits',
      <String, Object?>{
        'archived_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: <Object?>[habitId],
    );
    onChanged?.call();
  }

  @override
  Future<void> restoreHabit(String habitId) async {
    final db = await _database.instance;
    await db.update(
      'habits',
      <String, Object?>{
        'archived_at': null,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: <Object?>[habitId],
    );
    onChanged?.call();
  }

  @override
  Future<void> deleteHabit(String habitId) async {
    final db = await _database.instance;
    await db.delete('habits', where: 'id = ?', whereArgs: <Object?>[habitId]);
    onChanged?.call();
  }

  @override
  Future<HabitEntry?> getEntry(String habitId, String day) async {
    final db = await _database.instance;
    final rows = await db.query(
      'habit_entries',
      where: 'habit_id = ? AND day = ?',
      whereArgs: <Object?>[habitId, day],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return HabitEntry.fromMap(rows.first);
  }

  @override
  Future<void> upsertEntry(HabitEntry entry) async {
    final db = await _database.instance;
    await db.insert(
      'habit_entries',
      entry.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    onChanged?.call();
  }

  @override
  Future<void> toggleCheckbox(Habit habit, String day) async {
    final existing = await getEntry(habit.id, day);
    final now = DateTime.now();
    final revisionId =
        existing?.habitRevisionId ?? await latestRevisionId(habit.id);
    final completed = existing?.isCompleted ?? false;
    final next =
        (existing ??
                HabitEntry.empty(
                  id: _uuid.v7(),
                  habitId: habit.id,
                  day: day,
                  revisionId: revisionId,
                  now: now,
                ))
            .copyWith(
              status: completed
                  ? HabitEntryStatus.pending
                  : HabitEntryStatus.completed,
              completedAt: completed ? null : now,
              updatedAt: now,
              clearCompletedAt: completed,
            );
    await upsertEntry(next);
  }

  @override
  Future<void> adjustNumber(Habit habit, String day, int delta) async {
    final existing = await getEntry(habit.id, day);
    final now = DateTime.now();
    final revisionId =
        existing?.habitRevisionId ?? await latestRevisionId(habit.id);
    final base =
        existing ??
        HabitEntry.empty(
          id: _uuid.v7(),
          habitId: habit.id,
          day: day,
          revisionId: revisionId,
          now: now,
        );
    final nextValue = (base.numberValue + delta).clamp(0, 999999).toInt();
    final isComplete = nextValue >= (habit.numberTarget ?? 1);
    await upsertEntry(
      base.copyWith(
        numberValue: nextValue,
        status: isComplete
            ? HabitEntryStatus.completed
            : HabitEntryStatus.pending,
        completedAt: isComplete ? base.completedAt ?? now : null,
        updatedAt: now,
        clearCompletedAt: !isComplete,
      ),
    );
  }

  @override
  Future<void> setTimerSeconds(
    Habit habit,
    String day,
    int seconds, {
    bool preserveCompletion = true,
  }) async {
    final existing = await getEntry(habit.id, day);
    final now = DateTime.now();
    final revisionId =
        existing?.habitRevisionId ?? await latestRevisionId(habit.id);
    final base =
        existing ??
        HabitEntry.empty(
          id: _uuid.v7(),
          habitId: habit.id,
          day: day,
          revisionId: revisionId,
          now: now,
        );
    final target = habit.timerTargetSeconds ?? 1;
    final isComplete =
        seconds >= target || (preserveCompletion && base.isCompleted);
    await upsertEntry(
      base.copyWith(
        timerSeconds: seconds,
        status: isComplete
            ? HabitEntryStatus.completed
            : HabitEntryStatus.pending,
        completedAt: isComplete ? base.completedAt ?? now : null,
        updatedAt: now,
        clearCompletedAt: !isComplete,
      ),
    );
  }

  @override
  Future<void> markTimerCompleted(
    Habit habit,
    String day,
    DateTime completedAt,
  ) async {
    final existing = await getEntry(habit.id, day);
    final revisionId =
        existing?.habitRevisionId ?? await latestRevisionId(habit.id);
    final base =
        existing ??
        HabitEntry.empty(
          id: _uuid.v7(),
          habitId: habit.id,
          day: day,
          revisionId: revisionId,
          now: completedAt,
        );
    await upsertEntry(
      base.copyWith(
        status: HabitEntryStatus.completed,
        completedAt: base.completedAt ?? completedAt,
        updatedAt: completedAt,
      ),
    );
  }

  @override
  Future<int> calculateStreak(Habit habit, DateTime fromDay) async {
    final db = await _database.instance;
    final rows = await db.query(
      'habit_entries',
      columns: <String>['day'],
      where: 'habit_id = ? AND status = ?',
      whereArgs: <Object?>[habit.id, HabitEntryStatus.completed.name],
    );
    final completedDays = rows.map((row) => row['day'] as String).toSet();
    return _calculateStreakFromDays(habit, fromDay, completedDays);
  }

  @override
  Future<String?> latestRevisionId(String habitId) async {
    final db = await _database.instance;
    final rows = await db.query(
      'habit_revisions',
      columns: <String>['id'],
      where: 'habit_id = ?',
      whereArgs: <Object?>[habitId],
      orderBy: 'created_at DESC',
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['id'] as String;
  }

  @override
  Future<TimerSession?> getActiveTimerSession(String habitId) async {
    final db = await _database.instance;
    final rows = await db.query(
      'timer_sessions',
      where: 'habit_id = ? AND is_active = 1',
      whereArgs: <Object?>[habitId],
      orderBy: 'started_at DESC',
      limit: 1,
    );
    return rows.isEmpty ? null : TimerSession.fromMap(rows.first);
  }

  @override
  Future<List<TimerSession>> getActiveTimerSessions() async {
    final db = await _database.instance;
    final rows = await db.query(
      'timer_sessions',
      where: 'is_active = 1',
      orderBy: 'started_at ASC',
    );
    return rows.map(TimerSession.fromMap).toList();
  }

  @override
  Future<List<TimerSession>> getTimerSessions({
    String? habitId,
    String? day,
    DateTime? from,
    DateTime? to,
  }) async {
    final db = await _database.instance;
    final where = <String>[];
    final args = <Object?>[];
    if (habitId != null) {
      where.add('habit_id = ?');
      args.add(habitId);
    }
    if (day != null) {
      where.add('day = ?');
      args.add(day);
    }
    if (from != null) {
      where.add('started_at >= ?');
      args.add(from.toIso8601String());
    }
    if (to != null) {
      where.add('started_at < ?');
      args.add(to.toIso8601String());
    }
    final rows = await db.query(
      'timer_sessions',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'started_at DESC',
    );
    return rows.map(TimerSession.fromMap).toList();
  }

  @override
  Future<void> saveTimerSession(TimerSession session) async {
    final db = await _database.instance;
    await db.insert(
      'timer_sessions',
      session.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    onChanged?.call();
  }

  @override
  Future<bool> canRestoreStreak(String habitId, DateTime now, AppSettings settings) async {
    final db = await _database.instance;
    final habit = await getHabit(habitId);
    if (habit == null) return false;
    
    final day = HabitClock.habitDay(now, resetMinutes: settings.resetMinutes);
    final lastScheduledDay = _findLastScheduledDay(habit, day);
    if (lastScheduledDay == null) return false;
    final lastDayKey = HabitClock.dayKey(lastScheduledDay);
    
    // Check 24 hours grace period from the reset boundary of the missed day
    final resetBoundary = HabitClock.resetBoundaryAfterDay(lastDayKey, settings.resetMinutes);
    if (now.isBefore(resetBoundary) || now.isAfter(resetBoundary.add(const Duration(hours: 24)))) {
      return false;
    }
    
    // 2. Check if that day was completed
    final entry = await getEntry(habitId, lastDayKey);
    if (entry != null && entry.isCompleted) {
      return false; // Already completed, no miss to restore!
    }
    
    // 3. Check if that day has already been restored
    final restoredRows = await db.query(
      'streak_restorations',
      where: 'habit_id = ? AND restored_day = ?',
      whereArgs: <Object?>[habitId, lastDayKey],
      limit: 1,
    );
    if (restoredRows.isNotEmpty) {
      return false; // Already restored
    }
    
    // 4. Check monthly limit (max 2 per calendar month)
    final yearMonth = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    final countRows = await db.rawQuery(
      'SELECT COUNT(*) as count FROM streak_restorations '
      'WHERE habit_id = ? AND restored_at LIKE ?',
      <Object?>[habitId, '$yearMonth%'],
    );
    final count = Sqflite.firstIntValue(countRows) ?? 0;
    if (count >= 2) {
      return false; // Limit reached
    }
    
    return true;
  }

  @override
  Future<void> restoreStreak(String habitId, DateTime now, AppSettings settings) async {
    final day = HabitClock.habitDay(now, resetMinutes: settings.resetMinutes);
    
    final habit = await getHabit(habitId);
    if (habit == null) return;
    
    final lastScheduledDay = _findLastScheduledDay(habit, day);
    if (lastScheduledDay == null) return;
    final lastDayKey = HabitClock.dayKey(lastScheduledDay);
    
    final canRestore = await canRestoreStreak(habitId, now, settings);
    if (!canRestore) return;
    
    final db = await _database.instance;
    final nowStr = now.toIso8601String();
    
    final revisionId = await latestRevisionId(habitId) ?? '';
    
    await db.transaction((txn) async {
      await txn.insert('streak_restorations', <String, Object?>{
        'habit_id': habitId,
        'restored_day': lastDayKey,
        'restored_at': nowStr,
      });
      
      await txn.insert(
        'habit_entries',
        <String, Object?>{
          'id': _uuid.v7(),
          'habit_id': habitId,
          'habit_revision_id': revisionId,
          'day': lastDayKey,
          'status': HabitEntryStatus.completed.name,
          'number_value': habit.type == HabitType.number ? (habit.numberTarget ?? 1) : 0,
          'timer_seconds': habit.type == HabitType.timer ? (habit.timerTargetSeconds ?? 1) : 0,
          'completed_at': nowStr,
          'created_at': nowStr,
          'updated_at': nowStr,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
    
    onChanged?.call();
  }

  /// Find the most recent scheduled day before the given day.
  static DateTime? _findLastScheduledDay(Habit habit, DateTime day) {
    DateTime cursor = day.subtract(const Duration(days: 1));
    for (int i = 0; i < 30; i++) {
      if (habit.isScheduledOn(cursor)) {
        return cursor;
      }
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return null;
  }

  static String _placeholders(int count) =>
      List<String>.filled(count, '?').join(', ');
}
