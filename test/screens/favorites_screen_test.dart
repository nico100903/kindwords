// ignore_for_file: require_trailing_commas, always_declare_return_types
//
// Task 02.03 — Failing widget tests for FavoritesScreen list and delete flow.
//
// Tests 1 and 2 may already pass (screen is scaffolded with empty state and
// ListView.builder). Tests 3–9 are the coder's target contract.
//
// DO NOT fix these tests. They are the behavioral contract.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kindwords/screens/favorites_screen.dart';
import 'package:kindwords/providers/favorites_provider.dart';
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
  // Test 1: Empty state
  // -------------------------------------------------------------------------

  group('Empty state', () {
    testWidgets(
      'shows empty-state message when no favorites are saved',
      (WidgetTester tester) async {
        await _buildFavoritesScreen(tester, preFill: []);

        // The empty-state text must be visible
        expect(
          find.textContaining('No favorites'),
          findsOneWidget,
          reason: 'FavoritesScreen must show an empty-state message when '
              'favorites list is empty',
        );
      },
    );

    testWidgets(
      'does not show a ListView when no favorites are saved',
      (WidgetTester tester) async {
        await _buildFavoritesScreen(tester, preFill: []);

        // No ListView should be rendered in the empty state
        expect(
          find.byType(ListView),
          findsNothing,
          reason: 'FavoritesScreen must not render a ListView in the empty '
              'state — the empty message is the only body child',
        );
      },
    );
  });

  // -------------------------------------------------------------------------
  // Test 2: List renders with 3 favorites
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
  // the data; with ListView(children:), it also works but we can at minimum
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
}
