import 'dart:convert';

import 'package:home_widget/home_widget.dart';

import '../../../core/database/app_database.dart';
import '../../../core/utils/habit_clock.dart';
import '../../habits/data/local_habit_repository.dart';
import '../../habits/domain/habit.dart';
import '../../habits/domain/habit_with_entry.dart';
import '../../settings/data/settings_repository.dart';
import '../../settings/domain/app_settings.dart';
import '../../notifications/data/notification_service.dart';

class HabitWidgetService {
  HabitWidgetService();

  static const String androidWidgetName = 'HabitWidgetReceiver';

  static void registerBackgroundCallback() {
    HomeWidget.registerInteractivityCallback(habitWidgetBackgroundCallback);
  }

  Future<void> updateTodayWidget(
    List<HabitWithEntry> items,
    AppSettings settings,
  ) async {
    final payload = items.take(6).map((item) {
      return <String, Object?>{
        'id': item.habit.id,
        'name': item.habit.name,
        'type': item.habit.type.name,
        'streak': item.streak,
        'progress': item.progress,
        'completed': item.isComplete,
      };
    }).toList();
    final completed = items.where((item) => item.isComplete).length;
    await HomeWidget.saveWidgetData<String>('habits_json', jsonEncode(payload));
    await HomeWidget.saveWidgetData<int>('habit_count', items.length);
    await HomeWidget.saveWidgetData<int>('completed_count', completed);
    await HomeWidget.saveWidgetData<String>(
      'reset_time',
      settings.resetTimeLabel,
    );
    await HomeWidget.updateWidget(androidName: androidWidgetName);
  }
}

@pragma('vm:entry-point')
Future<void> habitWidgetBackgroundCallback(Uri? uri) async {
  if (uri == null || uri.host != 'complete') {
    return;
  }
  final habitId = uri.queryParameters['habitId'];
  if (habitId == null || habitId.isEmpty) {
    return;
  }
  final database = AppDatabase();
  try {
    final settings = await SettingsRepository().load();
    final repository = LocalHabitRepository(database);
    final habit = await repository.getHabit(habitId);
    if (habit == null) {
      return;
    }
    final day = HabitClock.dayKey(
      DateTime.now(),
      resetMinutes: settings.resetMinutes,
    );
    switch (habit.type) {
      case HabitType.checkbox:
        await repository.toggleCheckbox(habit, day);
        break;
      case HabitType.number:
        await repository.adjustNumber(habit, day, 1);
        break;
      case HabitType.timer:
        await repository.setTimerSeconds(
          habit,
          day,
          habit.timerTargetSeconds ?? 0,
        );
        break;
    }
    final items = await repository.getTodayHabits(DateTime.now(), settings);
    await HabitWidgetService().updateTodayWidget(items, settings);

    final completed = items.where((item) => item.isComplete).length;
    final missed = items.length - completed;
    final todayKey = HabitClock.dayKey(DateTime.now(), resetMinutes: settings.resetMinutes);
    final resetTime = HabitClock.resetBoundaryAfterDay(todayKey, settings.resetMinutes);
    await NotificationService().scheduleResetSummary(
      completed: completed,
      missed: missed,
      resetTime: resetTime,
    );
  } finally {
    await database.close();
  }
}
