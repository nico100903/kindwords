// ignore_for_file: require_trailing_commas, always_declare_return_types
//
// Task 02.02 — Failing widget tests for the HomeScreen save/unsave button.
//
// ALL tests in this file are expected to FAIL until the coder adds:
//   • FavoritesProvider wiring in HomeScreen
//   • An IconButton with Icons.favorite_outline / Icons.favorite in the AppBar
//
// DO NOT fix these tests. They are the contract.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kindwords/screens/home_screen.dart';
import 'package:kindwords/providers/quote_provider.dart';
import 'package:kindwords/providers/favorites_provider.dart';
import 'package:kindwords/services/quote_service.dart';
import 'package:kindwords/services/favorites_service.dart';
import 'package:kindwords/repositories/quote_repository.dart';
import 'package:kindwords/models/quote.dart';

// ---------------------------------------------------------------------------
// In-memory test repository (mirrors home_screen_quote_flow_test.dart pattern)
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
// Wires both QuoteProvider and FavoritesProvider. SharedPreferences is stubbed
// with setMockInitialValues({}) so FavoritesProvider._loadFavorites() returns
// an empty list without touching the real device storage.
// ---------------------------------------------------------------------------

/// Holds references to the providers so tests can introspect state directly.
QuoteProvider? _testQuoteProvider;
FavoritesProvider? _testFavoritesProvider;

/// A controllable repository whose [getAllQuotes] only resolves when
/// [completer] is completed. Used to hold [QuoteProvider._initialize()]
/// in the pending state so null-safety tests can observe the pre-load frame.
class _BlockingQuoteRepository implements QuoteRepositoryBase {
  final Completer<List<Quote>> completer;
  _BlockingQuoteRepository(this.completer);

  @override
  Future<List<Quote>> getAllQuotes() => completer.future;

  @override
  Future<Quote?> getById(String id) async => null;

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

/// Creates a full [MaterialApp] with both providers wired, ready for pumping.
Widget _createTestHomeApp() {
  final repo = _InMemoryQuoteRepository(_testQuotes);
  final quoteService = QuoteService(repo);
  final favoritesService = FavoritesService(repo);

  _testQuoteProvider = QuoteProvider(quoteService);
  _testFavoritesProvider = FavoritesProvider(favoritesService);

  return MaterialApp(
    home: MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _testQuoteProvider!),
        ChangeNotifierProvider.value(value: _testFavoritesProvider!),
      ],
      child: const HomeScreen(),
    ),
  );
}

// ---------------------------------------------------------------------------
// Finder helpers
//
// The BottomNavigationBar already contains Icons.favorite_outline for the
// Favorites tab, so we must scope all heart-icon finders to the AppBar to
// avoid false positives from the nav bar.
// ---------------------------------------------------------------------------

/// Finds the save-button [IconButton] that lives inside the [AppBar].
///
/// The coder must place the save button in AppBar.actions with the semantic
/// label 'Save quote' (or 'Remove from favorites') so this finder resolves.
Finder _saveFavoriteButton() => find.descendant(
      of: find.byType(AppBar),
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is IconButton &&
            (widget.icon is Icon) &&
            ((widget.icon as Icon).icon == Icons.favorite_outline ||
                (widget.icon as Icon).icon == Icons.favorite),
        description: 'IconButton with heart icon in AppBar',
      ),
    );

void main() {
  setUp(() async {
    // Stub SharedPreferences so FavoritesProvider loads an empty list.
    SharedPreferences.setMockInitialValues({});
  });

  // -------------------------------------------------------------------------
  // AC 1: Save button exists on HomeScreen
  // -------------------------------------------------------------------------

  group('AC: Save button is present in the AppBar', () {
    testWidgets(
      'AppBar contains a heart IconButton (Icons.favorite_outline) when '
      'quote is loaded',
      (WidgetTester tester) async {
        // Arrange
        await tester.pumpWidget(_createTestHomeApp());
        await tester
            .pumpAndSettle(); // let QuoteProvider._initialize() complete

        // Assert — FAILS until coder adds the save IconButton to AppBar.actions
        expect(
          _saveFavoriteButton(),
          findsOneWidget,
          reason: 'HomeScreen AppBar must contain an IconButton with a heart '
              'icon (Icons.favorite_outline) for the save-quote action',
        );
      },
    );
  });

  // -------------------------------------------------------------------------
  // AC 2: Icon reflects favorited state — outline when not saved, filled when saved
  // -------------------------------------------------------------------------

  group('AC: Heart icon reflects favorite state', () {
    testWidgets(
      'heart icon is outline (Icons.favorite_outline) when the current quote '
      'is NOT a favorite',
      (WidgetTester tester) async {
        // Arrange: empty favorites (default SharedPreferences stub)
        await tester.pumpWidget(_createTestHomeApp());
        await tester.pumpAndSettle();

        // The current quote is loaded; it has not been saved yet.
        // Assert: outline variant is shown
        final iconInAppBar = find.descendant(
          of: find.byType(AppBar),
          matching: find.byIcon(Icons.favorite_outline),
        );
        expect(
          iconInAppBar,
          findsOneWidget,
          reason: 'Heart icon must show Icons.favorite_outline when the quote '
              'is not in favorites',
        );
      },
    );

    testWidgets(
      'heart icon is filled (Icons.favorite) when the current quote IS a favorite',
      (WidgetTester tester) async {
        // Arrange: pump the widget tree
        await tester.pumpWidget(_createTestHomeApp());
        await tester.pumpAndSettle();

        // Pre-condition: ensure a quote is loaded
        final quoteProvider = _testQuoteProvider!;
        expect(quoteProvider.currentQuote, isNotNull);
        final quote = quoteProvider.currentQuote!;

        // Add the current quote to favorites directly via the provider
        final favoritesProvider = _testFavoritesProvider!;
        await favoritesProvider.addFavorite(quote);
        await tester.pumpAndSettle(); // let the rebuild propagate

        // Assert: filled heart variant is shown in AppBar
        final filledIconInAppBar = find.descendant(
          of: find.byType(AppBar),
          matching: find.byIcon(Icons.favorite),
        );
        expect(
          filledIconInAppBar,
          findsOneWidget,
          reason: 'Heart icon must switch to Icons.favorite (filled) when the '
              'current quote is already in favorites',
        );
      },
    );
  });

  // -------------------------------------------------------------------------
  // AC 3: Tapping the button calls toggleFavorite (adds when not present)
  // -------------------------------------------------------------------------

  group('AC: Tapping save button toggles favorite state', () {
    testWidgets(
      'tapping heart icon once adds the current quote to favorites',
      (WidgetTester tester) async {
        // Arrange
        await tester.pumpWidget(_createTestHomeApp());
        await tester.pumpAndSettle();

        final quoteProvider = _testQuoteProvider!;
        final favoritesProvider = _testFavoritesProvider!;
        expect(quoteProvider.currentQuote, isNotNull);
        final quote = quoteProvider.currentQuote!;
        expect(favoritesProvider.isFavorite(quote), isFalse);

        // Act: tap the save button
        await tester.tap(_saveFavoriteButton());
        await tester.pumpAndSettle();

        // Assert: quote is now a favorite
        expect(
          favoritesProvider.isFavorite(quote),
          isTrue,
          reason: 'Tapping the save button must add the current quote to '
              'favorites',
        );
      },
    );

    testWidgets(
      'heart icon shows filled state after tapping once',
      (WidgetTester tester) async {
        // Arrange
        await tester.pumpWidget(_createTestHomeApp());
        await tester.pumpAndSettle();

        // Act: tap save
        await tester.tap(_saveFavoriteButton());
        await tester.pumpAndSettle();

        // Assert: icon has switched to filled
        final filledIconInAppBar = find.descendant(
          of: find.byType(AppBar),
          matching: find.byIcon(Icons.favorite),
        );
        expect(
          filledIconInAppBar,
          findsOneWidget,
          reason: 'After tapping save, the heart icon must become '
              'Icons.favorite (filled)',
        );
      },
    );

    testWidgets(
      'tapping the heart icon a second time removes the quote from favorites',
      (WidgetTester tester) async {
        // Arrange
        await tester.pumpWidget(_createTestHomeApp());
        await tester.pumpAndSettle();

        final quoteProvider = _testQuoteProvider!;
        final favoritesProvider = _testFavoritesProvider!;
        final quote = quoteProvider.currentQuote!;

        // First tap: add
        await tester.tap(_saveFavoriteButton());
        await tester.pumpAndSettle();
        expect(favoritesProvider.isFavorite(quote), isTrue);

        // Second tap: remove
        await tester.tap(_saveFavoriteButton());
        await tester.pumpAndSettle();

        // Assert: no longer a favorite
        expect(
          favoritesProvider.isFavorite(quote),
          isFalse,
          reason: 'Tapping the save button a second time must remove the quote '
              'from favorites (toggle behavior)',
        );
      },
    );

    testWidgets(
      'heart icon returns to outline after tapping twice',
      (WidgetTester tester) async {
        // Arrange
        await tester.pumpWidget(_createTestHomeApp());
        await tester.pumpAndSettle();

        // Tap twice (add then remove)
        await tester.tap(_saveFavoriteButton());
        await tester.pumpAndSettle();
        await tester.tap(_saveFavoriteButton());
        await tester.pumpAndSettle();

        // Assert: outline icon is back in AppBar
        final outlineIconInAppBar = find.descendant(
          of: find.byType(AppBar),
          matching: find.byIcon(Icons.favorite_outline),
        );
        expect(
          outlineIconInAppBar,
          findsOneWidget,
          reason: 'After two taps, the heart icon must revert to '
              'Icons.favorite_outline',
        );
      },
    );
  });

  // -------------------------------------------------------------------------
  // AC 4: Null-safety — button is disabled when currentQuote is null
  // -------------------------------------------------------------------------

  group('AC: Save button handles null currentQuote gracefully', () {
    testWidgets(
      'save button is absent before a quote loads',
      (WidgetTester tester) async {
        // Arrange: use a blocking repository so _initialize() never resolves
        // during this test — giving us a reliable pre-load state to inspect.
        final completer = Completer<List<Quote>>();
        final blockingRepo = _BlockingQuoteRepository(completer);
        final quoteService = QuoteService(blockingRepo);
        final favService =
            FavoritesService(_InMemoryQuoteRepository(_testQuotes));

        final quoteProvider = QuoteProvider(quoteService);
        final favProvider = FavoritesProvider(favService);

        await tester.pumpWidget(MaterialApp(
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider.value(value: quoteProvider),
              ChangeNotifierProvider.value(value: favProvider),
            ],
            child: const HomeScreen(),
          ),
        ));
        await tester.pump(); // one frame — _initialize() still blocked

        // Assert: button must be absent (SizedBox.shrink) when quote is null.
        expect(
          _saveFavoriteButton(),
          findsNothing,
          reason: 'Save button must not be rendered while currentQuote is null '
              '— absence prevents any null-check crash on tap',
        );

        // Clean up: resolve the completer so the provider disposes cleanly.
        completer.complete([]);
      },
    );

    testWidgets(
      'no exception is thrown when the widget tree is built with null quote',
      (WidgetTester tester) async {
        // Use a blocking repo to reliably observe the pre-load state.
        final completer = Completer<List<Quote>>();
        final blockingRepo = _BlockingQuoteRepository(completer);
        final quoteService = QuoteService(blockingRepo);
        final favService =
            FavoritesService(_InMemoryQuoteRepository(_testQuotes));

        await tester.pumpWidget(MaterialApp(
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider(
                  create: (_) => QuoteProvider(quoteService)),
              ChangeNotifierProvider(
                  create: (_) => FavoritesProvider(favService)),
            ],
            child: const HomeScreen(),
          ),
        ));
        await tester.pump(); // one frame — init still blocked

        // Assert: no exceptions from rendering HomeScreen with null quote
        expect(tester.takeException(), isNull,
            reason: 'HomeScreen must not throw when currentQuote is null');

        // Clean up
        completer.complete([]);
      },
    );
  });
}
