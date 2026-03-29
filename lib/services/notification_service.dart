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
  Future<void> sendTestNotification();
  Future<void> scheduleTestInSeconds(int seconds);

  /// Re-schedules notification from saved settings. Called by boot receiver.
  Future<void> rescheduleFromSavedSettings();
}

/// Handles daily scheduled notifications using [flutter_local_notifications].
///
/// Android-specific notes:
/// - Requires SCHEDULE_EXACT_ALARM (API 31–32) or USE_EXACT_ALARM (API 33+)
/// - Notification channel: "kindwords_daily_v2" (IMPORTANCE_HIGH)
/// - Uses zonedSchedule with DateTimeComponents.time for daily repeat
/// - Channel v2 replaces v1 ("kindwords_daily") which was created with
///   IMPORTANCE_DEFAULT — Android locks channel importance after first creation
///   so a new channel ID is required to get heads-up + sound on delivery.
class NotificationService implements NotificationServiceBase {
  static const String _channelId = 'kindwords_daily_v2';
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

    // Remove the old v1 channel (created with IMPORTANCE_DEFAULT — Android
    // locks importance after first creation, so we migrate to v2 with HIGH).
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.deleteNotificationChannel('kindwords_daily');

    await _createNotificationChannel();

    // Request POST_NOTIFICATIONS permission once at init (Android 13+ / API 33+).
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
      importance: Importance.high,
      priority: Priority.high,
    );
    const details = NotificationDetails(android: androidDetails);

    await _plugin.zonedSchedule(
      _notificationId,
      'KindWords 💛',
      quote.text,
      scheduledTime,
      details,
      // alarmClock mode uses AlarmManager.setAlarmClock() — the strongest
      // scheduling guarantee on Android. Cannot be batched or deferred by OEM
      // battery management (including Honor/Huawei MagicOS). Shows a clock
      // icon in the status bar while the alarm is pending.
      androidScheduleMode: AndroidScheduleMode.alarmClock,
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

  /// Schedules a notification [seconds] from now using the exact same
  /// zonedSchedule + alarmClock path as the daily notification.
  ///
  /// Use this to verify scheduled delivery works independently of timing.
  @override
  Future<void> scheduleTestInSeconds(int seconds) async {
    final quote = await _quoteService.getRandomQuote();
    final scheduledTime =
        tz.TZDateTime.now(tz.local).add(Duration(seconds: seconds));

    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.high,
      priority: Priority.high,
    );

    await _plugin.zonedSchedule(
      9998,
      'KindWords Scheduled Test 💛',
      quote.text,
      scheduledTime,
      const NotificationDetails(android: androidDetails),
      androidScheduleMode: AndroidScheduleMode.alarmClock,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  /// Fires an immediate notification to verify the channel and permissions work.
  ///
  /// Useful for debugging on devices with aggressive battery management (e.g.
  /// Huawei/Honor MagicOS) where scheduled exact alarms may be suppressed.
  @override
  Future<void> sendTestNotification() async {
    final quote = await _quoteService.getRandomQuote();
    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.high,
      priority: Priority.high,
    );
    await _plugin.show(
      9999,
      'KindWords Test 💛',
      quote.text,
      const NotificationDetails(android: androidDetails),
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
      importance: Importance.high,
    );

    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(channel);
  }
}
