import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'app/app_settings_controller.dart';
import 'app/providers.dart';
import 'core/database/app_database.dart';
import 'features/notifications/data/notification_service.dart';
import 'features/settings/data/settings_repository.dart';
import 'features/settings/domain/app_settings.dart';
import 'features/widgets/data/habit_widget_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final database = AppDatabase();
  final notifications = NotificationService();
  final settingsRepository = SettingsRepository();
  final settingsController = AppSettingsController(
    repository: settingsRepository,
    initialSettings: AppSettings.defaults(),
  );

  HabitWidgetService.registerBackgroundCallback();

  runApp(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        notificationServiceProvider.overrideWithValue(notifications),
        appSettingsControllerProvider.overrideWithValue(settingsController),
      ],
      child: const HabitPeakApp(),
    ),
  );

  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(_finishStartup(database, notifications, settingsController));
  });
}

Future<void> _finishStartup(
  AppDatabase database,
  NotificationService notifications,
  AppSettingsController settingsController,
) async {
  try {
    await settingsController.load();
    await Future.wait<void>(<Future<void>>[
      database.instance.then((_) {}),
      notifications.initialize(),
    ]);
  } catch (_) {
    // Startup fallbacks keep the app usable even if a platform service is slow.
  }
}
