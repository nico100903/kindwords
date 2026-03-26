import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/quote_database.dart';
import '../data/quotes_data.dart';
import '../providers/quote_provider.dart';
import '../providers/favorites_provider.dart';
import '../repositories/quote_repository.dart';
import '../services/quote_service.dart';
import '../services/favorites_service.dart';
import '../services/notification_service.dart';
import '../screens/home_screen.dart';
import '../screens/favorites_screen.dart';
import '../screens/settings_screen.dart';

/// Bootstraps the KindWords application.
///
/// Creates services in dependency order, initializes notifications,
/// and builds the provider tree with the app widget.
///
/// Bootstrap ordering (non-negotiable per flutter-standards §3):
///   1. Open database
///   2. Seed quotes — must complete before any service reads
///   3. Construct repository + services
Future<Widget> bootstrapApp() async {
  // 1. Open SQLite database
  final db = QuoteDatabase();
  await db.open();

  // 2. Seed quotes table from embedded list (idempotent — no-op after first run)
  await db.seedIfEmpty(kAllQuotes);

  // 3. Construct repository + wire into QuoteService (Wave R5)
  final quoteRepo = LocalQuoteRepository(db);

  // Instantiate services in dependency order
  final quoteService = QuoteService(quoteRepo);
  final favoritesService = FavoritesService(quoteService);
  final notificationService = NotificationService(quoteService);

  // Initialize notification service before app launch
  await notificationService.initialize();

  return MultiProvider(
    providers: [
      ChangeNotifierProvider(
        create: (_) => QuoteProvider(quoteService),
      ),
      ChangeNotifierProvider(
        create: (_) => FavoritesProvider(favoritesService),
      ),
      // Expose NotificationService for SettingsScreen access
      Provider<NotificationServiceBase>.value(value: notificationService),
    ],
    child: const KindWordsApp(),
  );
}

class KindWordsApp extends StatelessWidget {
  const KindWordsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KindWords',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.amber,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const HomeScreen(),
        '/favorites': (context) => const FavoritesScreen(),
        '/settings': (context) => const SettingsScreen(),
      },
    );
  }
}
