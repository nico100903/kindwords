import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/quote_provider.dart';
import '../providers/favorites_provider.dart';
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
Future<Widget> bootstrapApp() async {
  // Instantiate services in dependency order
  final quoteService = QuoteService();
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
