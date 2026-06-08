import 'habit.dart';
import 'habit_entry.dart';

class HabitWithEntry {
  const HabitWithEntry({
    required this.habit,
    required this.streak,
    this.entry,
    this.activeTimerSeconds = 0,
    this.savedTimerSeconds = 0,
    this.timerIsRunning = false,
    this.timerIsPaused = false,
    this.canRestore = false,
  });

  final Habit habit;
  final HabitEntry? entry;
  final int streak;
  final int activeTimerSeconds;
  final int savedTimerSeconds;
  final bool timerIsRunning;
  final bool timerIsPaused;
  final bool canRestore;

  bool get isComplete => entry?.isCompleted ?? false;

  int get value {
    if (habit.type == HabitType.timer) {
      return activeTimerSeconds;
    }
    return entry?.numberValue ?? 0;
  }

  int get timerProgressSeconds => savedTimerSeconds + activeTimerSeconds;

  int get target {
    switch (habit.type) {
      case HabitType.checkbox:
        return 1;
      case HabitType.number:
        return habit.numberTarget ?? 1;
      case HabitType.timer:
        return habit.timerTargetSeconds ?? 1;
    }
  }

  double get progress {
    if (habit.type == HabitType.checkbox) {
      return isComplete ? 1 : 0;
    }
    final targetValue = target <= 0 ? 1 : target;
    final progressValue = habit.type == HabitType.timer
        ? timerProgressSeconds
        : value;
    return (progressValue / targetValue).clamp(0, 1).toDouble();
  }
}
