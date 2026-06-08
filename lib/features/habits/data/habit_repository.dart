import '../domain/habit.dart';
import '../domain/habit_entry.dart';
import '../domain/habit_with_entry.dart';
import '../../../features/settings/domain/app_settings.dart';
import '../../../features/timer/domain/timer_session.dart';

abstract class HabitRepository {
  Future<List<Habit>> getAllHabits({bool includeArchived = false});

  Future<Habit?> getHabit(String habitId);

  Future<List<HabitWithEntry>> getTodayHabits(
    DateTime now,
    AppSettings settings,
  );

  Future<String> saveHabit(Habit habit);

  Future<void> archiveHabit(String habitId);

  Future<void> restoreHabit(String habitId);

  Future<void> deleteHabit(String habitId);

  Future<HabitEntry?> getEntry(String habitId, String day);

  Future<void> upsertEntry(HabitEntry entry);

  Future<void> toggleCheckbox(Habit habit, String day);

  Future<void> adjustNumber(Habit habit, String day, int delta);

  Future<void> setTimerSeconds(
    Habit habit,
    String day,
    int seconds, {
    bool preserveCompletion = true,
  });

  Future<void> markTimerCompleted(
    Habit habit,
    String day,
    DateTime completedAt,
  );

  Future<int> calculateStreak(Habit habit, DateTime fromDay);

  Future<String?> latestRevisionId(String habitId);

  Future<TimerSession?> getActiveTimerSession(String habitId);

  Future<List<TimerSession>> getActiveTimerSessions();

  Future<List<TimerSession>> getTimerSessions({
    String? habitId,
    String? day,
    DateTime? from,
    DateTime? to,
  });

  Future<void> saveTimerSession(TimerSession session);

  Future<bool> canRestoreStreak(String habitId, DateTime now, AppSettings settings);

  Future<void> restoreStreak(String habitId, DateTime now, AppSettings settings);
}
