import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/notification_service.dart';

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

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _checkBatteryOptimization();
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
                const SizedBox(height: 16),
              ],
            ),
    );
  }
}
