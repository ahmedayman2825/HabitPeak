import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_settings_controller.dart';
import '../features/analytics/domain/analytics_summary.dart';
import '../features/habits/domain/habit.dart';
import '../core/database/app_database.dart';
import '../features/ai/data/local_insight_service.dart';
import '../features/analytics/data/analytics_repository.dart';
import '../features/backup/data/backup_service.dart';
import '../features/habits/data/habit_repository.dart';
import '../features/habits/data/local_habit_repository.dart';
import '../features/notifications/data/notification_service.dart';
import '../features/settings/data/settings_repository.dart';
import '../features/settings/data/data_management_service.dart';
import '../features/timer/data/timer_engine.dart';
import '../features/widgets/data/habit_widget_service.dart';

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  throw UnimplementedError('AppDatabase must be overridden at startup.');
});

final notificationServiceProvider = Provider<NotificationService>((ref) {
  throw UnimplementedError(
    'NotificationService must be overridden at startup.',
  );
});

final appSettingsControllerProvider = Provider<AppSettingsController>((ref) {
  throw UnimplementedError(
    'AppSettingsController must be overridden at startup.',
  );
});

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepository();
});

class DatabaseVersion extends Notifier<int> {
  @override
  int build() => 0;

  void increment() {
    state = state + 1;
  }
}

final databaseVersionProvider = NotifierProvider<DatabaseVersion, int>(DatabaseVersion.new);

final habitRepositoryProvider = Provider<HabitRepository>((ref) {
  return LocalHabitRepository(
    ref.watch(appDatabaseProvider),
    onChanged: () {
      ref.read(databaseVersionProvider.notifier).increment();
    },
  );
});

final timerEngineProvider = Provider<TimerEngine>((ref) {
  return TimerEngine(
    habits: ref.watch(habitRepositoryProvider),
    notifications: ref.watch(notificationServiceProvider),
  );
});

final analyticsRepositoryProvider = Provider<AnalyticsRepository>((ref) {
  return AnalyticsRepository(
    database: ref.watch(appDatabaseProvider),
    habits: ref.watch(habitRepositoryProvider),
  );
});

final localInsightServiceProvider = Provider<LocalInsightService>((ref) {
  return LocalInsightService();
});

final backupServiceProvider = Provider<BackupService>((ref) {
  return BackupService(ref.watch(appDatabaseProvider));
});

final dataManagementServiceProvider = Provider<DataManagementService>((ref) {
  return DataManagementService(ref.watch(appDatabaseProvider));
});

final habitWidgetServiceProvider = Provider<HabitWidgetService>((ref) {
  return HabitWidgetService();
});

final analyticsSummaryProvider = FutureProvider.family<AnalyticsSummary, AnalyticsWindow>((ref, window) {
  ref.watch(databaseVersionProvider);
  final repository = ref.watch(analyticsRepositoryProvider);
  final settings = ref.watch(appSettingsControllerProvider).settings;
  return repository.loadSummary(
    window: window,
    now: DateTime.now(),
    settings: settings,
  );
});

final habitAnalyticsSummaryProvider = FutureProvider.family<HabitAnalyticsSummary, Habit>((ref, habit) {
  ref.watch(databaseVersionProvider);
  final repository = ref.watch(analyticsRepositoryProvider);
  final settings = ref.watch(appSettingsControllerProvider).settings;
  return repository.loadHabitSummary(
    habit: habit,
    now: DateTime.now(),
    settings: settings,
  );
});
