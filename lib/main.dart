import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'app/app_settings_controller.dart';
import 'app/providers.dart';
import 'core/database/app_database.dart';
import 'features/notifications/data/notification_service.dart';
import 'features/settings/data/settings_repository.dart';
import 'features/widgets/data/habit_widget_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final database = AppDatabase();
  await database.instance;

  final notifications = NotificationService();
  await notifications.initialize();

  final settingsRepository = SettingsRepository();
  final settings = await settingsRepository.load();
  final settingsController = AppSettingsController(
    repository: settingsRepository,
    initialSettings: settings,
  );

  HabitWidgetService.registerBackgroundCallback();

  runApp(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        notificationServiceProvider.overrideWithValue(notifications),
        appSettingsControllerProvider.overrideWithValue(settingsController),
      ],
      child: const OpenHabitApp(),
    ),
  );
}
