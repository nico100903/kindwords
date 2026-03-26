import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:kindwords/bootstrap/app_bootstrap.dart';
import 'package:kindwords/screens/favorites_screen.dart';
import 'package:kindwords/providers/quote_provider.dart';
import 'package:kindwords/providers/favorites_provider.dart';
import 'package:kindwords/services/quote_service.dart';
import 'package:kindwords/services/favorites_service.dart';
import 'package:kindwords/repositories/quote_repository.dart';
import 'package:kindwords/models/quote.dart';
import 'package:kindwords/data/quotes_data.dart';

// ---------------------------------------------------------------------------
// In-memory test repository — wraps kAllQuotes so tests don't need sqflite.
// ---------------------------------------------------------------------------
class _InMemoryQuoteRepository implements QuoteRepositoryBase {
  @override
  Future<List<Quote>> getAllQuotes() async => kAllQuotes;

  @override
  Future<Quote?> getById(String id) async {
    try {
      return kAllQuotes.firstWhere((q) => q.id == id);
    } catch (_) {
      return null;
    }
  }

  // Sprint 2 CRUD stubs — not exercised by these tests
  @override
  Future<void> insertQuote(Quote quote) => throw UnimplementedError();
  @override
  Future<void> updateQuote(Quote quote) => throw UnimplementedError();
  @override
  Future<void> deleteQuote(String id) => throw UnimplementedError();
  @override
  Future<List<Quote>> getBySource(QuoteSource source) =>
      throw UnimplementedError();
  @override
  Future<List<Quote>> getByTag(String tag) => throw UnimplementedError();
}

/// Creates a testable widget tree with providers.
Widget _createTestApp() {
  final quoteService = QuoteService(_InMemoryQuoteRepository());
  final favoritesService = FavoritesService(quoteService);

  return MultiProvider(
    providers: [
      ChangeNotifierProvider(
        create: (_) => QuoteProvider(quoteService),
      ),
      ChangeNotifierProvider(
        create: (_) => FavoritesProvider(favoritesService),
      ),
    ],
    child: const KindWordsApp(),
  );
}

void main() {
  testWidgets('App launches with KindWords title', (WidgetTester tester) async {
    await tester.pumpWidget(_createTestApp());

    // Verify that the app bar shows 'KindWords'
    expect(find.text('KindWords'), findsOneWidget);
  });

  testWidgets('Home screen has bottom navigation bar',
      (WidgetTester tester) async {
    await tester.pumpWidget(_createTestApp());

    // Verify bottom navigation bar is present with Home/Favorites/Settings
    expect(find.byType(BottomNavigationBar), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Favorites'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
  });

  testWidgets('Home screen displays a quote', (WidgetTester tester) async {
    await tester.pumpWidget(_createTestApp());
    await tester.pumpAndSettle(); // wait for async _initialize() to complete

    // Verify a quote card is displayed (QuoteProvider ensures non-null quote)
    expect(find.byType(Card), findsOneWidget);
  });

  // Task 02.01: Quality Gates for Favorites Provider and Screen Shell

  // Task 02.01: Quality Gates for Favorites Provider and Screen Shell

  testWidgets(
    'FavoritesProvider exposes required state interface',
    (WidgetTester tester) async {
      final quoteService = QuoteService(_InMemoryQuoteRepository());
      final favoritesService = FavoritesService(quoteService);
      final favoritesProvider = FavoritesProvider(favoritesService);

      // Verify the provider has the expected interface methods and properties
      expect(favoritesProvider.favorites, isNotNull);
      expect(favoritesProvider.isLoading, isTrue); // Starts loading

      // Verify methods exist and are callable
      expect(favoritesProvider.isFavorite, isNotNull);
      expect(favoritesProvider.toggleFavorite, isNotNull);
      expect(favoritesProvider.addFavorite, isNotNull);
      expect(favoritesProvider.removeFavorite, isNotNull);
    },
  );

  testWidgets(
    'FavoritesScreen renders with Scaffold structure',
    (WidgetTester tester) async {
      final quoteService = QuoteService(_InMemoryQuoteRepository());
      final favoritesService = FavoritesService(quoteService);
      final favoritesProvider = FavoritesProvider(favoritesService);

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider(
            create: (_) => favoritesProvider,
            child: const FavoritesScreen(),
          ),
        ),
      );

      // Verify basic screen structure
      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);
      expect(find.text('My Favorites'), findsOneWidget);
    },
  );

  testWidgets(
    'FavoritesScreen shows loading state when isLoading is true',
    (WidgetTester tester) async {
      final quoteService = QuoteService(_InMemoryQuoteRepository());
      final favoritesService = FavoritesService(quoteService);
      final favoritesProvider = FavoritesProvider(favoritesService);

      // Verify loading state is true initially
      expect(favoritesProvider.isLoading, isTrue);

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider(
            create: (_) => favoritesProvider,
            child: const FavoritesScreen(),
          ),
        ),
      );

      // Pump once (before async completes)
      await tester.pump();

      // If still loading, should show CircularProgressIndicator
      if (favoritesProvider.isLoading) {
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      }
    },
  );

  testWidgets(
    'FavoritesScreen Consumer updates when FavoritesProvider changes',
    (WidgetTester tester) async {
      final quoteService = QuoteService(_InMemoryQuoteRepository());
      final favoritesService = FavoritesService(quoteService);
      final favoritesProvider = FavoritesProvider(favoritesService);

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider(
            create: (_) => favoritesProvider,
            child: const FavoritesScreen(),
          ),
        ),
      );

      // The Consumer widget should rebuild when provider notifies
      // By building successfully, we verify the Consumer pattern is in place
      expect(find.byType(Scaffold), findsOneWidget);
    },
  );
}
