import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/notification_service.dart';

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

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final notificationService = context.read<NotificationService>();
    final settings = await notificationService.loadSettings();
    setState(() {
      _notificationsEnabled = settings.enabled;
      _notificationHour = settings.hour;
      _notificationMinute = settings.minute;
      _isLoading = false;
    });
  }

  Future<void> _onToggleChanged(bool value) async {
    final notificationService = context.read<NotificationService>();

    if (value) {
      // Enable notifications - schedule with current time
      await notificationService.scheduleDailyNotification(
        _notificationHour,
        _notificationMinute,
      );
    } else {
      // Disable notifications
      await notificationService.cancelNotification();
    }

    setState(() {
      _notificationsEnabled = value;
    });
  }

  Future<void> _pickTime() async {
    // Capture service before async gap to avoid context usage warning
    final notificationService = context.read<NotificationService>();
    
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: _notificationHour,
        minute: _notificationMinute,
      ),
      builder: (context, child) {
        // Enforce 24-hour format per SPEC requirement
        return Localizations.override(
          context: context,
          locale: const Locale('en', 'GB'), // 24-hour locale
          child: child!,
        );
      },
    );

    if (pickedTime != null) {

      setState(() {
        _notificationHour = pickedTime.hour;
        _notificationMinute = pickedTime.minute;
      });

      // If notifications are enabled, reschedule with new time
      if (_notificationsEnabled) {
        await notificationService.scheduleDailyNotification(
          _notificationHour,
          _notificationMinute,
        );
      }
    }
  }

  String _formatTime(int hour, int minute) {
    // Manual 24-hour formatting to ensure consistent display
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
                // Notification section header
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
                // Enable/disable toggle
                SwitchListTile(
                  title: const Text('Enable Daily Notifications'),
                  subtitle: Text(
                    _notificationsEnabled
                        ? 'Daily motivation at ${_formatTime(_notificationHour, _notificationMinute)}'
                        : 'Notifications are disabled',
                  ),
                  value: _notificationsEnabled,
                  onChanged: _onToggleChanged,
                ),
                // Time picker (only shown when enabled)
                if (_notificationsEnabled)
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
                // Info text
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'Daily reminders will show a random motivational quote at your chosen time.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                  ),
                ),
              ],
            ),
    );
  }
}
