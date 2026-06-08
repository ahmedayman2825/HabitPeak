import 'package:uuid/uuid.dart';

import '../features/habits/data/habit_repository.dart';
import '../features/habits/domain/habit.dart';
import '../features/habits/domain/habit_entry.dart';
import '../features/habits/domain/recurrence_rule.dart';

class MockDataSeeder {
  MockDataSeeder(this._habits);

  final HabitRepository _habits;
  final Uuid _uuid = const Uuid();

  Future<void> seed() async {
    final now = DateTime.now();
    final habits = <Habit>[
      Habit(
        id: _uuid.v7(),
        name: 'Read 20 pages',
        type: HabitType.number,
        schedule: RecurrenceRule.daily(excludedWeekdays: const <int>[7]),
        createdAt: now,
        updatedAt: now,
        numberTarget: 20,
      ),
      Habit(
        id: _uuid.v7(),
        name: 'Study deep work',
        type: HabitType.timer,
        schedule: const RecurrenceRule(
          type: RecurrenceType.weekly,
          selectedWeekdays: <int>[1, 2, 3, 4, 5],
        ),
        createdAt: now,
        updatedAt: now,
        timerTargetSeconds: const Duration(hours: 2).inSeconds,
      ),
      Habit(
        id: _uuid.v7(),
        name: 'Evening review',
        type: HabitType.checkbox,
        schedule: RecurrenceRule.daily(),
        createdAt: now,
        updatedAt: now,
      ),
    ];

    for (final habit in habits) {
      final revisionId = await _habits.saveHabit(habit);
      for (var offset = 1; offset <= 10; offset++) {
        final day = now.subtract(Duration(days: offset));
        if (!habit.schedule.isScheduledOn(day)) {
          continue;
        }
        final key =
            '${day.year.toString().padLeft(4, '0')}-'
            '${day.month.toString().padLeft(2, '0')}-'
            '${day.day.toString().padLeft(2, '0')}';
        final completed = offset % 4 != 0;
        await _habits.upsertEntry(
          HabitEntry(
            id: _uuid.v7(),
            habitId: habit.id,
            habitRevisionId: revisionId,
            day: key,
            status: completed
                ? HabitEntryStatus.completed
                : HabitEntryStatus.missed,
            numberValue: habit.type == HabitType.number && completed ? 20 : 0,
            timerSeconds: habit.type == HabitType.timer && completed
                ? const Duration(minutes: 95).inSeconds + offset * 60
                : 0,
            completedAt: completed ? day.add(const Duration(hours: 20)) : null,
            createdAt: day,
            updatedAt: day,
          ),
        );
      }
    }
  }
}
