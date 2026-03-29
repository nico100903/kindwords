import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:kindwords/services/quote_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz_data;

/// Abstract interface for notification services.
///
/// Allows mocking in tests without tight coupling to implementation details.
abstract class NotificationServiceBase {
  Future<({bool enabled, int hour, int minute})> loadSettings();
  Future<void> scheduleDailyNotification(int hour, int minute);
  Future<void> cancelNotification();

  /// Re-schedules notification from saved settings. Called by boot receiver.
  Future<void> rescheduleFromSavedSettings();
}

/// Handles daily scheduled notifications using [flutter_local_notifications].
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

    // Set tz.local to the device's actual IANA timezone so zonedSchedule fires
    // at the correct local time (e.g. 08:00 Asia/Manila, not 08:00 UTC).
    final String localTimezoneName = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(localTimezoneName));

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    await _plugin.initialize(initSettings);
    await _createNotificationChannel();

    // Request POST_NOTIFICATIONS permission once at init (Android 13+ / API 33+).
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.requestNotificationsPermission();
  }

  /// Schedules a daily notification at [hour]:[minute].
  ///
  /// Cancels any existing scheduled notification before rescheduling.
  /// Persists the chosen time to [SharedPreferences].
  ///
  /// Checks exact-alarm permission before scheduling (required on API 31+).
  /// Returns early if permission is not granted, directing the user to grant
  /// permission in system settings before the notification can be scheduled.
  @override
  Future<void> scheduleDailyNotification(int hour, int minute) async {
    await cancelNotification();

    // Guard: check exact-alarm permission before every zonedSchedule call.
    // Permission can be revoked at any time via Battery settings (API 31+).
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final canSchedule =
        await androidPlugin?.canScheduleExactNotifications() ?? false;
    if (!canSchedule) {
      await androidPlugin?.requestExactAlarmsPermission();
      return;
    }

    final quote = await _quoteService.getRandomQuote();
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
  @override
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

    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(channel);
  }
}
