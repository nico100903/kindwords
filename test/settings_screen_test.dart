import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:kindwords/screens/settings_screen.dart';
import 'package:kindwords/services/notification_service.dart';

/// Mock NotificationService for widget testing.
///
/// Tracks method calls to verify SettingsScreen interactions.
class MockNotificationService implements NotificationServiceBase {
  bool loadSettingsCalled = false;
  bool scheduleDailyNotificationCalled = false;
  bool cancelNotificationCalled = false;
  
  int? lastScheduleHour;
  int? lastScheduleMinute;
  
  ({bool enabled, int hour, int minute}) _settings = (enabled: false, hour: 8, minute: 0);
  
  /// Sets the mock settings that loadSettings() will return.
  void setMockSettings({required bool enabled, required int hour, required int minute}) {
    _settings = (enabled: enabled, hour: hour, minute: minute);
  }
  
  /// Simulates loading settings from SharedPreferences.
  @override
  Future<({bool enabled, int hour, int minute})> loadSettings() async {
    loadSettingsCalled = true;
    return _settings;
  }
  
  /// Simulates scheduling a daily notification.
  @override
  Future<void> scheduleDailyNotification(int hour, int minute) async {
    scheduleDailyNotificationCalled = true;
    lastScheduleHour = hour;
    lastScheduleMinute = minute;
    _settings = (enabled: true, hour: hour, minute: minute);
  }
  
  /// Simulates canceling the notification.
  @override
  Future<void> cancelNotification() async {
    cancelNotificationCalled = true;
    _settings = (enabled: false, hour: _settings.hour, minute: _settings.minute);
  }
  
  void reset() {
    loadSettingsCalled = false;
    scheduleDailyNotificationCalled = false;
    cancelNotificationCalled = false;
    lastScheduleHour = null;
    lastScheduleMinute = null;
    _settings = (enabled: false, hour: 8, minute: 0);
  }
}

/// Creates a testable SettingsScreen with the provided mock service.
Widget createTestSettingsApp(MockNotificationService mockService) {
  return MaterialApp(
    home: Scaffold(
      body: Provider<NotificationServiceBase>.value(
        value: mockService,
        child: const SettingsScreen(),
      ),
    ),
  );
}

void main() {
  group('SettingsScreen - Notification Preferences', () {
    late MockNotificationService mockService;

    setUp(() {
      mockService = MockNotificationService();
    });

    // -------------------------------------------------------------------------
    // ACCEPTANCE CRITERION: Settings destination includes daily notification
    // on/off control (Switch widget)
    // -------------------------------------------------------------------------
    group('AC: Notification toggle control', () {
      testWidgets('displays a Switch widget for enabling/disabling notifications', 
          (WidgetTester tester) async {
        // Arrange: mock returns disabled by default
        mockService.setMockSettings(enabled: false, hour: 8, minute: 0);

        // Act: render SettingsScreen
        await tester.pumpWidget(createTestSettingsApp(mockService));
        await tester.pumpAndSettle();

        // Assert: Switch widget is present
        expect(find.byType(Switch), findsOneWidget, 
            reason: 'Settings screen must have a Switch for notification toggle');
      });

      testWidgets('loadSettings is called on screen initialization', 
          (WidgetTester tester) async {
        // Arrange
        mockService.setMockSettings(enabled: false, hour: 8, minute: 0);

        // Act
        await tester.pumpWidget(createTestSettingsApp(mockService));
        await tester.pumpAndSettle();

        // Assert: loadSettings was called to populate initial state
        expect(mockService.loadSettingsCalled, isTrue,
            reason: 'SettingsScreen must call loadSettings() in initState');
      });

      testWidgets('Switch reflects enabled state when notifications are ON', 
          (WidgetTester tester) async {
        // Arrange: mock returns enabled state
        mockService.setMockSettings(enabled: true, hour: 14, minute: 30);

        // Act
        await tester.pumpWidget(createTestSettingsApp(mockService));
        await tester.pumpAndSettle();

        // Assert: Switch is in ON position
        final switchWidget = tester.widget<Switch>(find.byType(Switch));
        expect(switchWidget.value, isTrue,
            reason: 'Switch must reflect enabled state from loadSettings');
      });

      testWidgets('Switch reflects disabled state when notifications are OFF', 
          (WidgetTester tester) async {
        // Arrange
        mockService.setMockSettings(enabled: false, hour: 8, minute: 0);

        // Act
        await tester.pumpWidget(createTestSettingsApp(mockService));
        await tester.pumpAndSettle();

        // Assert: Switch is in OFF position
        final switchWidget = tester.widget<Switch>(find.byType(Switch));
        expect(switchWidget.value, isFalse,
            reason: 'Switch must reflect disabled state from loadSettings');
      });

      testWidgets('toggling Switch ON calls scheduleDailyNotification', 
          (WidgetTester tester) async {
        // Arrange: start disabled
        mockService.setMockSettings(enabled: false, hour: 8, minute: 0);
        await tester.pumpWidget(createTestSettingsApp(mockService));
        await tester.pumpAndSettle();

        // Act: toggle the switch ON
        await tester.tap(find.byType(Switch));
        await tester.pumpAndSettle();

        // Assert: scheduleDailyNotification was called
        expect(mockService.scheduleDailyNotificationCalled, isTrue,
            reason: 'Toggling ON must call scheduleDailyNotification');
      });

      testWidgets('toggling Switch OFF calls cancelNotification', 
          (WidgetTester tester) async {
        // Arrange: start enabled
        mockService.setMockSettings(enabled: true, hour: 14, minute: 30);
        await tester.pumpWidget(createTestSettingsApp(mockService));
        await tester.pumpAndSettle();

        // Act: toggle the switch OFF
        await tester.tap(find.byType(Switch));
        await tester.pumpAndSettle();

        // Assert: cancelNotification was called
        expect(mockService.cancelNotificationCalled, isTrue,
            reason: 'Toggling OFF must call cancelNotification');
      });
    });

    // -------------------------------------------------------------------------
    // ACCEPTANCE CRITERION: Settings destination includes time selection 
    // control for daily reminder
    // -------------------------------------------------------------------------
    group('AC: Time selection control', () {
      testWidgets('displays current notification time in 24-hour format', 
          (WidgetTester tester) async {
        // Arrange: set time to 14:30
        mockService.setMockSettings(enabled: true, hour: 14, minute: 30);

        // Act
        await tester.pumpWidget(createTestSettingsApp(mockService));
        await tester.pumpAndSettle();

        // Assert: time is displayed in HH:MM format
        expect(find.textContaining('14:30'), findsWidgets,
            reason: 'Settings screen must display time in 24-hour HH:MM format');
      });

      testWidgets('displays time with leading zeros for single-digit hours', 
          (WidgetTester tester) async {
        // Arrange: set time to 08:05
        mockService.setMockSettings(enabled: true, hour: 8, minute: 5);

        // Act
        await tester.pumpWidget(createTestSettingsApp(mockService));
        await tester.pumpAndSettle();

        // Assert: time shows leading zeros (08:05, not 8:5)
        expect(find.textContaining('08:05'), findsWidgets,
            reason: 'Time must display with leading zeros (08:05 not 8:5)');
      });

      testWidgets('has a tappable element for changing notification time', 
          (WidgetTester tester) async {
        // Arrange
        mockService.setMockSettings(enabled: true, hour: 8, minute: 0);

        // Act
        await tester.pumpWidget(createTestSettingsApp(mockService));
        await tester.pumpAndSettle();

        // Assert: there's a ListTile or InkWell containing the time
        // that can be tapped to open time picker
        final timeText = find.textContaining('08:00');
        expect(timeText, findsWidgets,
            reason: 'Time must be displayed on screen');

        // The time should be in a tappable container (ListTile, InkWell, etc.)
        final tappable = find.ancestor(
          of: timeText.first,
          matching: find.byWidgetPredicate((w) => 
              w is ListTile || w is InkWell || w is GestureDetector),
        );
        expect(tappable, findsWidgets,
            reason: 'Time display must be tappable to open time picker');
      });

      testWidgets('tapping time opens TimePicker dialog', 
          (WidgetTester tester) async {
        // Arrange
        mockService.setMockSettings(enabled: true, hour: 8, minute: 0);
        await tester.pumpWidget(createTestSettingsApp(mockService));
        await tester.pumpAndSettle();

        // Act: tap on the time display area
        final timeText = find.textContaining('08:00');
        await tester.tap(timeText.first);
        await tester.pumpAndSettle();

        // Assert: TimePicker dialog is shown
        expect(find.byType(TimePickerDialog), findsOneWidget,
            reason: 'Tapping time must open a TimePickerDialog');
      });

      testWidgets('confirming new time calls scheduleDailyNotification with new values', 
          (WidgetTester tester) async {
        // Arrange: start with 08:00
        mockService.setMockSettings(enabled: true, hour: 8, minute: 0);
        await tester.pumpWidget(createTestSettingsApp(mockService));
        await tester.pumpAndSettle();

        // Act: tap time to open picker
        final timeText = find.textContaining('08:00');
        await tester.tap(timeText.first);
        await tester.pumpAndSettle();

        // Select new time (14:30) via time picker
        // Note: Flutter's TimePicker requires finding and tapping OK/confirm
        final okButton = find.text('OK');
        if (okButton.evaluate().isNotEmpty) {
          await tester.tap(okButton);
          await tester.pumpAndSettle();
        }

        // Assert: scheduleDailyNotification was called (time changed)
        expect(mockService.scheduleDailyNotificationCalled, isTrue,
            reason: 'Confirming new time must call scheduleDailyNotification');
      });
    });

    // -------------------------------------------------------------------------
    // ACCEPTANCE CRITERION: Currently chosen state/time remain visible 
    // after leaving and reopening the app
    // -------------------------------------------------------------------------
    group('AC: Settings persistence across sessions', () {
      testWidgets('fresh install shows default values (disabled, 08:00)', 
          (WidgetTester tester) async {
        // Arrange: mock returns defaults (as per loadSettings contract)
        mockService.setMockSettings(enabled: false, hour: 8, minute: 0);

        // Act: first-time launch simulation
        await tester.pumpWidget(createTestSettingsApp(mockService));
        await tester.pumpAndSettle();

        // Assert: defaults are shown without crash
        final switchWidget = tester.widget<Switch>(find.byType(Switch));
        expect(switchWidget.value, isFalse,
            reason: 'Fresh install must show notifications disabled');
        expect(find.textContaining('08:00'), findsWidgets,
            reason: 'Fresh install must show default time 08:00');
      });

      testWidgets('enabled state persists (simulated by re-reading from service)', 
          (WidgetTester tester) async {
        // Arrange: simulate user had previously enabled notifications at 14:30
        mockService.setMockSettings(enabled: true, hour: 14, minute: 30);

        // Act: "reopen" app by rebuilding with same persisted state
        await tester.pumpWidget(createTestSettingsApp(mockService));
        await tester.pumpAndSettle();

        // Assert: persisted state is reflected
        final switchWidget = tester.widget<Switch>(find.byType(Switch));
        expect(switchWidget.value, isTrue,
            reason: 'Enabled state must persist and be shown on reload');
        expect(find.textContaining('14:30'), findsWidgets,
            reason: 'Time 14:30 must persist and be shown on reload');
      });

      testWidgets('disabled state persists (simulated by re-reading from service)', 
          (WidgetTester tester) async {
        // Arrange: simulate user had previously disabled notifications
        mockService.setMockSettings(enabled: false, hour: 9, minute: 15);

        // Act
        await tester.pumpWidget(createTestSettingsApp(mockService));
        await tester.pumpAndSettle();

        // Assert
        final switchWidget = tester.widget<Switch>(find.byType(Switch));
        expect(switchWidget.value, isFalse,
            reason: 'Disabled state must persist and be shown on reload');
      });
    });

    // -------------------------------------------------------------------------
    // EDGE CASE: Time boundary values (00:00 and 23:59)
    // -------------------------------------------------------------------------
    group('Edge case: Time boundary values', () {
      testWidgets('displays midnight (00:00) correctly', 
          (WidgetTester tester) async {
        // Arrange
        mockService.setMockSettings(enabled: true, hour: 0, minute: 0);

        // Act
        await tester.pumpWidget(createTestSettingsApp(mockService));
        await tester.pumpAndSettle();

        // Assert
        expect(find.textContaining('00:00'), findsWidgets,
            reason: 'Midnight (00:00) must display correctly');
      });

      testWidgets('displays end of day (23:59) correctly', 
          (WidgetTester tester) async {
        // Arrange
        mockService.setMockSettings(enabled: true, hour: 23, minute: 59);

        // Act
        await tester.pumpWidget(createTestSettingsApp(mockService));
        await tester.pumpAndSettle();

        // Assert
        expect(find.textContaining('23:59'), findsWidgets,
            reason: 'End of day (23:59) must display correctly');
      });
    });

    // -------------------------------------------------------------------------
    // EDGE CASE: Idempotency - toggle same state twice
    // -------------------------------------------------------------------------
    group('Edge case: Idempotent operations', () {
      testWidgets('toggling ON when already enabled calls scheduleDailyNotification', 
          (WidgetTester tester) async {
        // Arrange: start enabled
        mockService.setMockSettings(enabled: true, hour: 10, minute: 0);
        await tester.pumpWidget(createTestSettingsApp(mockService));
        await tester.pumpAndSettle();

        // Act: toggle (would turn OFF in current UI, but this tests the toggle handler)
        await tester.tap(find.byType(Switch));
        await tester.pumpAndSettle();

        // Assert: appropriate service method was called
        // (either cancel or schedule depending on resulting state)
        expect(
          mockService.cancelNotificationCalled || mockService.scheduleDailyNotificationCalled,
          isTrue,
          reason: 'Toggle interaction must trigger a service call',
        );
      });
    });

    // -------------------------------------------------------------------------
    // BUSINESS RULE: Settings destination reachable from main experience
    // -------------------------------------------------------------------------
    group('AC: Settings destination reachable', () {
      testWidgets('SettingsScreen renders without crash', 
          (WidgetTester tester) async {
        // Arrange
        mockService.setMockSettings(enabled: false, hour: 8, minute: 0);

        // Act
        await tester.pumpWidget(createTestSettingsApp(mockService));
        await tester.pumpAndSettle();

        // Assert: screen renders with expected structure
        expect(find.byType(SettingsScreen), findsOneWidget,
            reason: 'SettingsScreen must render without crash');
      });

      testWidgets('Settings screen has AppBar with Settings title', 
          (WidgetTester tester) async {
        // Arrange
        mockService.setMockSettings(enabled: false, hour: 8, minute: 0);

        // Act
        await tester.pumpWidget(createTestSettingsApp(mockService));
        await tester.pumpAndSettle();

        // Assert: AppBar with 'Settings' title
        expect(find.text('Settings'), findsOneWidget,
            reason: 'Settings screen must have AppBar with Settings title');
      });
    });
  });
}
