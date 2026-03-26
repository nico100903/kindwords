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
    } else {
      await notificationService.cancelNotification();
    }

    if (mounted) {
      setState(() {
        _notificationsEnabled = value;
      });
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
              ],
            ),
    );
  }
}
