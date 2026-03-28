// ignore_for_file: require_trailing_commas, always_declare_return_types
//
// Task 02.03 — Failing widget tests for FavoritesScreen list and delete flow.
// Task 08.01 — Failing widget tests for FavoritesScreen edit and delete continuity.
//
// Tests 1 and 2 may already pass (screen is scaffolded with empty state and
// ListView.builder). Tests 3–9 are the coder's target contract.
// Tests 10–14 are the QA contract for task 08.01.
//
// DO NOT fix these tests. They are the behavioral contract.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kindwords/screens/favorites_screen.dart';
import 'package:kindwords/providers/favorites_provider.dart';
import 'package:kindwords/providers/quote_catalog_provider.dart';
import 'package:kindwords/services/favorites_service.dart';
import 'package:kindwords/repositories/quote_repository.dart';
import 'package:kindwords/models/quote.dart';

// ---------------------------------------------------------------------------
// In-memory repository — returns pre-seeded quotes by ID so FavoritesService
// can resolve favorites from SharedPreferences IDs.
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
// Full CRUD repository for 08.01 tests — supports update and delete for
// cross-provider coordination tests.
// ---------------------------------------------------------------------------

class _FullCrudFavoritesRepository implements QuoteRepositoryBase {
  final List<Quote> _quotes;

  _FullCrudFavoritesRepository(this._quotes);

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
    final index = _quotes.indexWhere((q) => q.id == quote.id);
    if (index >= 0) {
      _quotes[index] = quote;
    }
  }

  @override
  Future<void> deleteQuote(String id) async {
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
// Test fixtures
// ---------------------------------------------------------------------------

const _quoteWithAuthor = Quote(
  id: 'fav001',
  text: 'The journey of a thousand miles begins with a single step.',
  author: 'Lao Tzu',
);

const _quoteWithoutAuthor = Quote(
  id: 'fav002',
  text: 'Be the change you wish to see in the world.',
  author: null,
);

const _quoteThird = Quote(
  id: 'fav003',
  text: 'In the middle of every difficulty lies opportunity.',
  author: 'Albert Einstein',
);

final _allTestQuotes = [_quoteWithAuthor, _quoteWithoutAuthor, _quoteThird];

// ---------------------------------------------------------------------------
// Widget builder helpers
// ---------------------------------------------------------------------------

/// Builds a [MaterialApp] wrapping [FavoritesScreen] with a real
/// [FavoritesProvider] whose [FavoritesService] uses a stub repository.
///
/// [preFill] quotes are added to the provider after construction so that
/// the screen has populated favorites on first build.
Future<FavoritesProvider> _buildFavoritesScreen(
  WidgetTester tester, {
  List<Quote> preFill = const [],
}) async {
  SharedPreferences.setMockInitialValues({});

  final repo = _InMemoryQuoteRepository(_allTestQuotes);
  final service = FavoritesService(repo);
  final provider = FavoritesProvider(service);

  // Wait for _loadFavorites() to complete (starts in constructor)
  await tester.pumpAndSettle();

  // Pre-populate favorites directly via provider so the screen has data
  for (final q in preFill) {
    await provider.addFavorite(q);
  }

  await tester.pumpWidget(
    MaterialApp(
      home: ChangeNotifierProvider.value(
        value: provider,
        child: const FavoritesScreen(),
      ),
    ),
  );

  // Let the Consumer rebuild after provider state settles
  await tester.pumpAndSettle();

  return provider;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  // -------------------------------------------------------------------------
  // Test 1: Empty state when no favorites
  // -------------------------------------------------------------------------

  group('Empty state', () {
    testWidgets(
      'shows empty state message when favorites list is empty',
      (WidgetTester tester) async {
        await _buildFavoritesScreen(
          tester,
          preFill: [],
        );

        expect(
          find.textContaining('No favorites yet'),
          findsOneWidget,
          reason: 'FavoritesScreen must show empty state when no favorites exist',
        );
      },
    );
  });

  // -------------------------------------------------------------------------
  // Test 2: ListView.builder renders with favorites
  // -------------------------------------------------------------------------

  group('List renders with favorites', () {
    testWidgets(
      'renders a ListView.builder when provider has 3 favorites',
      (WidgetTester tester) async {
        await _buildFavoritesScreen(
          tester,
          preFill: [_quoteWithAuthor, _quoteWithoutAuthor, _quoteThird],
        );

        expect(
          find.byType(ListView),
          findsOneWidget,
          reason: 'FavoritesScreen must render a ListView when favorites '
              'are present',
        );
      },
    );

    testWidgets(
      'renders exactly 3 ListTile widgets for 3 favorites',
      (WidgetTester tester) async {
        await _buildFavoritesScreen(
          tester,
          preFill: [_quoteWithAuthor, _quoteWithoutAuthor, _quoteThird],
        );

        expect(
          find.byType(ListTile),
          findsNWidgets(3),
          reason: 'FavoritesScreen must render one ListTile per favorite '
              'quote — 3 favorites → 3 ListTiles',
        );
      },
    );
  });

  // -------------------------------------------------------------------------
  // Test 3: Quote text visible in list
  // -------------------------------------------------------------------------

  testWidgets(
    'first favorite text is visible in the list',
    (WidgetTester tester) async {
      await _buildFavoritesScreen(
        tester,
        preFill: [_quoteWithAuthor, _quoteWithoutAuthor, _quoteThird],
      );

      expect(
        find.text(_quoteWithAuthor.text),
        findsOneWidget,
        reason: 'The first favorite quote text must appear as a Text widget '
            'inside the list',
      );
    },
  );

  // -------------------------------------------------------------------------
  // Test 4: Author shown when present
  // -------------------------------------------------------------------------

  testWidgets(
    'shows author subtitle when quote has a non-null author',
    (WidgetTester tester) async {
      await _buildFavoritesScreen(
        tester,
        preFill: [_quoteWithAuthor],
      );

      // Author formatted as '— Lao Tzu'
      expect(
        find.text('— ${_quoteWithAuthor.author}'),
        findsOneWidget,
        reason: 'ListTile.subtitle must display the author as "— Author Name" '
            'when quote.author is non-null',
      );
    },
  );

  // -------------------------------------------------------------------------
  // Test 5: Author hidden when null
  // -------------------------------------------------------------------------

  testWidgets(
    'does not show a subtitle when quote.author is null',
    (WidgetTester tester) async {
      await _buildFavoritesScreen(
        tester,
        preFill: [_quoteWithoutAuthor],
      );

      // Must not render '— null' text
      expect(
        find.text('— null'),
        findsNothing,
        reason: 'ListTile.subtitle must be null when quote.author is null — '
            'no "— null" text must appear',
      );
    },
  );

  // -------------------------------------------------------------------------
  // Test 6: Delete button present on each row
  // -------------------------------------------------------------------------

  testWidgets(
    'each ListTile has an IconButton with a delete icon',
    (WidgetTester tester) async {
      await _buildFavoritesScreen(
        tester,
        preFill: [_quoteWithAuthor, _quoteWithoutAuthor, _quoteThird],
      );

      // One delete IconButton per row — 3 favorites → 3 delete buttons
      expect(
        find.byIcon(Icons.delete_outline),
        findsNWidgets(3),
        reason:
            'Every ListTile must have an IconButton with Icons.delete_outline '
            'as its trailing widget',
      );
    },
  );

  // -------------------------------------------------------------------------
  // Test 7: Tapping delete removes the item from the list
  // -------------------------------------------------------------------------

  testWidgets(
    'tapping the delete button on the first item removes it from the list',
    (WidgetTester tester) async {
      await _buildFavoritesScreen(
        tester,
        preFill: [_quoteWithAuthor, _quoteWithoutAuthor, _quoteThird],
      );

      // Confirm 3 items before deletion
      expect(find.byType(ListTile), findsNWidgets(3));

      // Tap the first delete button
      await tester.tap(find.byIcon(Icons.delete_outline).first);
      await tester.pumpAndSettle();

      // List must shrink to 2 items
      expect(
        find.byType(ListTile),
        findsNWidgets(2),
        reason: 'After tapping delete on the first item, the list must '
            'contain 2 ListTiles',
      );

      // The deleted quote text must no longer be visible
      expect(
        find.text(_quoteWithAuthor.text),
        findsNothing,
        reason: 'The deleted quote text must not appear in the list after '
            'deletion',
      );
    },
  );

  // -------------------------------------------------------------------------
  // Test 8: Delete does not affect other items
  // -------------------------------------------------------------------------

  testWidgets(
    'remaining 2 favorites are still visible after deleting the first',
    (WidgetTester tester) async {
      await _buildFavoritesScreen(
        tester,
        preFill: [_quoteWithAuthor, _quoteWithoutAuthor, _quoteThird],
      );

      // Delete first item
      await tester.tap(find.byIcon(Icons.delete_outline).first);
      await tester.pumpAndSettle();

      // The other two quotes must still be visible
      expect(
        find.text(_quoteWithoutAuthor.text),
        findsOneWidget,
        reason: 'Second favorite must remain visible after deleting the first',
      );
      expect(
        find.text(_quoteThird.text),
        findsOneWidget,
        reason: 'Third favorite must remain visible after deleting the first',
      );
    },
  );

  // -------------------------------------------------------------------------
  // Test 9: ListView.builder (not ListView(children:)) is used
  //
  // Both ListView.builder and ListView(children:) produce a widget of type
  // ListView, so we cannot distinguish them by type alone. Instead we verify
  // that itemCount on the scroll view matches favorites.length — a property
  // only set when itemBuilder is used — by checking the SliverList delegate
  // type. A pragmatic proxy: with ListView.builder, the item count matches
  // the data; with ListView(children:), it also works but we at minimum
  // verify the scroll view exists and item count is respected by checking
  // the number of built tiles equals the data length.
  //
  // Primary assertion: 3 ListTiles for 3 favorites — satisfies the spec.
  // Secondary note: this test documents the intent; strict ListView.builder
  // detection would require accessing internal RenderSliverList state which
  // is an implementation detail. The tech-lead guidance uses ListView.builder
  // and the itemCount/itemBuilder match is the behavioral contract.
  // -------------------------------------------------------------------------

  testWidgets(
    'ListView renders exactly as many rows as favorites (itemCount contract)',
    (WidgetTester tester) async {
      await _buildFavoritesScreen(
        tester,
        preFill: [_quoteWithAuthor, _quoteWithoutAuthor, _quoteThird],
      );

      // Exactly one ListView present (ListView.builder produces one ListView)
      expect(
        find.byType(ListView),
        findsOneWidget,
        reason:
            'Exactly one ListView must be present when favorites are loaded',
      );

      // The number of rendered ListTiles must equal the number of favorites
      expect(
        find.byType(ListTile),
        findsNWidgets(3),
        reason: 'itemCount must equal favorites.length — '
            '3 favorites must produce exactly 3 ListTile widgets',
      );
    },
  );

  // =========================================================================
  // TASK 08.01 — FAVORITES EDIT/DELETE CONTINUITY TESTS
  // =========================================================================
  //
  // These tests define the behavioral contract for:
  // - Edit icon presence per favorited quote
  // - Edit navigation to QuoteFormScreen
  // - Favorites list refresh after edit (updated quote text visible)
  // - Stale entry cleanup after delete via form
  //
  // Key implementation expectations from enrichment:
  // - FavoritesScreen becomes StatefulWidget
  // - ChangeNotifierProvider.value re-shares QuoteCatalogProvider on navigation
  // - FavoritesProvider.reload() called on Navigator.pop(..., true)
  // =========================================================================

  // -------------------------------------------------------------------------
  // Test 10: Edit icon present on each row (Task 08.01)
  // -------------------------------------------------------------------------

  group('Task 08.01 - Edit icon presence', () {
    testWidgets(
      'each favorited quote has an edit IconButton with Icons.edit_outlined',
      (WidgetTester tester) async {
        await _buildFavoritesScreen(
          tester,
          preFill: [_quoteWithAuthor, _quoteWithoutAuthor, _quoteThird],
        );

        // One edit IconButton per row — 3 favorites → 3 edit buttons
        expect(
          find.byIcon(Icons.edit_outlined),
          findsNWidgets(3),
          reason: 'Every favorited quote ListTile must have an edit IconButton '
              'with Icons.edit_outlined as required by task 08.01',
        );
      },
    );

    testWidgets(
      'single favorite shows exactly one edit icon',
      (WidgetTester tester) async {
        await _buildFavoritesScreen(
          tester,
          preFill: [_quoteWithAuthor],
        );

        expect(
          find.byIcon(Icons.edit_outlined),
          findsOneWidget,
          reason: 'A single favorited quote must show exactly one edit icon',
        );
      },
    );

    testWidgets(
      'empty favorites shows no edit icons',
      (WidgetTester tester) async {
        await _buildFavoritesScreen(
          tester,
          preFill: [],
        );

        expect(
          find.byIcon(Icons.edit_outlined),
          findsNothing,
          reason: 'When no favorites exist, no edit icons should appear',
        );
      },
    );
  });

  // -------------------------------------------------------------------------
  // Test 11: Edit icon navigation to QuoteFormScreen (Task 08.01)
  // -------------------------------------------------------------------------

  group('Task 08.01 - Edit navigation', () {
    testWidgets(
      'tapping edit icon pushes QuoteFormScreen in edit mode',
      (WidgetTester tester) async {
        // Use full CRUD repository for cross-provider coordination tests
        final repo = _FullCrudFavoritesRepository([_quoteWithAuthor]);
        final service = FavoritesService(repo);
        final favoritesProvider = FavoritesProvider(service);

        // Create catalog provider that FavoritesScreen can read
        final catalogProvider = QuoteCatalogProvider(repo);

        await tester.pumpWidget(
          MaterialApp(
            home: MultiProvider(
              providers: [
                ChangeNotifierProvider.value(value: favoritesProvider),
                ChangeNotifierProvider.value(value: catalogProvider),
              ],
              child: const FavoritesScreen(),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Pre-populate favorites
        await favoritesProvider.addFavorite(_quoteWithAuthor);
        await tester.pumpAndSettle();

        // Find and tap the edit icon
        final editIcon = find.byIcon(Icons.edit_outlined);
        expect(editIcon, findsOneWidget,
            reason: 'Edit icon must be visible on favorited quote row');

        await tester.tap(editIcon);
        await tester.pumpAndSettle();

        // Assert: navigated to QuoteFormScreen in edit mode
        expect(
          find.text('Edit Quote'),
          findsOneWidget,
          reason: 'Tapping edit icon must push QuoteFormScreen in edit mode '
              'which shows "Edit Quote" title',
        );
      },
    );

    testWidgets(
      'QuoteFormScreen receives the correct quote for editing',
      (WidgetTester tester) async {
        final repo = _FullCrudFavoritesRepository([_quoteWithAuthor]);
        final service = FavoritesService(repo);
        final favoritesProvider = FavoritesProvider(service);
        final catalogProvider = QuoteCatalogProvider(repo);

        await tester.pumpWidget(
          MaterialApp(
            home: MultiProvider(
              providers: [
                ChangeNotifierProvider.value(value: favoritesProvider),
                ChangeNotifierProvider.value(value: catalogProvider),
              ],
              child: const FavoritesScreen(),
            ),
          ),
        );

        await tester.pumpAndSettle();
        await favoritesProvider.addFavorite(_quoteWithAuthor);
        await tester.pumpAndSettle();

        // Tap edit
        await tester.tap(find.byIcon(Icons.edit_outlined));
        await tester.pumpAndSettle();

        // Assert: QuoteFormScreen is showing the quote's text (pre-populated)
        expect(
          find.textContaining(_quoteWithAuthor.text),
          findsWidgets,
          reason: 'QuoteFormScreen must show the quote text pre-populated in '
              'the text field when in edit mode',
        );
      },
    );
  });

  // -------------------------------------------------------------------------
  // Test 12: Favorites refresh after edit (Task 08.01)
  // -------------------------------------------------------------------------

  group('Task 08.01 - Edit completion flow', () {
    testWidgets(
      'after editing a favorite and returning, updated quote text is visible',
      (WidgetTester tester) async {
        final originalQuote = Quote(
          id: 'edit-test-001',
          text: 'Original quote text before edit.',
          author: 'Original Author',
          tags: const [],
          source: QuoteSource.seeded,
          createdAt: DateTime.utc(2026, 3, 1),
        );

        final updatedQuote = Quote(
          id: 'edit-test-001',
          text: 'Updated quote text after successful edit!',
          author: 'Updated Author',
          tags: const ['wisdom'],
          source: QuoteSource.seeded,
          createdAt: DateTime.utc(2026, 3, 1),
          updatedAt: DateTime.utc(2026, 3, 28),
        );

        final repo = _FullCrudFavoritesRepository([originalQuote]);
        final service = FavoritesService(repo);
        final favoritesProvider = FavoritesProvider(service);
        final catalogProvider = QuoteCatalogProvider(repo);

        await tester.pumpWidget(
          MaterialApp(
            home: MultiProvider(
              providers: [
                ChangeNotifierProvider.value(value: favoritesProvider),
                ChangeNotifierProvider.value(value: catalogProvider),
              ],
              child: const FavoritesScreen(),
            ),
          ),
        );

        await tester.pumpAndSettle();
        await favoritesProvider.addFavorite(originalQuote);
        await tester.pumpAndSettle();

        // Verify original text is visible
        expect(
          find.textContaining('Original quote text before edit'),
          findsOneWidget,
          reason: 'Original quote text must be visible before edit',
        );

        // Tap edit to navigate to QuoteFormScreen
        await tester.tap(find.byIcon(Icons.edit_outlined));
        await tester.pumpAndSettle();

        // Simulate update by calling provider directly (mocks form save)
        await catalogProvider.updateQuote(updatedQuote);

        // Pop back with result=true to simulate successful edit
        // Note: We need to find the context from the widget tree
        // The FavoritesScreen should be in the tree after navigation
        final context = tester.element(find.byType(FavoritesScreen).last);
        Navigator.of(context).pop(true);
        await tester.pumpAndSettle();

        // Assert: updated text is now visible in favorites list
        expect(
          find.textContaining('Updated quote text after successful edit'),
          findsOneWidget,
          reason: 'After editing a favorite and returning with result=true, '
              'FavoritesProvider.reload() must be called and updated text visible',
        );

        // Assert: original text no longer appears
        expect(
          find.textContaining('Original quote text before edit'),
          findsNothing,
          reason: 'Original quote text must not appear after successful edit',
        );
      },
    );

    testWidgets(
      'canceling edit (pop with false) does not trigger reload',
      (WidgetTester tester) async {
        final quote = Quote(
          id: 'cancel-test-001',
          text: 'This text should remain unchanged.',
          author: 'Test Author',
          tags: const [],
          source: QuoteSource.seeded,
          createdAt: DateTime.utc(2026, 3, 1),
        );

        final repo = _FullCrudFavoritesRepository([quote]);
        final service = FavoritesService(repo);
        final favoritesProvider = FavoritesProvider(service);
        final catalogProvider = QuoteCatalogProvider(repo);

        await tester.pumpWidget(
          MaterialApp(
            home: MultiProvider(
              providers: [
                ChangeNotifierProvider.value(value: favoritesProvider),
                ChangeNotifierProvider.value(value: catalogProvider),
              ],
              child: const FavoritesScreen(),
            ),
          ),
        );

        await tester.pumpAndSettle();
        await favoritesProvider.addFavorite(quote);
        await tester.pumpAndSettle();

        // Tap edit
        await tester.tap(find.byIcon(Icons.edit_outlined));
        await tester.pumpAndSettle();

        // Pop back with result=false (cancel)
        final context = tester.element(find.byType(FavoritesScreen).last);
        Navigator.of(context).pop(false);
        await tester.pumpAndSettle();

        // Assert: original text still visible (no reload occurred)
        expect(
          find.textContaining('This text should remain unchanged'),
          findsOneWidget,
          reason: 'Canceling edit (pop with false) must not trigger reload — '
              'original text must still be visible',
        );
      },
    );
  });

  // -------------------------------------------------------------------------
  // Test 13: Stale entry cleanup after delete via form (Task 08.01)
  // -------------------------------------------------------------------------

  group('Task 08.01 - Delete via form (stale entry cleanup)', () {
    testWidgets(
      'after deleting a favorite via QuoteFormScreen, quote no longer appears in list',
      (WidgetTester tester) async {
        final quote1 = Quote(
          id: 'delete-test-001',
          text: 'Quote that will remain after delete.',
          author: 'Remaining Author',
          tags: const [],
          source: QuoteSource.seeded,
          createdAt: DateTime.utc(2026, 3, 1),
        );

        final quote2 = Quote(
          id: 'delete-test-002',
          text: 'Quote that will be deleted via form.',
          author: 'Deleted Author',
          tags: const [],
          source: QuoteSource.userCreated,
          createdAt: DateTime.utc(2026, 3, 2),
        );

        final repo = _FullCrudFavoritesRepository([quote1, quote2]);
        final service = FavoritesService(repo);
        final favoritesProvider = FavoritesProvider(service);
        final catalogProvider = QuoteCatalogProvider(repo);

        await tester.pumpWidget(
          MaterialApp(
            home: MultiProvider(
              providers: [
                ChangeNotifierProvider.value(value: favoritesProvider),
                ChangeNotifierProvider.value(value: catalogProvider),
              ],
              child: const FavoritesScreen(),
            ),
          ),
        );

        await tester.pumpAndSettle();
        await favoritesProvider.addFavorite(quote1);
        await favoritesProvider.addFavorite(quote2);
        await tester.pumpAndSettle();

        // Verify both quotes visible initially
        expect(
          find.byType(ListTile),
          findsNWidgets(2),
          reason: 'Both favorites must be visible initially',
        );

        // Tap edit on the second quote (the one to delete)
        final editIcons = find.byIcon(Icons.edit_outlined);
        expect(editIcons, findsNWidgets(2));
        await tester.tap(editIcons.at(1)); // Tap edit on second quote
        await tester.pumpAndSettle();

        // Simulate delete by calling provider directly
        await catalogProvider.deleteQuote(quote2.id);

        // Pop back with result=true to simulate successful delete
        final context = tester.element(find.byType(FavoritesScreen).last);
        Navigator.of(context).pop(true);
        await tester.pumpAndSettle();

        // Assert: only one quote remains (stale entry cleaned up)
        expect(
          find.byType(ListTile),
          findsOneWidget,
          reason: 'After deleting a favorite via QuoteFormScreen and returning '
              'with result=true, FavoritesProvider.reload() must be called and '
              'the deleted quote must not appear (stale entry cleanup)',
        );

        // Assert: deleted quote text no longer appears
        expect(
          find.textContaining('Quote that will be deleted via form'),
          findsNothing,
          reason: 'The deleted quote text must not appear in favorites list',
        );

        // Assert: remaining quote still visible
        expect(
          find.textContaining('Quote that will remain after delete'),
          findsOneWidget,
          reason: 'The remaining quote must still be visible after deletion',
        );
      },
    );

    testWidgets(
      'canceling delete (pop with false) does not remove the quote',
      (WidgetTester tester) async {
        final quote = Quote(
          id: 'cancel-delete-test-001',
          text: 'This quote should remain after cancel.',
          author: 'Test Author',
          tags: const [],
          source: QuoteSource.seeded,
          createdAt: DateTime.utc(2026, 3, 1),
        );

        final repo = _FullCrudFavoritesRepository([quote]);
        final service = FavoritesService(repo);
        final favoritesProvider = FavoritesProvider(service);
        final catalogProvider = QuoteCatalogProvider(repo);

        await tester.pumpWidget(
          MaterialApp(
            home: MultiProvider(
              providers: [
                ChangeNotifierProvider.value(value: favoritesProvider),
                ChangeNotifierProvider.value(value: catalogProvider),
              ],
              child: const FavoritesScreen(),
            ),
          ),
        );

        await tester.pumpAndSettle();
        await favoritesProvider.addFavorite(quote);
        await tester.pumpAndSettle();

        // Tap edit
        await tester.tap(find.byIcon(Icons.edit_outlined));
        await tester.pumpAndSettle();

        // Pop back with result=false (cancel delete)
        final context = tester.element(find.byType(FavoritesScreen).last);
        Navigator.of(context).pop(false);
        await tester.pumpAndSettle();

        // Assert: quote still visible
        expect(
          find.textContaining('This quote should remain after cancel'),
          findsOneWidget,
          reason: 'Canceling delete (pop with false) must not remove the quote',
        );
      },
    );
  });

  // -------------------------------------------------------------------------
  // Test 14: Existing delete button behavior unchanged (Task 08.01 regression gate)
  // -------------------------------------------------------------------------

  group('Task 08.01 - Existing delete button behavior unchanged', () {
    testWidgets(
      'existing delete icon still works for direct unfavorite (test 6 unchanged)',
      (WidgetTester tester) async {
        await _buildFavoritesScreen(
          tester,
          preFill: [_quoteWithAuthor, _quoteWithoutAuthor, _quoteThird],
        );

        // One delete IconButton per row — 3 favorites → 3 delete buttons
        expect(
          find.byIcon(Icons.delete_outline),
          findsNWidgets(3),
          reason:
              'Every ListTile must still have the existing delete IconButton '
              'with Icons.delete_outline (regression gate)',
        );
      },
    );

    testWidgets(
      'tapping delete icon still removes item (test 7 unchanged)',
      (WidgetTester tester) async {
        await _buildFavoritesScreen(
          tester,
          preFill: [_quoteWithAuthor, _quoteWithoutAuthor, _quoteThird],
        );

        // Confirm 3 items before deletion
        expect(find.byType(ListTile), findsNWidgets(3));

        // Tap the first delete button
        await tester.tap(find.byIcon(Icons.delete_outline).first);
        await tester.pumpAndSettle();

        // List must shrink to 2 items
        expect(
          find.byType(ListTile),
          findsNWidgets(2),
          reason: 'Existing delete behavior must work unchanged — '
              'after tapping delete, list must contain 2 ListTiles',
        );
      },
    );
  });
}
