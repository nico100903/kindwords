import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'quote_service.dart';

/// Abstract interface for notification services.
///
/// Allows mocking in tests without tight coupling to implementation details.
abstract class NotificationServiceBase {
  Future<({bool enabled, int hour, int minute})> loadSettings();
  Future<void> scheduleDailyNotification(int hour, int minute);
  Future<void> cancelNotification();
}

/// Handles daily scheduled notifications using [flutter_local_notifications].
///
/// Wave 3 (Task 03.01) will implement full scheduling logic.
/// This stub exposes the correct interface and channel setup.
///
/// Android-specific notes:
/// - Requires SCHEDULE_EXACT_ALARM (API 31–32) or USE_EXACT_ALARM (API 33+)
/// - Notification channel: "kindwords_daily" (IMPORTANCE_DEFAULT)
/// - Uses zonedSchedule with DateTimeComponents.time for daily repeat
class NotificationService implements NotificationServiceBase {
  static const String _channelId = 'kindwords_daily';
  static const String _channelName = 'Daily Motivation';
  static const String _channelDesc = 'Daily motivational quote notification';
  static const int _notificationId = 1001;

  static const String _prefEnabled = 'notification_enabled';
  static const String _prefHour = 'notification_hour';
  static const String _prefMinute = 'notification_minute';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  final QuoteService _quoteService;

  NotificationService(this._quoteService);

  /// Initializes the notification plugin and timezone database.
  ///
  /// Must be called in [main()] before [runApp()].
  Future<void> initialize() async {
    tz_data.initializeTimeZones();

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    await _plugin.initialize(initSettings);
    await _createNotificationChannel();
  }

  /// Schedules a daily notification at [hour]:[minute].
  ///
  /// Cancels any existing scheduled notification before rescheduling.
  /// Persists the chosen time to [SharedPreferences].
  ///
  /// TODO (Wave 3, Task 03.01): Implement full scheduling logic.
  @override
  Future<void> scheduleDailyNotification(int hour, int minute) async {
    await cancelNotification();

    final quote = _quoteService.getRandomQuote();
    final scheduledTime = _nextInstanceOf(hour, minute);

    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    );
    const details = NotificationDetails(android: androidDetails);

    await _plugin.zonedSchedule(
      _notificationId,
      'KindWords 💛',
      quote.text,
      scheduledTime,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefEnabled, true);
    await prefs.setInt(_prefHour, hour);
    await prefs.setInt(_prefMinute, minute);

    // TODO: use a proper logger — removed debugPrint (R1.3)
  }

  /// Cancels the scheduled daily notification and marks it disabled.
  @override
  Future<void> cancelNotification() async {
    await _plugin.cancel(_notificationId);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefEnabled, false);
  }

  /// Loads saved notification settings from [SharedPreferences].
  ///
  /// Returns a record with {enabled, hour, minute} or defaults (disabled, 8:00).
  @override
  Future<({bool enabled, int hour, int minute})> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    return (
      enabled: prefs.getBool(_prefEnabled) ?? false,
      hour: prefs.getInt(_prefHour) ?? 8,
      minute: prefs.getInt(_prefMinute) ?? 0,
    );
  }

  /// Re-schedules the daily notification from saved settings.
  ///
  /// Called by the BootReceiver after device reboot.
  Future<void> rescheduleFromSavedSettings() async {
    final settings = await loadSettings();
    if (settings.enabled) {
      await scheduleDailyNotification(settings.hour, settings.minute);
    }
  }

  tz.TZDateTime _nextInstanceOf(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  Future<void> _createNotificationChannel() async {
    const channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDesc,
      importance: Importance.defaultImportance,
    );

    final androidPlugin =
        _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(channel);
  }
}
