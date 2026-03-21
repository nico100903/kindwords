import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:kindwords/services/notification_service.dart';

/// Settings screen for notification configuration.
///
/// Task 03.01: Full notification time picker and toggle implementation.
/// Allows users to enable/disable daily notifications and select reminder time.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = false;
  int _hour = 8;
  int _minute = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final service = context.read<NotificationServiceBase>();
    final settings = await service.loadSettings();
    
    if (mounted) {
      setState(() {
        _notificationsEnabled = settings.enabled;
        _hour = settings.hour;
        _minute = settings.minute;
        _isLoading = false;
      });
    }
  }

  String get _formattedTime {
    return '${_hour.toString().padLeft(2, '0')}:${_minute.toString().padLeft(2, '0')}';
  }

  Future<void> _toggleNotifications(bool value) async {
    final service = context.read<NotificationServiceBase>();
    
    if (value) {
      await service.scheduleDailyNotification(_hour, _minute);
    } else {
      await service.cancelNotification();
    }
    
    if (mounted) {
      setState(() {
        _notificationsEnabled = value;
      });
    }
  }

  Future<void> _selectTime() async {
    // Get service before async gap to avoid use_build_context_synchronously
    final service = context.read<NotificationServiceBase>();
    
    final TimeOfDay? selectedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _hour, minute: _minute),
      builder: (context, child) {
        // Ensure 24-hour format
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        );
      },
    );

    if (selectedTime != null) {
      await service.scheduleDailyNotification(selectedTime.hour, selectedTime.minute);
      
      if (mounted) {
        setState(() {
          _hour = selectedTime.hour;
          _minute = selectedTime.minute;
          _notificationsEnabled = true;
        });
      }
    }
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
                SwitchListTile(
                  title: const Text('Daily Notifications'),
                  subtitle: Text(_notificationsEnabled
                      ? 'Enabled'
                      : 'Disabled'),
                  value: _notificationsEnabled,
                  onChanged: _toggleNotifications,
                ),
                ListTile(
                  title: const Text('Reminder Time'),
                  trailing: InkWell(
                    onTap: _selectTime,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _formattedTime,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.access_time),
                        ],
                      ),
                    ),
                  ),
                  onTap: _selectTime,
                ),
              ],
            ),
    );
  }
}
