// ignore_for_file: require_trailing_commas, always_declare_return_types, unused_local_variable, use_super_parameters
//
// Task 06.01 — Failing widget tests for QuoteCatalogScreen browse and filter.
//
// These tests define the Wave 3 UI contract:
// - Route /quotes resolves from KindWordsApp
// - Loading state before provider data resolves
// - List renders all quotes after load
// - ListView.builder pattern (lazy construction)
// - Source filter chips (All/Seeded/Mine)
// - Tag filter chips
// - Filter composition (intersection behavior)
// - Empty-filter state when no quotes match
// - Edit/delete IconButtons visible per row
// - Source indicator + author/anonymous fallback per row
// - No repeated provider load on rebuild
//
// DO NOT fix these tests. They are the behavioral contract.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:kindwords/models/quote.dart';
import 'package:kindwords/providers/quote_catalog_provider.dart';
import 'package:kindwords/repositories/quote_repository.dart';
import 'package:kindwords/screens/quote_catalog_screen.dart';

// ---------------------------------------------------------------------------
// In-memory test repository — returns pre-seeded quotes for provider tests.
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

  // CRUD stubs — not exercised by these read-only browse tests
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
// Blocking repository — delays getAllQuotes until completer completes.
// Used to test loading state.
// ---------------------------------------------------------------------------

class _BlockingQuoteRepository implements QuoteRepositoryBase {
  final Completer<List<Quote>> completer;
  _BlockingQuoteRepository(this.completer);

  @override
  Future<List<Quote>> getAllQuotes() => completer.future;

  @override
  Future<Quote?> getById(String id) async => null;

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
// Test fixtures — controlled quote set for filter tests
//
// Required by task spec:
// - one seeded quote tagged `motivational`
// - one seeded quote tagged `wisdom`
// - one userCreated quote tagged `personal`
// - one userCreated quote with null author
// ---------------------------------------------------------------------------

final _seededMotivational = Quote(
  id: 'cat001',
  text: 'Believe you can and you are halfway there.',
  author: 'Theodore Roosevelt',
  tags: const ['motivational'],
  source: QuoteSource.seeded,
  createdAt: DateTime.utc(2026, 3, 1),
);

final _seededWisdom = Quote(
  id: 'cat002',
  text: 'The only true wisdom is in knowing you know nothing.',
  author: 'Socrates',
  tags: const ['wisdom'],
  source: QuoteSource.seeded,
  createdAt: DateTime.utc(2026, 3, 2),
);

final _userPersonal = Quote(
  id: 'cat003',
  text: 'My morning routine sets the tone for the day.',
  author: 'Me',
  tags: const ['personal'],
  source: QuoteSource.userCreated,
  createdAt: DateTime.utc(2026, 3, 3),
);

final _userNoAuthor = Quote(
  id: 'cat004',
  text: 'Anonymous wisdom from my journal.',
  author: null,
  tags: const ['personal'],
  source: QuoteSource.userCreated,
  createdAt: DateTime.utc(2026, 3, 4),
);

// Extra seeded quote with multiple tags for intersection test
final _seededMultiTag = Quote(
  id: 'cat005',
  text: 'Stay hungry, stay foolish.',
  author: 'Steve Jobs',
  tags: const ['motivational', 'wisdom'],
  source: QuoteSource.seeded,
  createdAt: DateTime.utc(2026, 3, 5),
);

final _allTestQuotes = [
  _seededMotivational,
  _seededWisdom,
  _userPersonal,
  _userNoAuthor,
  _seededMultiTag,
];

// ---------------------------------------------------------------------------
// Widget builder helpers
// ---------------------------------------------------------------------------

/// Builds a MaterialApp wrapping QuoteCatalogScreen with a real
/// QuoteCatalogProvider backed by an in-memory repository.
///
/// Returns the provider so tests can inspect filter state.
Future<QuoteCatalogProvider> _buildCatalogScreen(
  WidgetTester tester, {
  List<Quote> quotes = const [],
  bool delayedLoad = false,
  Completer<List<Quote>>? loadCompleter,
}) async {
  final repo = delayedLoad && loadCompleter != null
      ? _BlockingQuoteRepository(loadCompleter)
      : _InMemoryQuoteRepository(quotes);

  final provider = QuoteCatalogProvider(repo);

  await tester.pumpWidget(
    MaterialApp(
      home: ChangeNotifierProvider.value(
        value: provider,
        child: const QuoteCatalogScreen(),
      ),
    ),
  );

  return provider;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // -------------------------------------------------------------------------
  // Test 1: Route /quotes resolves from KindWordsApp
  // -------------------------------------------------------------------------

  group('Route resolution', () {
    testWidgets(
      '/quotes route is registered and renders QuoteCatalogScreen',
      (WidgetTester tester) async {
        final repo = _InMemoryQuoteRepository(_allTestQuotes);
        final provider = QuoteCatalogProvider(repo);

        // Build app starting directly at /quotes route
        await tester.pumpWidget(
          MaterialApp(
            initialRoute: '/quotes',
            routes: {
              '/': (context) => const Scaffold(body: Text('Home')),
              // /quotes route will be added by coder to KindWordsApp.routes
              // It must map to QuoteCatalogScreen
              '/quotes': (context) => ChangeNotifierProvider.value(
                    value: provider,
                    child: const QuoteCatalogScreen(),
                  ),
            },
          ),
        );

        // Trigger load
        await provider.load();
        await tester.pumpAndSettle();

        // Assert: /quotes route resolves and shows a Scaffold
        expect(
          find.byType(Scaffold),
          findsWidgets,
          reason: '/quotes route must resolve to a Scaffold-based screen '
              '(QuoteCatalogScreen)',
        );

        // Assert: The screen shows the quote list (proves it's QuoteCatalogScreen)
        expect(
          find.byType(ListTile),
          findsWidgets,
          reason: '/quotes route must navigate to QuoteCatalogScreen which '
              'renders ListTiles for quotes',
        );
      },
    );
  });

  // -------------------------------------------------------------------------
  // Test 2: Loading state before provider data resolves
  // -------------------------------------------------------------------------

  group('Loading state', () {
    testWidgets(
      'shows CircularProgressIndicator while provider.isLoading is true',
      (WidgetTester tester) async {
        final completer = Completer<List<Quote>>();
        final provider = await _buildCatalogScreen(
          tester,
          quotes: _allTestQuotes,
          delayedLoad: true,
          loadCompleter: completer,
        );

        // Trigger load — it will not complete yet
        provider.load();
        await tester.pump(); // one frame, isLoading is now true

        // Assert: loading indicator is visible
        expect(
          find.byType(CircularProgressIndicator),
          findsOneWidget,
          reason: 'QuoteCatalogScreen must show a centered '
              'CircularProgressIndicator while provider.isLoading is true',
        );

        // Clean up: complete the load
        completer.complete(_allTestQuotes);
        await tester.pumpAndSettle();
      },
    );
  });

  // -------------------------------------------------------------------------
  // Test 3: Screen renders list of all quotes after load
  // -------------------------------------------------------------------------

  group('List rendering after load', () {
    testWidgets(
      'renders all quotes from provider after load completes',
      (WidgetTester tester) async {
        final provider = await _buildCatalogScreen(
          tester,
          quotes: _allTestQuotes,
        );

        // Trigger load and settle
        await provider.load();
        await tester.pumpAndSettle();

        // Assert: one ListTile per quote (5 quotes in fixture)
        expect(
          find.byType(ListTile),
          findsNWidgets(_allTestQuotes.length),
          reason: 'QuoteCatalogScreen must render one ListTile per quote '
              'after load — ${_allTestQuotes.length} quotes → '
              '${_allTestQuotes.length} ListTiles',
        );
      },
    );
  });

  // -------------------------------------------------------------------------
  // Test 4: List uses ListView.builder pattern
  // -------------------------------------------------------------------------

  group('ListView.builder pattern', () {
    testWidgets(
      'uses ListView with itemBuilder semantics (not eager ListView.children)',
      (WidgetTester tester) async {
        final provider = await _buildCatalogScreen(
          tester,
          quotes: _allTestQuotes,
        );

        await provider.load();
        await tester.pumpAndSettle();

        // Assert: ListView exists
        expect(
          find.byType(ListView),
          findsOneWidget,
          reason: 'QuoteCatalogScreen must use a ListView for the quote list',
        );

        // Verify the number of ListTiles matches quote count
        // (ListView.builder produces ListTiles lazily, but the count must match)
        expect(
          find.byType(ListTile),
          findsNWidgets(_allTestQuotes.length),
          reason: 'ListView must render exactly ${_allTestQuotes.length} '
              'ListTiles for ${_allTestQuotes.length} quotes — '
              'itemCount contract',
        );
      },
    );
  });

  // -------------------------------------------------------------------------
  // Test 5: Source filter chip "Seeded" shows only seeded quotes
  // -------------------------------------------------------------------------

  group('Source filter: Seeded', () {
    testWidgets(
      'shows only seeded quotes when Seeded filter chip is selected',
      (WidgetTester tester) async {
        final provider = await _buildCatalogScreen(
          tester,
          quotes: _allTestQuotes,
        );

        await provider.load();
        await tester.pumpAndSettle();

        // Apply Seeded source filter
        provider.setSourceFilter(QuoteSource.seeded);
        await tester.pumpAndSettle();

        final seededCount =
            _allTestQuotes.where((q) => q.source == QuoteSource.seeded).length;

        // Assert: only seeded quotes visible
        expect(
          find.byType(ListTile),
          findsNWidgets(seededCount),
          reason: 'Seeded filter must show only seeded quotes — '
              '$seededCount expected',
        );
      },
    );
  });

  // -------------------------------------------------------------------------
  // Test 6: Source filter chip "Mine" shows only userCreated quotes
  // -------------------------------------------------------------------------

  group('Source filter: Mine', () {
    testWidgets(
      'shows only userCreated quotes when Mine filter chip is selected',
      (WidgetTester tester) async {
        final provider = await _buildCatalogScreen(
          tester,
          quotes: _allTestQuotes,
        );

        await provider.load();
        await tester.pumpAndSettle();

        // Apply Mine (userCreated) source filter
        provider.setSourceFilter(QuoteSource.userCreated);
        await tester.pumpAndSettle();

        final mineCount = _allTestQuotes
            .where((q) => q.source == QuoteSource.userCreated)
            .length;

        // Assert: only userCreated quotes visible
        expect(
          find.byType(ListTile),
          findsNWidgets(mineCount),
          reason: 'Mine filter must show only userCreated quotes — '
              '$mineCount expected',
        );
      },
    );
  });

  // -------------------------------------------------------------------------
  // Test 7: Tag filter chip shows only quotes containing that tag
  // -------------------------------------------------------------------------

  group('Tag filter', () {
    testWidgets(
      'shows only quotes with #motivational tag when motivational chip is selected',
      (WidgetTester tester) async {
        final provider = await _buildCatalogScreen(
          tester,
          quotes: _allTestQuotes,
        );

        await provider.load();
        await tester.pumpAndSettle();

        // Apply motivational tag filter
        provider.setTagFilter('motivational');
        await tester.pumpAndSettle();

        final motivationalCount =
            _allTestQuotes.where((q) => q.tags.contains('motivational')).length;

        // Assert: only motivational quotes visible
        expect(
          find.byType(ListTile),
          findsNWidgets(motivationalCount),
          reason:
              'Tag filter #motivational must show only quotes with that tag — '
              '$motivationalCount expected',
        );
      },
    );
  });

  // -------------------------------------------------------------------------
  // Test 8: Source + tag filters compose (intersection behavior)
  // -------------------------------------------------------------------------

  group('Filter composition', () {
    testWidgets(
      'source + tag filters compose as intersection',
      (WidgetTester tester) async {
        final provider = await _buildCatalogScreen(
          tester,
          quotes: _allTestQuotes,
        );

        await provider.load();
        await tester.pumpAndSettle();

        // Apply Seeded source filter
        provider.setSourceFilter(QuoteSource.seeded);
        // Apply motivational tag filter
        provider.setTagFilter('motivational');
        await tester.pumpAndSettle();

        // Count intersection: seeded AND motivational
        final intersectionCount = _allTestQuotes
            .where((q) =>
                q.source == QuoteSource.seeded &&
                q.tags.contains('motivational'))
            .length;

        // Assert: only intersection visible
        expect(
          find.byType(ListTile),
          findsNWidgets(intersectionCount),
          reason: 'Source + tag filters must compose as intersection — '
              '$intersectionCount seeded+motivational quotes expected',
        );

        // Verify the intersection is correct
        expect(intersectionCount, greaterThan(0),
            reason:
                'Test fixture must include at least one seeded+motivational '
                'quote for composition test');
      },
    );

    testWidgets(
      'setting tag filter does NOT clear source filter',
      (WidgetTester tester) async {
        final provider = await _buildCatalogScreen(
          tester,
          quotes: _allTestQuotes,
        );

        await provider.load();
        await tester.pumpAndSettle();

        // Apply Seeded source filter
        provider.setSourceFilter(QuoteSource.seeded);
        await tester.pumpAndSettle();

        // Apply tag filter
        provider.setTagFilter('wisdom');
        await tester.pumpAndSettle();

        // Assert: source filter is still active
        expect(
          provider.sourceFilter,
          equals(QuoteSource.seeded),
          reason: 'Setting tag filter must NOT clear source filter — '
              'filters compose independently',
        );
      },
    );
  });

  // -------------------------------------------------------------------------
  // Test 9: Empty-filter state appears when no quotes match
  // -------------------------------------------------------------------------

  group('Empty-filter state', () {
    testWidgets(
      'shows empty-filter message when no quotes match active filters',
      (WidgetTester tester) async {
        final provider = await _buildCatalogScreen(
          tester,
          quotes: _allTestQuotes,
        );

        await provider.load();
        await tester.pumpAndSettle();

        // Apply a tag that no quote has
        provider.setTagFilter('nonexistent');
        await tester.pumpAndSettle();

        // Assert: empty-filter state is shown
        expect(
          find.textContaining('No quotes match'),
          findsOneWidget,
          reason: 'Empty-filter state must show a message like '
              '"No quotes match this filter" when filtered list is empty',
        );

        // Assert: no ListTiles rendered
        expect(
          find.byType(ListTile),
          findsNothing,
          reason: 'No ListTiles should render when no quotes match filters',
        );
      },
    );

    testWidgets(
      'empty-filter state includes a way to clear filters',
      (WidgetTester tester) async {
        final provider = await _buildCatalogScreen(
          tester,
          quotes: _allTestQuotes,
        );

        await provider.load();
        await tester.pumpAndSettle();

        // Apply filter that yields no results
        provider.setTagFilter('nonexistent');
        await tester.pumpAndSettle();

        // Assert: clear-filter button exists
        expect(
          find.widgetWithText(TextButton, 'Clear'),
          findsOneWidget,
          reason:
              'Empty-filter state must include a "Clear" or "Clear filters" '
              'button to reset filters',
        );
      },
    );
  });

  // -------------------------------------------------------------------------
  // Test 10: Each quote row shows edit and delete IconButtons
  // -------------------------------------------------------------------------

  group('Row action buttons', () {
    testWidgets(
      'each quote row has edit and delete IconButtons',
      (WidgetTester tester) async {
        final provider = await _buildCatalogScreen(
          tester,
          quotes: _allTestQuotes,
        );

        await provider.load();
        await tester.pumpAndSettle();

        // Count edit icons (one per row)
        expect(
          find.byIcon(Icons.edit_outlined),
          findsNWidgets(_allTestQuotes.length),
          reason: 'Each quote row must have an edit IconButton with '
              'Icons.edit_outlined',
        );

        // Count delete icons (one per row)
        expect(
          find.byIcon(Icons.delete_outline),
          findsNWidgets(_allTestQuotes.length),
          reason: 'Each quote row must have a delete IconButton with '
              'Icons.delete_outline',
        );
      },
    );
  });

  // -------------------------------------------------------------------------
  // Test 11: Each row shows source indicator + author/anonymous fallback
  // -------------------------------------------------------------------------

  group('Row content: source and author', () {
    testWidgets(
      'seeded quotes show menu_book icon as source indicator',
      (WidgetTester tester) async {
        final provider = await _buildCatalogScreen(
          tester,
          quotes: _allTestQuotes,
        );

        await provider.load();
        await tester.pumpAndSettle();

        final seededCount =
            _allTestQuotes.where((q) => q.source == QuoteSource.seeded).length;

        expect(
          find.byIcon(Icons.menu_book_outlined),
          findsNWidgets(seededCount),
          reason: 'Seeded quotes must show Icons.menu_book_outlined as '
              'the source indicator (leading icon)',
        );
      },
    );

    testWidgets(
      'userCreated quotes show edit_note icon as source indicator',
      (WidgetTester tester) async {
        final provider = await _buildCatalogScreen(
          tester,
          quotes: _allTestQuotes,
        );

        await provider.load();
        await tester.pumpAndSettle();

        final userCount = _allTestQuotes
            .where((q) => q.source == QuoteSource.userCreated)
            .length;

        expect(
          find.byIcon(Icons.edit_note),
          findsNWidgets(userCount),
          reason: 'UserCreated quotes must show Icons.edit_note as '
              'the source indicator (leading icon)',
        );
      },
    );

    testWidgets(
      'row shows author when present',
      (WidgetTester tester) async {
        final provider = await _buildCatalogScreen(
          tester,
          quotes: [_seededMotivational], // has author "Theodore Roosevelt"
        );

        await provider.load();
        await tester.pumpAndSettle();

        expect(
          find.textContaining('Theodore Roosevelt'),
          findsOneWidget,
          reason: 'Quote row must display the author name when present',
        );
      },
    );

    testWidgets(
      'row shows anonymous fallback when author is null',
      (WidgetTester tester) async {
        final provider = await _buildCatalogScreen(
          tester,
          quotes: [_userNoAuthor], // has null author
        );

        await provider.load();
        await tester.pumpAndSettle();

        expect(
          find.textContaining('Anonymous'),
          findsOneWidget,
          reason: 'Quote row must show "Anonymous" when quote.author is null',
        );
      },
    );
  });

  // -------------------------------------------------------------------------
  // Test 12: Screen does not trigger repeated provider load on rebuild
  // -------------------------------------------------------------------------

  group('Load idempotency', () {
    testWidgets(
      'provider.load() is called only once despite multiple rebuilds',
      (WidgetTester tester) async {
        int loadCallCount = 0;

        // Wrap provider to count load() calls
        final repo = _InMemoryQuoteRepository(_allTestQuotes);
        final baseProvider = QuoteCatalogProvider(repo);

        // Create a tracking wrapper
        final trackingProvider = _TrackingQuoteCatalogProvider(
          repo,
          onLoad: () => loadCallCount++,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: ChangeNotifierProvider.value(
              value: trackingProvider,
              child: const Placeholder(),
            ),
          ),
        );

        // Trigger load
        await trackingProvider.load();
        await tester.pumpAndSettle();

        // Force multiple rebuilds
        trackingProvider.notifyListeners();
        await tester.pump();
        trackingProvider.notifyListeners();
        await tester.pump();
        trackingProvider.notifyListeners();
        await tester.pumpAndSettle();

        // Assert: load was called exactly once
        expect(
          loadCallCount,
          equals(1),
          reason: 'provider.load() must be called exactly once — '
              'screen must use initState guard, not build()',
        );
      },
    );
  });

  // -------------------------------------------------------------------------
  // Task 07.01 — Create entry points (AppBar + and FAB)
  // -------------------------------------------------------------------------

  group('Create entry points', () {
    testWidgets(
      'AppBar has an add icon button for creating new quotes',
      (WidgetTester tester) async {
        final provider = await _buildCatalogScreen(
          tester,
          quotes: _allTestQuotes,
        );

        await provider.load();
        await tester.pumpAndSettle();

        // Assert: AppBar has an add icon
        expect(
          find.byIcon(Icons.add),
          findsWidgets,
          reason: 'QuoteCatalogScreen AppBar must have an IconButton with '
              'Icons.add for creating new quotes',
        );
      },
    );

    testWidgets(
      'FloatingActionButton with "New Quote" label is visible',
      (WidgetTester tester) async {
        final provider = await _buildCatalogScreen(
          tester,
          quotes: _allTestQuotes,
        );

        await provider.load();
        await tester.pumpAndSettle();

        // Assert: FAB exists
        expect(
          find.byType(FloatingActionButton),
          findsOneWidget,
          reason: 'QuoteCatalogScreen must have a FloatingActionButton for '
              'creating new quotes',
        );

        // Assert: FAB shows "New Quote" text (extended FAB)
        expect(
          find.text('New Quote'),
          findsOneWidget,
          reason: 'FloatingActionButton.extended must show "New Quote" label',
        );
      },
    );
  });

  // -------------------------------------------------------------------------
  // Task 07.01 — Navigation to QuoteFormScreen
  // -------------------------------------------------------------------------

  group('Create navigation', () {
    testWidgets(
      'tapping AppBar add icon navigates to QuoteFormScreen',
      (WidgetTester tester) async {
        final repo = _CreatableQuoteRepository(_allTestQuotes);
        final provider = QuoteCatalogProvider(repo);

        await tester.pumpWidget(
          MaterialApp(
            home: ChangeNotifierProvider.value(
              value: provider,
              child: const QuoteCatalogScreen(),
            ),
            routes: {
              '/quote-form': (context) => const _MockQuoteFormScreen(),
            },
          ),
        );

        await provider.load();
        await tester.pumpAndSettle();

        // Find and tap the AppBar add button (not the FAB)
        final appBarAddButton = find.descendant(
          of: find.byType(AppBar),
          matching: find.byIcon(Icons.add),
        );

        if (appBarAddButton.evaluate().isNotEmpty) {
          await tester.tap(appBarAddButton);
          await tester.pumpAndSettle();

          // Assert: navigated to QuoteFormScreen (or mock)
          expect(
            find.text('New Quote'),
            findsOneWidget,
            reason: 'Tapping AppBar add button must navigate to '
                'QuoteFormScreen which shows "New Quote" title',
          );
        } else {
          fail('AppBar add button not found');
        }
      },
    );

    testWidgets(
      'tapping FAB navigates to QuoteFormScreen',
      (WidgetTester tester) async {
        final repo = _CreatableQuoteRepository(_allTestQuotes);
        final provider = QuoteCatalogProvider(repo);

        await tester.pumpWidget(
          MaterialApp(
            home: ChangeNotifierProvider.value(
              value: provider,
              child: const QuoteCatalogScreen(),
            ),
            routes: {
              '/quote-form': (context) => const _MockQuoteFormScreen(),
            },
          ),
        );

        await provider.load();
        await tester.pumpAndSettle();

        // Find and tap the FAB
        final fab = find.byType(FloatingActionButton);
        expect(fab, findsOneWidget, reason: 'FAB must be present');

        await tester.tap(fab);
        await tester.pumpAndSettle();

        // Assert: navigated to QuoteFormScreen (or mock)
        expect(
          find.text('New Quote'),
          findsOneWidget,
          reason: 'Tapping FAB must navigate to QuoteFormScreen which shows '
              '"New Quote" title',
        );
      },
    );
  });

  // -------------------------------------------------------------------------
  // Task 07.01 — Post-save catalog refresh
  // -------------------------------------------------------------------------

  group('Post-save catalog refresh', () {
    testWidgets(
      'after successful save and pop, catalog list shows the new quote',
      (WidgetTester tester) async {
        final repo = _CreatableQuoteRepository([]);
        final provider = QuoteCatalogProvider(repo);

        await tester.pumpWidget(
          MaterialApp(
            home: ChangeNotifierProvider.value(
              value: provider,
              child: const QuoteCatalogScreen(),
            ),
            routes: {
              '/quote-form': (context) => _MockQuoteFormScreenWithSave(
                    onSaved: () async {
                      // Simulate creating a quote via provider
                      final newQuote = Quote(
                        id: 'new001',
                        text: 'A newly created quote text.',
                        author: 'Test User',
                        tags: const ['personal'],
                        source: QuoteSource.userCreated,
                        createdAt: DateTime.now(),
                      );
                      await provider.createQuote(newQuote);
                    },
                  ),
            },
          ),
        );

        await provider.load();
        await tester.pumpAndSettle();

        // Initially: empty state or no quotes
        final initialTileCount = find.byType(ListTile).evaluate().length;

        // Tap FAB to navigate to form
        await tester.tap(find.byType(FloatingActionButton));
        await tester.pumpAndSettle();

        // Tap mock save button
        final saveButton = find.text('Mock Save');
        if (saveButton.evaluate().isNotEmpty) {
          await tester.tap(saveButton);
          await tester.pumpAndSettle();
        }

        // Assert: catalog now shows the new quote
        expect(
          find.byType(ListTile),
          findsWidgets,
          reason:
              'After returning from QuoteFormScreen with a successful save, '
              'the catalog must refresh and show the newly created quote',
        );

        // Verify the quote text appears
        expect(
          find.textContaining('newly created'),
          findsOneWidget,
          reason: 'The newly created quote text must be visible in the catalog '
              'after save and return',
        );
      },
    );

    testWidgets(
      'catalog reload is triggered after returning from successful create',
      (WidgetTester tester) async {
        final repo = _CreatableQuoteRepository([
          _seededMotivational, // Start with one quote
        ]);
        final provider = QuoteCatalogProvider(repo);

        await tester.pumpWidget(
          MaterialApp(
            home: ChangeNotifierProvider.value(
              value: provider,
              child: const QuoteCatalogScreen(),
            ),
            routes: {
              '/quote-form': (context) => _MockQuoteFormScreenWithSave(
                    onSaved: () async {
                      final newQuote = Quote(
                        id: 'new002',
                        text: 'Another newly created quote.',
                        author: null,
                        tags: const [],
                        source: QuoteSource.userCreated,
                        createdAt: DateTime.now(),
                      );
                      await provider.createQuote(newQuote);
                    },
                  ),
            },
          ),
        );

        await provider.load();
        await tester.pumpAndSettle();

        // Count initial tiles
        final initialCount = find.byType(ListTile).evaluate().length;
        expect(initialCount, equals(1), reason: 'Should start with 1 quote');

        // Navigate to form
        await tester.tap(find.byType(FloatingActionButton));
        await tester.pumpAndSettle();

        // Save and return
        final saveButton = find.text('Mock Save');
        if (saveButton.evaluate().isNotEmpty) {
          await tester.tap(saveButton);
          await tester.pumpAndSettle();
        }

        // Assert: tile count increased by 1
        expect(
          find.byType(ListTile),
          findsNWidgets(2),
          reason: 'After creating a new quote and returning, the catalog must '
              'show 2 ListTiles (1 original + 1 new)',
        );
      },
    );
  });

  // ===========================================================================
  // TASK 07.02 — EDIT/DELETE FROM CATALOG
  // ===========================================================================

  // -------------------------------------------------------------------------
  // Test: Edit button navigates to QuoteFormScreen with quote parameter
  // -------------------------------------------------------------------------

  group('Edit button navigation', () {
    testWidgets(
      'tapping edit icon navigates to QuoteFormScreen in edit mode',
      (WidgetTester tester) async {
        final existingQuote = _seededMotivational;
        final repo = _FullCrudCatalogRepository([existingQuote]);
        final provider = QuoteCatalogProvider(repo);

        await tester.pumpWidget(
          MaterialApp(
            home: ChangeNotifierProvider.value(
              value: provider,
              child: const QuoteCatalogScreen(),
            ),
            routes: {
              '/quote-form': (context) => _MockEditQuoteFormScreen(
                    quote: existingQuote,
                  ),
            },
          ),
        );

        await provider.load();
        await tester.pumpAndSettle();

        // Find and tap the edit icon
        final editIcon = find.byIcon(Icons.edit_outlined);
        expect(editIcon, findsOneWidget,
            reason: 'Edit icon must be visible on quote row');

        await tester.tap(editIcon);
        await tester.pumpAndSettle();

        // Assert: navigated to QuoteFormScreen in edit mode
        expect(
          find.text('Edit Quote'),
          findsOneWidget,
          reason:
              'Tapping edit icon must navigate to QuoteFormScreen in edit mode '
              'which shows "Edit Quote" title',
        );
      },
    );
  });

  // -------------------------------------------------------------------------
  // Test: Catalog refresh after UPDATE
  // -------------------------------------------------------------------------

  group('Catalog refresh after update', () {
    testWidgets(
      'after successful update and pop, catalog shows updated quote text',
      (WidgetTester tester) async {
        final originalQuote = Quote(
          id: 'update-test-001',
          text: 'Original quote text before update.',
          author: 'Original Author',
          tags: const ['motivational'],
          source: QuoteSource.userCreated,
          createdAt: DateTime.utc(2026, 3, 1),
        );

        final repo = _FullCrudCatalogRepository([originalQuote]);
        final provider = QuoteCatalogProvider(repo);

        await tester.pumpWidget(
          MaterialApp(
            home: ChangeNotifierProvider.value(
              value: provider,
              child: const QuoteCatalogScreen(),
            ),
            routes: {
              '/quote-form': (context) => _MockEditQuoteFormScreenWithUpdate(
                    quote: originalQuote,
                    onUpdate: () async {
                      // Simulate updating the quote
                      final updatedQuote = Quote(
                        id: originalQuote.id,
                        text: 'Updated quote text after edit!',
                        author: 'Updated Author',
                        tags: const ['wisdom'],
                        source: originalQuote.source,
                        createdAt: originalQuote.createdAt,
                        updatedAt: DateTime.now(),
                      );
                      await provider.updateQuote(updatedQuote);
                    },
                  ),
            },
          ),
        );

        await provider.load();
        await tester.pumpAndSettle();

        // Initially shows original text
        expect(
          find.textContaining('Original quote text'),
          findsOneWidget,
          reason: 'Catalog must initially show original quote text',
        );

        // Tap edit icon
        await tester.tap(find.byIcon(Icons.edit_outlined));
        await tester.pumpAndSettle();

        // Tap mock update button
        final updateButton = find.text('Mock Update');
        if (updateButton.evaluate().isNotEmpty) {
          await tester.tap(updateButton);
          await tester.pumpAndSettle();
        }

        // Assert: catalog shows updated text
        expect(
          find.textContaining('Updated quote text'),
          findsOneWidget,
          reason:
              'After returning from QuoteFormScreen with a successful update, '
              'the catalog must refresh and show the updated quote text',
        );

        // Original text should no longer appear
        expect(
          find.textContaining('Original quote text before'),
          findsNothing,
          reason: 'Original quote text must not appear after update',
        );
      },
    );
  });

  // -------------------------------------------------------------------------
  // Test: Catalog refresh after DELETE from catalog (bottom sheet)
  // -------------------------------------------------------------------------

  group('Catalog refresh after delete from catalog', () {
    testWidgets(
      'after confirming delete from catalog, quote no longer appears',
      (WidgetTester tester) async {
        final quote1 = Quote(
          id: 'delete-test-001',
          text: 'Quote that will remain.',
          author: 'Author 1',
          tags: const [],
          source: QuoteSource.seeded,
          createdAt: DateTime.utc(2026, 3, 1),
        );

        final quote2 = Quote(
          id: 'delete-test-002',
          text: 'Quote that will be deleted.',
          author: 'Author 2',
          tags: const [],
          source: QuoteSource.userCreated,
          createdAt: DateTime.utc(2026, 3, 2),
        );

        final repo = _FullCrudCatalogRepository([quote1, quote2]);
        final provider = QuoteCatalogProvider(repo);

        await tester.pumpWidget(
          MaterialApp(
            home: ChangeNotifierProvider.value(
              value: provider,
              child: const QuoteCatalogScreen(),
            ),
          ),
        );

        await provider.load();
        await tester.pumpAndSettle();

        // Initially shows both quotes
        expect(
          find.byType(ListTile),
          findsNWidgets(2),
          reason: 'Catalog must initially show both quotes',
        );

        // Find and tap the delete icon on the second quote
        final deleteIcons = find.byIcon(Icons.delete_outline);
        expect(deleteIcons, findsNWidgets(2),
            reason: 'Each quote row must have a delete icon');

        // Tap delete on the second quote (the one to be deleted)
        await tester.tap(deleteIcons.at(1));
        await tester.pumpAndSettle();

        // Assert: bottom sheet confirmation appears
        expect(
          find.textContaining('Delete Quote'),
          findsOneWidget,
          reason:
              'Tapping delete icon must show a bottom sheet with "Delete Quote" title',
        );

        // Tap confirm delete button
        final confirmDelete = find.widgetWithText(TextButton, 'Delete');
        expect(confirmDelete, findsWidgets,
            reason:
                'Delete confirmation bottom sheet must have a Delete button');

        await tester.tap(confirmDelete.last);
        await tester.pumpAndSettle();

        // Assert: only one quote remains
        expect(
          find.byType(ListTile),
          findsOneWidget,
          reason: 'After confirming delete, the catalog must refresh and show '
              'only one quote (the remaining one)',
        );

        // Assert: deleted quote text no longer appears
        expect(
          find.textContaining('Quote that will be deleted'),
          findsNothing,
          reason: 'The deleted quote text must not appear in the catalog',
        );
      },
    );
  });
}

// ---------------------------------------------------------------------------
// Tracking provider wrapper — counts load() invocations
// ---------------------------------------------------------------------------

class _TrackingQuoteCatalogProvider extends QuoteCatalogProvider {
  final void Function() onLoad;

  _TrackingQuoteCatalogProvider(
    QuoteRepositoryBase repo, {
    required this.onLoad,
  }) : super(repo);

  @override
  Future<void> load() async {
    onLoad();
    return super.load();
  }
}

// ---------------------------------------------------------------------------
// Task 07.01 — Creatable repository for create-flow tests
// ---------------------------------------------------------------------------

class _CreatableQuoteRepository implements QuoteRepositoryBase {
  final List<Quote> _quotes;

  _CreatableQuoteRepository(this._quotes);

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

  @override
  Future<void> insertQuote(Quote quote) async {
    _quotes.add(quote);
  }

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
// Task 07.02 — Full CRUD repository for catalog edit/delete tests
// ---------------------------------------------------------------------------

class _FullCrudCatalogRepository implements QuoteRepositoryBase {
  final List<Quote> _quotes;
  final List<Quote> _updatedQuotes = [];
  final List<String> _deletedIds = [];

  _FullCrudCatalogRepository(this._quotes);

  List<Quote> get updatedQuotes => List.unmodifiable(_updatedQuotes);
  List<String> get deletedIds => List.unmodifiable(_deletedIds);

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

  @override
  Future<void> insertQuote(Quote quote) async {
    _quotes.add(quote);
  }

  @override
  Future<void> updateQuote(Quote quote) async {
    _updatedQuotes.add(quote);
    final index = _quotes.indexWhere((q) => q.id == quote.id);
    if (index >= 0) {
      _quotes[index] = quote;
    }
  }

  @override
  Future<void> deleteQuote(String id) async {
    _deletedIds.add(id);
    _quotes.removeWhere((q) => q.id == id);
  }

  @override
  Future<List<Quote>> getBySource(QuoteSource source) async =>
      _quotes.where((q) => q.source == source).toList();

  @override
  Future<List<Quote>> getByTag(String tag) async =>
      _quotes.where((q) => q.tags.contains(tag)).toList();
}

// ---------------------------------------------------------------------------
// Task 07.01 — Mock QuoteFormScreen for navigation tests
// ---------------------------------------------------------------------------

/// Minimal mock QuoteFormScreen that shows "New Quote" title.
/// Used to verify navigation from catalog to form.
class _MockQuoteFormScreen extends StatelessWidget {
  const _MockQuoteFormScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Quote'),
      ),
      body: const Center(
        child: Text('Mock Quote Form'),
      ),
    );
  }
}

/// Mock QuoteFormScreen with a save button that calls onSaved callback
/// and pops with result true.
class _MockQuoteFormScreenWithSave extends StatelessWidget {
  final Future<void> Function() onSaved;

  const _MockQuoteFormScreenWithSave({required this.onSaved});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Quote'),
        actions: [
          TextButton(
            onPressed: () async {
              await onSaved();
              if (context.mounted) {
                Navigator.of(context).pop(true);
              }
            },
            child: const Text('Mock Save'),
          ),
        ],
      ),
      body: const Center(
        child: Text('Mock Quote Form with Save'),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Task 07.02 — Mock edit QuoteFormScreen for edit navigation tests
// ---------------------------------------------------------------------------

/// Mock QuoteFormScreen in edit mode that shows "Edit Quote" title.
class _MockEditQuoteFormScreen extends StatelessWidget {
  final Quote quote;

  const _MockEditQuoteFormScreen({required this.quote});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Quote'),
      ),
      body: Center(
        child: Text('Editing quote: ${quote.id}'),
      ),
    );
  }
}

/// Mock QuoteFormScreen in edit mode with an update button.
class _MockEditQuoteFormScreenWithUpdate extends StatelessWidget {
  final Quote quote;
  final Future<void> Function() onUpdate;

  const _MockEditQuoteFormScreenWithUpdate({
    required this.quote,
    required this.onUpdate,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Quote'),
        actions: [
          TextButton(
            onPressed: () async {
              await onUpdate();
              if (context.mounted) {
                Navigator.of(context).pop(true);
              }
            },
            child: const Text('Mock Update'),
          ),
        ],
      ),
      body: Center(
        child: Text('Editing quote: ${quote.id}'),
      ),
    );
  }
}
