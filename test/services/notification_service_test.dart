// ignore_for_file: require_trailing_commas
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kindwords/models/quote.dart';
import 'package:kindwords/repositories/quote_repository.dart';
import 'package:kindwords/services/notification_service.dart';
import 'package:kindwords/services/quote_service.dart';

// ---------------------------------------------------------------------------
// Helpers: stub the flutter_local_notifications platform channel so that
// plugin calls do not throw MissingPluginException in unit tests.
//
// The plugin uses method channel: "dexterous.com/flutter/local_notifications"
// We stub every call with a minimal success response so the Dart layer under
// test can run without a real Android platform.
// ---------------------------------------------------------------------------

const _kChannelName = 'dexterous.com/flutter/local_notifications';

/// Installs a permissive stub handler for the flutter_local_notifications
/// method channel.  Returns success (null / true) for every call so the
/// Dart-layer logic under test is exercised without hitting a real platform.
void _stubNotificationChannel() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel(_kChannelName),
    (MethodCall call) async {
      switch (call.method) {
        case 'initialize':
          return true;
        case 'createNotificationChannel':
          return null;
        case 'cancel':
          return null;
        case 'zonedSchedule':
          return null;
        case 'requestExactAlarmsPermission':
          return true;
        case 'requestNotificationsPermission':
          return true;
        case 'canScheduleExactNotifications':
          return true;
        default:
          return null;
      }
    },
  );
}

// ---------------------------------------------------------------------------
// Minimal fake repository + service — QuoteService needs a repo; we provide a
// real repo backed by a single quote so QuoteService.getRandomQuote() works.
// ---------------------------------------------------------------------------

class _FakeQuoteRepository implements QuoteRepositoryBase {
  static const _quote = Quote(id: 'q001', text: 'Stay kind.', author: null);

  @override
  Future<List<Quote>> getAllQuotes() async => const [_quote];

  @override
  Future<Quote?> getById(String id) async =>
      id == _quote.id ? _quote : null;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // Ensure the Flutter test binding is available (required for method channel
  // stubs and SharedPreferences mock initialisation).
  TestWidgetsFlutterBinding.ensureInitialized();

  late NotificationService service;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    _stubNotificationChannel();

    final repo = _FakeQuoteRepository();
    final quoteService = QuoteService(repo);
    service = NotificationService(quoteService);
  });

  // -------------------------------------------------------------------------
  // loadSettings() — SharedPreferences reads
  // -------------------------------------------------------------------------

  group('NotificationService.loadSettings()', () {
    test('returns defaults when no prefs are set', () async {
      // Arrange: setUp already called setMockInitialValues({})

      // Act
      final settings = await service.loadSettings();

      // Assert: disabled, 8:00 defaults
      expect(settings.enabled, isFalse);
      expect(settings.hour, equals(8));
      expect(settings.minute, equals(0));
    });

    test('returns saved values when prefs contain persisted settings', () async {
      // Arrange: pre-load prefs with a saved schedule
      SharedPreferences.setMockInitialValues({
        'notification_enabled': true,
        'notification_hour': 9,
        'notification_minute': 30,
      });

      // Act
      final settings = await service.loadSettings();

      // Assert: matches stored values exactly
      expect(settings.enabled, isTrue);
      expect(settings.hour, equals(9));
      expect(settings.minute, equals(30));
    });
  });

  // -------------------------------------------------------------------------
  // cancelNotification() — sets enabled=false in prefs
  // -------------------------------------------------------------------------

  group('NotificationService.cancelNotification()', () {
    test('sets notification_enabled to false in prefs', () async {
      // Arrange: start with enabled=true
      SharedPreferences.setMockInitialValues({
        'notification_enabled': true,
        'notification_hour': 8,
        'notification_minute': 0,
      });

      // Act
      await service.cancelNotification();

      // Assert: prefs reflect disabled state
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('notification_enabled'), isFalse);
    });
  });

  // -------------------------------------------------------------------------
  // rescheduleFromSavedSettings() — skips schedule when disabled
  // -------------------------------------------------------------------------

  group('NotificationService.rescheduleFromSavedSettings()', () {
    test(
        'completes without exception and leaves prefs unchanged when disabled',
        () async {
      // Arrange: notifications are disabled in prefs
      SharedPreferences.setMockInitialValues({
        'notification_enabled': false,
        'notification_hour': 8,
        'notification_minute': 0,
      });

      // Act + Assert: must not throw
      await expectLater(
        service.rescheduleFromSavedSettings(),
        completes,
      );

      // Verify prefs were not modified (still disabled)
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('notification_enabled'), isFalse);
    });
  });

  // -------------------------------------------------------------------------
  // notificationBootCallback — symbol existence contract (Task 03.03)
  //
  // This test MUST FAIL until the coder adds:
  //
  //   @pragma('vm:entry-point')
  //   Future<void> notificationBootCallback() async { ... }
  //
  // to lib/main.dart.  The test imports main.dart and references the symbol;
  // the Dart compiler will reject the import if the symbol does not exist.
  // -------------------------------------------------------------------------

  // NOTE: The boot callback symbol test lives in test/main_boot_callback_test.dart
  // to keep that compile-time gate isolated.  See that file for the red test.
}
