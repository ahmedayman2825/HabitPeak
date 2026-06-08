import 'package:uuid/uuid.dart';

import '../../../core/utils/habit_clock.dart';
import '../../habits/data/habit_repository.dart';
import '../../habits/domain/habit.dart';
import '../../notifications/data/notification_service.dart';
import '../../settings/domain/app_settings.dart';
import '../domain/timer_session.dart';

class TimerEngine {
  TimerEngine({
    required HabitRepository habits,
    required NotificationService notifications,
  }) : _habits = habits,
       _notifications = notifications;

  final HabitRepository _habits;
  final NotificationService _notifications;
  final Uuid _uuid = const Uuid();

  Future<TimerSession> start(Habit habit, AppSettings settings) async {
    final now = DateTime.now();
    final existing = await _habits.getActiveTimerSession(habit.id);
    if (existing != null) {
      if (existing.isPaused) {
        return resume(existing, settings);
      }
      return existing;
    }
    final session = TimerSession(
      id: _uuid.v7(),
      habitId: habit.id,
      day: HabitClock.dayKey(now, resetMinutes: settings.resetMinutes),
      startedAt: now,
      lastResumedAt: now,
      accumulatedSeconds: 0,
      isActive: true,
      isPaused: false,
    );
    await _habits.saveTimerSession(session);
    return session;
  }

  Future<TimerSession> pause(TimerSession session) async {
    final now = DateTime.now();
    final paused = _pausedAt(session, now);
    await _habits.saveTimerSession(paused);
    return paused;
  }

  Future<TimerSession> resume(
    TimerSession session,
    AppSettings settings,
  ) async {
    final now = DateTime.now();
    final currentDay = HabitClock.dayKey(
      now,
      resetMinutes: settings.resetMinutes,
    );
    if (session.day != currentDay) {
      return session;
    }
    final resumed = session.copyWith(
      lastResumedAt: now,
      isActive: true,
      isPaused: false,
      clearPausedAt: true,
    );
    await _habits.saveTimerSession(resumed);
    return resumed;
  }

  Future<({TimerSession stoppedSession, int elapsedSeconds})> stopAndReset(
    TimerSession session,
  ) async {
    final now = DateTime.now();
    final elapsed = session.elapsedSecondsAt(now).clamp(0, 1 << 31).toInt();
    final stopped = session.copyWith(
      accumulatedSeconds: 0,
      endedAt: now,
      isActive: false,
      isPaused: true,
      pausedAt: now,
      clearLastResumed: true,
    );
    await _habits.saveTimerSession(stopped);
    final habit = await _habits.getHabit(session.habitId);
    if (habit != null) {
      await _habits.setTimerSeconds(
        habit,
        session.day,
        await _savedDaySeconds(session.habitId, session.day),
        preserveCompletion: false,
      );
    }
    return (stoppedSession: stopped, elapsedSeconds: elapsed);
  }

  Future<void> saveStoppedTimeToDay(
    TimerSession stoppedSession,
    int elapsedSeconds,
  ) async {
    if (elapsedSeconds <= 0) {
      return;
    }
    final savedSession = stoppedSession.copyWith(
      accumulatedSeconds: elapsedSeconds,
    );
    await _habits.saveTimerSession(savedSession);
    final habit = await _habits.getHabit(stoppedSession.habitId);
    if (habit == null) {
      return;
    }
    await _habits.setTimerSeconds(
      habit,
      stoppedSession.day,
      await _savedDaySeconds(stoppedSession.habitId, stoppedSession.day),
      preserveCompletion: false,
    );
  }

  Future<void> reconcileActiveSessions(AppSettings settings) async {
    final sessions = await _habits.getActiveTimerSessions();
    for (final session in sessions) {
      final habit = await _habits.getHabit(session.habitId);
      if (habit == null || habit.type != HabitType.timer) {
        continue;
      }
      await _pauseIfDayReset(session, habit, settings);
      final refreshed = await _habits.getActiveTimerSession(session.habitId);
      if (refreshed == null || refreshed.isPaused) {
        continue;
      }
      await _completeIfTargetReached(refreshed, habit);
    }
  }

  Future<void> syncRunningSession(
    Habit habit,
    TimerSession session,
    AppSettings settings,
  ) async {
    await _pauseIfDayReset(session, habit, settings);
    final active = await _habits.getActiveTimerSession(habit.id);
    if (active == null || active.isPaused) {
      return;
    }
    await _completeIfTargetReached(active, habit);
    final dailySeconds =
        await _savedDaySeconds(habit.id, active.day) +
        active.elapsedSecondsAt(DateTime.now());
    await _habits.setTimerSeconds(
      habit,
      active.day,
      dailySeconds,
      preserveCompletion: false,
    );
  }

  Future<void> _completeIfTargetReached(
    TimerSession session,
    Habit habit,
  ) async {
    final target = habit.timerTargetSeconds ?? 0;
    if (target <= 0 || session.targetReachedAt != null) {
      return;
    }
    final now = DateTime.now();
    final dailySeconds =
        await _savedDaySeconds(habit.id, session.day) +
        session.elapsedSecondsAt(now);
    if (dailySeconds < target) {
      return;
    }
    await _habits.markTimerCompleted(habit, session.day, now);
    await _habits.saveTimerSession(session.copyWith(targetReachedAt: now));
  }

  Future<void> _pauseIfDayReset(
    TimerSession session,
    Habit habit,
    AppSettings settings,
  ) async {
    final now = DateTime.now();
    final currentDay = HabitClock.dayKey(
      now,
      resetMinutes: settings.resetMinutes,
    );
    if (session.day == currentDay || session.isPaused) {
      return;
    }
    final boundary = HabitClock.resetBoundaryAfterDay(
      session.day,
      settings.resetMinutes,
    );
    final elapsedAtBoundary = session.lastResumedAt == null
        ? session.accumulatedSeconds
        : session.accumulatedSeconds +
              boundary.difference(session.lastResumedAt!).inSeconds;
    final safeElapsed = elapsedAtBoundary.clamp(0, 1 << 31).toInt();
    final paused = session.copyWith(
      accumulatedSeconds: safeElapsed,
      pausedAt: boundary,
      isPaused: true,
      isActive: true,
      clearLastResumed: true,
    );
    await _habits.saveTimerSession(paused);
    final dailySeconds =
        await _savedDaySeconds(session.habitId, session.day) + safeElapsed;
    await _habits.setTimerSeconds(
      habit,
      session.day,
      dailySeconds,
      preserveCompletion: false,
    );
    await _notifications.showEndOfDaySummary(
      label: '${habit.name.toLowerCase()} for',
      tracked: Duration(seconds: safeElapsed),
    );
  }

  TimerSession _pausedAt(TimerSession session, DateTime at) {
    return session.copyWith(
      accumulatedSeconds: session.elapsedSecondsAt(at),
      pausedAt: at,
      isPaused: true,
      isActive: true,
      clearLastResumed: true,
    );
  }

  Future<int> _savedDaySeconds(String habitId, String day) async {
    final sessions = await _habits.getTimerSessions(habitId: habitId, day: day);
    return sessions
        .where((session) => !session.isActive && session.endedAt != null)
        .fold<int>(0, (sum, session) => sum + session.accumulatedSeconds);
  }
}
