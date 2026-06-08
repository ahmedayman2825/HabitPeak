import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../../core/utils/duration_format.dart';

class NotificationService {
  NotificationService();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }
    tz_data.initializeTimeZones();
    try {
      final tzInfo = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(tzInfo.identifier));
    } catch (_) {
      try {
        tz.setLocalLocation(tz.getLocation('Etc/UTC'));
      } catch (_) {
        if (tz.timeZoneDatabase.locations.isNotEmpty) {
          tz.setLocalLocation(tz.timeZoneDatabase.locations.values.first);
        }
      }
    }
    const android = AndroidInitializationSettings(
      '@drawable/ic_stat_openhabit',
    );
    const darwin = DarwinInitializationSettings();
    const settings = InitializationSettings(android: android, iOS: darwin);
    await _plugin.initialize(settings: settings);
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
    _initialized = true;
  }

  Future<void> showReminder(String habitName) async {
    await _show(
      id: habitName.hashCode,
      title: 'Habit reminder',
      body: 'Did you complete $habitName?',
    );
  }

  Future<void> showMissedHabit(String habitName) async {
    await _show(
      id: habitName.hashCode ^ 0x42,
      title: 'Missed habit',
      body: 'You missed $habitName today.',
    );
  }

  Future<void> showEndOfDaySummary({
    required String label,
    required Duration tracked,
  }) async {
    await _show(
      id: label.hashCode ^ 0x84,
      title: 'Daily summary',
      body: 'You $label ${DurationFormat.compact(tracked)} today.',
    );
  }

  Future<void> scheduleDailySummary({
    required int id,
    required DateTime at,
  }) async {
    await initialize();
    await _plugin.zonedSchedule(
      id: id,
      title: 'Daily habit summary',
      body: 'Review what you completed today.',
      scheduledDate: tz.TZDateTime.from(at, tz.local),
      notificationDetails: _details(),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> scheduleResetSummary({
    required int completed,
    required int missed,
    required DateTime resetTime,
  }) async {
    await initialize();
    await cancel(999);

    if (resetTime.isBefore(DateTime.now())) {
      return;
    }

    final android = AndroidNotificationDetails(
      'day_summary',
      'Day Summary',
      channelDescription: 'Daily summary notifications after day resets',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    );
    const darwin = DarwinNotificationDetails();
    final details = NotificationDetails(android: android, iOS: darwin);

    final String body;
    if (completed == 0 && missed == 0) {
      body = 'No habits were scheduled today.';
    } else {
      body = 'You did $completed today, missed $missed';
    }

    await _plugin.zonedSchedule(
      id: 999,
      title: 'Daily Summary',
      body: body,
      scheduledDate: tz.TZDateTime.from(resetTime, tz.local),
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  Future<void> cancel(int id) => _plugin.cancel(id: id);

  Future<void> _show({
    required int id,
    required String title,
    required String body,
  }) async {
    await initialize();
    await _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: _details(),
    );
  }

  NotificationDetails _details() {
    const android = AndroidNotificationDetails(
      'openhabit_local',
      'OpenHabit reminders',
      channelDescription: 'Habit reminders and daily summaries',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    );
    const darwin = DarwinNotificationDetails();
    return const NotificationDetails(android: android, iOS: darwin);
  }
}
