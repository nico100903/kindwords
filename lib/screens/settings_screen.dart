import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../services/notification_service.dart';

/// Compile-time flag — set via `--dart-define=KINDWORDS_DEBUG_NOTIFICATIONS=true`.
///
/// When true, the Settings screen renders an additional "Notification Debug"
/// section with a "Send Test Notification" button and a configurable
/// "Schedule Test" trigger (with a live countdown timer).
///
/// The production default is always false; the section is tree-shaken out of
/// release builds.
// ignore: do_not_use_environment
const bool _kDebugNotifications = bool.fromEnvironment(
  'KINDWORDS_DEBUG_NOTIFICATIONS',
);

const _batteryChannel = MethodChannel('com.example.kindwords/battery');

/// Settings screen for notification configuration.
///
/// Task 03.01: Daily notification enable/disable toggle and time picker.
/// Settings persist via NotificationService (SharedPreferences internally).
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = false;
  int _notificationHour = 8;
  int _notificationMinute = 0;
  bool _isLoading = true;
  bool _isBatteryOptimized = false; // true = NOT exempted (bad)

  // Debug-only state — unused (and tree-shaken) when _kDebugNotifications is false.
  int _scheduleTestDelaySeconds = 15;
  int? _scheduledTestRemainingSeconds;
  Timer? _scheduledTestCountdownTimer;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _checkBatteryOptimization();
  }

  @override
  void dispose() {
    _scheduledTestCountdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkBatteryOptimization() async {
    try {
      final bool isIgnoring = await _batteryChannel
          .invokeMethod<bool>('isIgnoringBatteryOptimizations') ?? false;
      if (mounted) {
        setState(() {
          _isBatteryOptimized = !isIgnoring; // optimized = NOT exempted
        });
      }
    } catch (_) {
      // Non-Android platform or channel unavailable — ignore
    }
  }

  Future<void> _requestBatteryExemption() async {
    try {
      await _batteryChannel.invokeMethod('requestIgnoreBatteryOptimizations');
      // Re-check after returning from system settings
      await Future<void>.delayed(const Duration(milliseconds: 500));
      await _checkBatteryOptimization();
    } catch (_) {}
  }

  // ---------------------------------------------------------------------------
  // Debug helpers — only called when _kDebugNotifications is true.
  // Tree-shaken in release / non-debug builds.
  // ---------------------------------------------------------------------------

  Future<void> _sendTestNotification() async {
    final service = context.read<NotificationServiceBase>();
    await service.sendTestNotification();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Test notification sent — check your notification shade.',
          ),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  void _startScheduledTestCountdown(int seconds) {
    _scheduledTestCountdownTimer?.cancel();
    setState(() {
      _scheduledTestRemainingSeconds = seconds;
    });

    _scheduledTestCountdownTimer = Timer.periodic(
      const Duration(seconds: 1),
      (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }

        final nextValue = (_scheduledTestRemainingSeconds ?? 0) - 1;
        if (nextValue <= 0) {
          timer.cancel();
          setState(() {
            _scheduledTestRemainingSeconds = null;
          });
          return;
        }

        setState(() {
          _scheduledTestRemainingSeconds = nextValue;
        });
      },
    );
  }

  Future<void> _scheduleTestInSeconds() async {
    final service = context.read<NotificationServiceBase>();
    await service.scheduleTestInSeconds(_scheduleTestDelaySeconds);
    if (mounted) {
      _startScheduledTestCountdown(_scheduleTestDelaySeconds);
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Scheduled test: notification will fire in '
            '$_scheduleTestDelaySeconds seconds. Lock the screen now and wait.',
          ),
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  Future<void> _loadSettings() async {
    final service = context.read<NotificationServiceBase>();
    final settings = await service.loadSettings();

    if (mounted) {
      setState(() {
        _notificationsEnabled = settings.enabled;
        _notificationHour = settings.hour;
        _notificationMinute = settings.minute;
        _isLoading = false;
      });
    }
  }

  Future<void> _onToggleChanged(bool value) async {
    final notificationService = context.read<NotificationServiceBase>();

    if (value) {
      await notificationService.scheduleDailyNotification(
        _notificationHour,
        _notificationMinute,
      );

      // Verify the notification was actually scheduled — scheduling silently
      // returns early if SCHEDULE_EXACT_ALARM permission is not yet granted
      // (API 31–32). Read prefs back to detect this case.
      final result = await notificationService.loadSettings();
      if (mounted) {
        setState(() {
          _notificationsEnabled = result.enabled;
        });
        if (!result.enabled) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Permission required: go to Settings → Apps → KindWords → '
                'Alarms & Reminders and allow exact alarms, then try again.',
              ),
              duration: Duration(seconds: 6),
            ),
          );
        }
      }
    } else {
      await notificationService.cancelNotification();
      if (mounted) {
        setState(() {
          _notificationsEnabled = false;
        });
      }
    }
  }

  Future<void> _pickTime() async {
    final notificationService = context.read<NotificationServiceBase>();

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: _notificationHour,
        minute: _notificationMinute,
      ),
    );

    if (pickedTime != null) {
      if (mounted) {
        setState(() {
          _notificationHour = pickedTime.hour;
          _notificationMinute = pickedTime.minute;
        });
      }

      if (_notificationsEnabled) {
        await notificationService.scheduleDailyNotification(
          _notificationHour,
          _notificationMinute,
        );
      }
    }
  }

  String _formatTime(int hour, int minute) {
    final hourStr = hour.toString().padLeft(2, '0');
    final minuteStr = minute.toString().padLeft(2, '0');
    return '$hourStr:$minuteStr';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                // Battery optimization warning banner
                if (_isBatteryOptimized)
                  MaterialBanner(
                    padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                    content: const Text(
                      'Battery optimization is ON for this app. '
                      'Scheduled notifications may be delayed or blocked — '
                      'especially on Honor / Huawei devices.',
                    ),
                    leading: const Icon(
                      Icons.battery_alert,
                      color: Colors.deepOrange,
                    ),
                    actions: [
                      TextButton(
                        onPressed: _requestBatteryExemption,
                        child: const Text('FIX NOW'),
                      ),
                    ],
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(
                    'Daily Reminders',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                SwitchListTile(
                  title: const Text('Enable Daily Notifications'),
                  subtitle: Text(
                    _notificationsEnabled
                        ? 'Tap the time below to change the schedule'
                        : 'Notifications are disabled',
                  ),
                  value: _notificationsEnabled,
                  onChanged: _onToggleChanged,
                ),
                ListTile(
                  leading: const Icon(Icons.access_time),
                  title: const Text('Reminder Time'),
                  subtitle: Text(
                    _formatTime(_notificationHour, _notificationMinute),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _pickTime,
                ),
                const Divider(height: 32),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'Daily reminders will show a random motivational quote at your chosen time.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                  ),
                ),

                // -------------------------------------------------------
                // Debug section — visible only when the app is launched with
                // --dart-define=KINDWORDS_DEBUG_NOTIFICATIONS=true
                // -------------------------------------------------------
                if (_kDebugNotifications) ...[
                  const Divider(height: 32),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: Text(
                      'Notification Debug',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Theme.of(context).colorScheme.error,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: OutlinedButton.icon(
                      onPressed: _sendTestNotification,
                      icon: const Icon(Icons.notifications_active_outlined),
                      label: const Text('Send Test Notification'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Scheduled test delay: $_scheduleTestDelaySeconds seconds',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        Slider(
                          value: _scheduleTestDelaySeconds.toDouble(),
                          min: 5,
                          max: 60,
                          divisions: 11,
                          label: '$_scheduleTestDelaySeconds s',
                          onChanged: (value) {
                            setState(() {
                              _scheduleTestDelaySeconds = value.round();
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: OutlinedButton.icon(
                      onPressed: _scheduleTestInSeconds,
                      icon: const Icon(Icons.alarm),
                      label: Text(
                        _scheduledTestRemainingSeconds == null
                            ? 'Schedule Test (fires in $_scheduleTestDelaySeconds s)'
                            : 'Scheduled — $_scheduledTestRemainingSeconds s remaining',
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 16),
              ],
            ),
    );
  }
}
