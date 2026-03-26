import 'package:flutter/widgets.dart';
import 'package:kindwords/bootstrap/app_bootstrap.dart';
import 'package:kindwords/data/quote_database.dart';
import 'package:kindwords/data/quotes_data.dart';
import 'package:kindwords/repositories/quote_repository.dart';
import 'package:kindwords/services/notification_service.dart';
import 'package:kindwords/services/quote_service.dart';

/// Boot recovery entry point — called by [BootReceiver] after device reboot.
/// Reconstructs minimal service graph and reschedules daily notification.
/// [@pragma] prevents tree-shaker from removing this in release builds.
@pragma('vm:entry-point')
Future<void> notificationBootCallback() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final db = QuoteDatabase();
    await db.open();
    await db.seedIfEmpty(kAllQuotes);
    final quoteRepo = LocalQuoteRepository(db);
    final quoteService = QuoteService(quoteRepo);
    final notificationService = NotificationService(quoteService);
    await notificationService.initialize();
    await notificationService.rescheduleFromSavedSettings();
  } catch (_) {
    // Silently exit in headless/test environments where platform channels
    // (sqflite, flutter_local_notifications) are unavailable.
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final app = await bootstrapApp();
  runApp(app);
}
