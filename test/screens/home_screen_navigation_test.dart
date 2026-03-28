// ignore_for_file: require_trailing_commas, always_declare_return_types
//
// Task 08.02 — Failing widget tests for bottom navigation expansion.
//
// ALL tests in this file are expected to FAIL until the coder:
//   • Expands BottomNavigationBar from 3 to 4 items
//   • Adds Quotes tab at index 1 (Home=0, Quotes=1, Favorites=2, Settings=3)
//   • Inserts case 1: in _onNavItemTapped to push '/quotes'
//   • Shifts Favorites from case 1: to case 2:
//   • Shifts Settings from case 2: to case 3:
//
// DO NOT fix these tests. They are the contract.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kindwords/screens/home_screen.dart';
import 'package:kindwords/screens/favorites_screen.dart';
import 'package:kindwords/screens/settings_screen.dart';
import 'package:kindwords/screens/quote_catalog_screen.dart';
import 'package:kindwords/providers/quote_provider.dart';
import 'package:kindwords/providers/favorites_provider.dart';
import 'package:kindwords/providers/quote_catalog_provider.dart';
import 'package:kindwords/services/quote_service.dart';
import 'package:kindwords/services/favorites_service.dart';
import 'package:kindwords/services/notification_service.dart';
import 'package:kindwords/repositories/quote_repository.dart';
import 'package:kindwords/models/quote.dart';

// ---------------------------------------------------------------------------
// In-memory test repository (mirrors existing test patterns)
// ---------------------------------------------------------------------------

class _InMemoryQuoteRepository implements QuoteRepositoryBase {
  final List<Quote> _quotes;
  _InMemoryQuoteRepository(this._quotes);

  @override
  Future<List<Quote>> getAllQuotes() async => List.unmodifiable(_quotes);

  @override
  Future<Quote?> getById(String id) async {
    try {
      return _quotes.firstWhere((q) => q.id == id);
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

/// Mock notification service for SettingsScreen tests.
///
/// Provides no-op implementations that return safe defaults.
class _MockNotificationService implements NotificationServiceBase {
  @override
  Future<({bool enabled, int hour, int minute})> loadSettings() async {
    return (enabled: false, hour: 8, minute: 0);
  }

  @override
  Future<void> scheduleDailyNotification(int hour, int minute) async {}

  @override
  Future<void> cancelNotification() async {}

  @override
  Future<void> rescheduleFromSavedSettings() async {}
}

// ---------------------------------------------------------------------------
// Test fixtures
// ---------------------------------------------------------------------------

final _testQuotes = List<Quote>.generate(
  5,
  (i) => Quote(
    id: 'q${(i + 1).toString().padLeft(3, '0')}',
    text: 'Quote ${i + 1}',
    author: null,
  ),
);

// ---------------------------------------------------------------------------
// Test app builder
//
// Creates a minimal MaterialApp with providers wired and HomeScreen as home.
// Routes are defined to match the production app_bootstrap.dart routes.
//
// CRITICAL: MultiProvider must wrap MaterialApp (not be inside home:) so that
// named-route pushes can access all providers. This matches production
// bootstrap ordering in app_bootstrap.dart.
// ---------------------------------------------------------------------------

Widget _createTestApp() {
  final repo = _InMemoryQuoteRepository(_testQuotes);
  final quoteService = QuoteService(repo);
  final favoritesService = FavoritesService(repo);
  final notificationService = _MockNotificationService();

  return MultiProvider(
    providers: [
      ChangeNotifierProvider(
        create: (_) => QuoteProvider(quoteService),
      ),
      ChangeNotifierProvider(
        create: (_) => FavoritesProvider(favoritesService),
      ),
      ChangeNotifierProvider(
        create: (_) => QuoteCatalogProvider(repo),
      ),
      // Expose NotificationService for SettingsScreen access
      Provider<NotificationServiceBase>.value(value: notificationService),
    ],
    child: MaterialApp(
      home: const HomeScreen(),
      routes: {
        '/favorites': (context) => const FavoritesScreen(),
        '/settings': (context) => const SettingsScreen(),
        '/quotes': (context) => const QuoteCatalogScreen(),
      },
    ),
  );
}

// ---------------------------------------------------------------------------
// Finder helpers
// ---------------------------------------------------------------------------

/// Finds the BottomNavigationBar in HomeScreen.
Finder _bottomNavBar() => find.byType(BottomNavigationBar);

/// Finds a BottomNavigationBarItem by its label text.
Finder _navItemByLabel(String label) => find.descendant(
      of: _bottomNavBar(),
      matching: find.text(label),
    );

void main() {
  setUp(() async {
    // Stub SharedPreferences so FavoritesProvider loads an empty list.
    SharedPreferences.setMockInitialValues({});
  });

  // -------------------------------------------------------------------------
  // AC 1: Bottom navigation shows four top-level tabs
  // -------------------------------------------------------------------------

  group('AC: Bottom navigation has four tabs', () {
    testWidgets(
      'BottomNavigationBar has exactly 4 items',
      (WidgetTester tester) async {
        // Arrange
        await tester.pumpWidget(_createTestApp());
        await tester.pumpAndSettle();

        // Assert — FAILS until coder adds 4th item (currently has 3)
        final bottomNavBar =
            tester.widget<BottomNavigationBar>(_bottomNavBar());
        expect(
          bottomNavBar.items.length,
          equals(4),
          reason: 'BottomNavigationBar must have exactly 4 items: '
              'Home, Quotes, Favorites, Settings',
        );
      },
    );

    testWidgets(
      'BottomNavigationBar items are labeled Home, Quotes, Favorites, Settings '
      'in that order',
      (WidgetTester tester) async {
        // Arrange
        await tester.pumpWidget(_createTestApp());
        await tester.pumpAndSettle();

        // Assert — FAILS until coder adds Quotes at index 1 and shifts others
        final bottomNavBar =
            tester.widget<BottomNavigationBar>(_bottomNavBar());
        final labels = bottomNavBar.items.map((item) => item.label).toList();

        expect(
          labels[0],
          equals('Home'),
          reason: 'First tab must be labeled "Home"',
        );
        expect(
          labels[1],
          equals('Quotes'),
          reason: 'Second tab must be labeled "Quotes" (new tab at index 1)',
        );
        expect(
          labels[2],
          equals('Favorites'),
          reason: 'Third tab must be labeled "Favorites" (shifted from index 1 '
              'to 2)',
        );
        expect(
          labels[3],
          equals('Settings'),
          reason: 'Fourth tab must be labeled "Settings" (shifted from index 2 '
              'to 3)',
        );
      },
    );
  });

  // -------------------------------------------------------------------------
  // AC 2: Selecting the Quotes tab opens the Quote Catalog screen
  // -------------------------------------------------------------------------

  group('AC: Quotes tab opens QuoteCatalogScreen', () {
    testWidgets(
      'tapping Quotes tab (index 1) navigates to QuoteCatalogScreen',
      (WidgetTester tester) async {
        // Arrange
        await tester.pumpWidget(_createTestApp());
        await tester.pumpAndSettle();

        // Pre-condition: QuoteCatalogScreen is not present
        expect(
          find.byType(QuoteCatalogScreen),
          findsNothing,
          reason: 'QuoteCatalogScreen should not be visible before tap',
        );

        // Act: Tap the Quotes tab (should be index 1 after implementation)
        // Note: We tap by finding the Quotes label, not by index, to test the
        // behavioral contract rather than implementation details.
        final quotesTab = _navItemByLabel('Quotes');

        // This will FAIL if Quotes tab doesn't exist yet
        expect(
          quotesTab,
          findsWidgets,
          reason: 'Quotes tab must exist to be tapped',
        );

        // Find the BottomNavigationBar and tap at the Quotes position
        // We need to tap the actual nav bar at the correct location
        await tester.tap(quotesTab.first);
        await tester.pumpAndSettle();

        // Assert — QuoteCatalogScreen is now visible
        expect(
          find.byType(QuoteCatalogScreen),
          findsOneWidget,
          reason: 'Tapping Quotes tab must navigate to QuoteCatalogScreen',
        );
      },
    );
  });

  // -------------------------------------------------------------------------
  // AC 3: Existing Home, Favorites, and Settings destinations remain reachable
  // -------------------------------------------------------------------------

  group('AC: Existing tabs remain reachable (no regression)', () {
    testWidgets(
      'tapping Home tab (index 0) stays on HomeScreen',
      (WidgetTester tester) async {
        // Arrange
        await tester.pumpWidget(_createTestApp());
        await tester.pumpAndSettle();

        // Assert: HomeScreen is visible
        expect(
          find.byType(HomeScreen),
          findsOneWidget,
          reason: 'HomeScreen should be visible at app start',
        );

        // Act: Tap Home tab (should be a no-op since already on Home)
        final homeTab = _navItemByLabel('Home');
        await tester.tap(homeTab);
        await tester.pumpAndSettle();

        // Assert: Still on HomeScreen
        expect(
          find.byType(HomeScreen),
          findsOneWidget,
          reason: 'Tapping Home tab should stay on HomeScreen',
        );
      },
    );

    testWidgets(
      'tapping Favorites tab navigates to FavoritesScreen',
      (WidgetTester tester) async {
        // Arrange
        await tester.pumpWidget(_createTestApp());
        await tester.pumpAndSettle();

        // Pre-condition: FavoritesScreen is not present
        expect(
          find.byType(FavoritesScreen),
          findsNothing,
          reason: 'FavoritesScreen should not be visible before tap',
        );

        // Act: Tap the Favorites tab
        final favoritesTab = _navItemByLabel('Favorites');
        await tester.tap(favoritesTab);
        await tester.pumpAndSettle();

        // Assert — FavoritesScreen is now visible
        expect(
          find.byType(FavoritesScreen),
          findsOneWidget,
          reason: 'Tapping Favorites tab must navigate to FavoritesScreen '
              '(regression: this was case 1, should now be case 2)',
        );
      },
    );

    testWidgets(
      'tapping Settings tab navigates to SettingsScreen',
      (WidgetTester tester) async {
        // Arrange
        await tester.pumpWidget(_createTestApp());
        await tester.pumpAndSettle();

        // Pre-condition: SettingsScreen is not present
        expect(
          find.byType(SettingsScreen),
          findsNothing,
          reason: 'SettingsScreen should not be visible before tap',
        );

        // Act: Tap the Settings tab
        final settingsTab = _navItemByLabel('Settings');
        await tester.tap(settingsTab);
        await tester.pumpAndSettle();

        // Assert — SettingsScreen is now visible
        expect(
          find.byType(SettingsScreen),
          findsOneWidget,
          reason: 'Tapping Settings tab must navigate to SettingsScreen '
              '(regression: this was case 2, should now be case 3)',
        );
      },
    );
  });

  // -------------------------------------------------------------------------
  // AC 4: Navigation update does not regress random quote journey or settings
  // (Covered by existing tests in home_screen_quote_flow_test.dart and
  // settings_screen_test.dart)
  //
  // Note: Per enrichment guidance, tests should NOT require tab-highlight
  // persistence after push. We only verify navigation succeeded, not
  // currentIndex state.
  // -------------------------------------------------------------------------

  group('AC: Navigation succeeds without tab-highlight persistence', () {
    testWidgets(
      'navigating to Quotes succeeds (tab highlight not verified)',
      (WidgetTester tester) async {
        // Arrange
        await tester.pumpWidget(_createTestApp());
        await tester.pumpAndSettle();

        // Act: Tap Quotes tab
        final quotesTab = _navItemByLabel('Quotes');
        await tester.tap(quotesTab.first);
        await tester.pumpAndSettle();

        // Assert: QuoteCatalogScreen is visible
        // Note: We do NOT check currentIndex per enrichment guidance
        // that tab-highlight persistence after push is not required.
        expect(
          find.byType(QuoteCatalogScreen),
          findsOneWidget,
          reason: 'Tapping Quotes tab must navigate to QuoteCatalogScreen',
        );
      },
    );

    testWidgets(
      'navigating to Favorites succeeds (tab highlight not verified)',
      (WidgetTester tester) async {
        // Arrange
        await tester.pumpWidget(_createTestApp());
        await tester.pumpAndSettle();

        // Act: Tap Favorites tab
        final favoritesTab = _navItemByLabel('Favorites');
        await tester.tap(favoritesTab);
        await tester.pumpAndSettle();

        // Assert: FavoritesScreen is visible
        // Note: We do NOT check currentIndex per enrichment guidance
        // that tab-highlight persistence after push is not required.
        expect(
          find.byType(FavoritesScreen),
          findsOneWidget,
          reason: 'Tapping Favorites tab must navigate to FavoritesScreen',
        );
      },
    );

    testWidgets(
      'navigating to Settings succeeds (tab highlight not verified)',
      (WidgetTester tester) async {
        // Arrange
        await tester.pumpWidget(_createTestApp());
        await tester.pumpAndSettle();

        // Act: Tap Settings tab
        final settingsTab = _navItemByLabel('Settings');
        await tester.tap(settingsTab);
        await tester.pumpAndSettle();

        // Assert: SettingsScreen is visible
        // Note: We do NOT check currentIndex per enrichment guidance
        // that tab-highlight persistence after push is not required.
        expect(
          find.byType(SettingsScreen),
          findsOneWidget,
          reason: 'Tapping Settings tab must navigate to SettingsScreen',
        );
      },
    );
  });

  // -------------------------------------------------------------------------
  // Icon specification tests (from sprint-crud-quotes-ui.md)
  // -------------------------------------------------------------------------

  group('AC: Tab icons match specification', () {
    testWidgets(
      'Quotes tab uses format_quote icons (outlined inactive, filled active)',
      (WidgetTester tester) async {
        // Arrange
        await tester.pumpWidget(_createTestApp());
        await tester.pumpAndSettle();

        // Get the BottomNavigationBar widget
        final bottomNavBar =
            tester.widget<BottomNavigationBar>(_bottomNavBar());

        // Quotes should be at index 1
        // Note: We check that the item exists and has the correct icon type
        // The icon field is BottomNavigationBarItem which has icon and activeIcon
        expect(
          bottomNavBar.items.length,
          greaterThanOrEqualTo(2),
          reason: 'Need at least 2 items to check index 1',
        );

        // This test will FAIL if Quotes tab doesn't exist yet
        // After implementation, index 1 should be Quotes
        final quotesItem = bottomNavBar.items[1];

        // Check the icon is Icons.format_quote_outlined (inactive)
        final inactiveIcon = quotesItem.icon as Icon;
        expect(
          inactiveIcon.icon,
          equals(Icons.format_quote_outlined),
          reason:
              'Quotes tab inactive icon must be Icons.format_quote_outlined',
        );

        // Check the activeIcon is Icons.format_quote (filled)
        final activeIcon = quotesItem.activeIcon as Icon;
        expect(
          activeIcon.icon,
          equals(Icons.format_quote),
          reason: 'Quotes tab active icon must be Icons.format_quote',
        );
      },
    );
  });
}
