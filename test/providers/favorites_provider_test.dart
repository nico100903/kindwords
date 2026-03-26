// ignore_for_file: require_trailing_commas
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:kindwords/models/quote.dart';
import 'package:kindwords/providers/favorites_provider.dart';
import 'package:kindwords/services/favorites_service.dart';

// ---------------------------------------------------------------------------
// Test doubles
// ---------------------------------------------------------------------------

class MockFavoritesService extends Mock implements FavoritesService {}

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

const _quoteA = Quote(id: 'qa', text: 'Test Quote A', author: 'Author A');
const _quoteB = Quote(id: 'qb', text: 'Test Quote B', author: null);

// Fallback for mocktail — required so any()/captureAny() can resolve Quote.
class _FakeQuote extends Fake implements Quote {}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Constructs a [FavoritesProvider] whose mock service reports no stored
/// favorites on [loadFavorites] by default.  Individual tests may override
/// via `when(...)`.
FavoritesProvider _makeProvider(MockFavoritesService mockService) {
  when(() => mockService.loadFavorites()).thenAnswer((_) async => []);
  return FavoritesProvider(mockService);
}

/// Waits for the constructor's fire-and-forget [_loadFavorites] to settle.
Future<void> _settle() => Future<void>.microtask(() {});

void main() {
  late MockFavoritesService mockService;
  late FavoritesProvider provider;

  setUpAll(() {
    registerFallbackValue(_FakeQuote());
  });

  setUp(() {
    mockService = MockFavoritesService();
    // addFavorite / removeFavorite are no-ops by default (service layer not
    // under test here — we test provider state, not service I/O).
    when(() => mockService.addFavorite(any())).thenAnswer((_) async {});
    when(() => mockService.removeFavorite(any())).thenAnswer((_) async {});
    provider = _makeProvider(mockService);
  });

  // -------------------------------------------------------------------------
  // isFavorite
  // -------------------------------------------------------------------------

  group('FavoritesProvider.isFavorite()', () {
    test('returns false for a quote not in the list', () async {
      // Arrange: empty favorites (default stub)
      await _settle();

      // Act + Assert
      expect(
        provider.isFavorite(_quoteA),
        isFalse,
        reason: 'isFavorite must return false for a quote that has never been '
            'added to favorites',
      );
    });

    test('returns true after addFavorite is called with that quote', () async {
      // Arrange
      await _settle();
      await provider.addFavorite(_quoteA);

      // Act + Assert
      expect(
        provider.isFavorite(_quoteA),
        isTrue,
        reason: 'isFavorite must return true immediately after addFavorite '
            'completes — no additional await required',
      );
    });
  });

  // -------------------------------------------------------------------------
  // addFavorite
  // -------------------------------------------------------------------------

  group('FavoritesProvider.addFavorite()', () {
    test('adds the quote to the favorites list', () async {
      // Arrange
      await _settle();
      expect(provider.favorites, isEmpty);

      // Act
      await provider.addFavorite(_quoteA);

      // Assert
      expect(
        provider.favorites,
        contains(_quoteA),
        reason: 'addFavorite must add the quote so it appears in favorites',
      );
      expect(
        provider.favorites.length,
        equals(1),
        reason:
            'favorites must contain exactly one entry after one addFavorite',
      );
    });

    test('is idempotent — calling twice does not create a duplicate', () async {
      // Arrange
      await _settle();

      // Act: add the same quote twice
      await provider.addFavorite(_quoteA);
      await provider.addFavorite(_quoteA);

      // Assert
      expect(
        provider.favorites.length,
        equals(1),
        reason: 'favorites.length must be 1 after two addFavorite calls with '
            'the same quote — duplicates are not allowed',
      );
    });

    test('calls notifyListeners() so consumers rebuild', () async {
      // Arrange
      await _settle();
      var notifyCount = 0;
      provider.addListener(() => notifyCount++);

      // Act
      await provider.addFavorite(_quoteA);

      // Assert: at least one notification was fired
      expect(
        notifyCount,
        greaterThanOrEqualTo(1),
        reason: 'addFavorite must call notifyListeners() so the UI can '
            'update the heart icon',
      );
    });
  });

  // -------------------------------------------------------------------------
  // removeFavorite
  // -------------------------------------------------------------------------

  group('FavoritesProvider.removeFavorite()', () {
    test('removes the quote from the favorites list', () async {
      // Arrange: start with quoteA already in favorites
      await _settle();
      await provider.addFavorite(_quoteA);
      expect(provider.favorites, contains(_quoteA));

      // Act
      await provider.removeFavorite(_quoteA);

      // Assert
      expect(
        provider.favorites,
        isNot(contains(_quoteA)),
        reason: 'removeFavorite must remove the quote from favorites',
      );
      expect(
        provider.favorites,
        isEmpty,
        reason: 'favorites must be empty after removing the only entry',
      );
    });

    test('does not affect other favorites when removing one quote', () async {
      // Arrange: two quotes added
      await _settle();
      await provider.addFavorite(_quoteA);
      await provider.addFavorite(_quoteB);

      // Act: remove only quoteA
      await provider.removeFavorite(_quoteA);

      // Assert: quoteB is still present
      expect(
        provider.favorites,
        contains(_quoteB),
        reason: 'removeFavorite must only remove the targeted quote; '
            'other favorites must remain',
      );
      expect(
        provider.favorites.length,
        equals(1),
      );
    });
  });

  // -------------------------------------------------------------------------
  // toggleFavorite
  // -------------------------------------------------------------------------

  group('FavoritesProvider.toggleFavorite()', () {
    test('adds quote when it is not already a favorite', () async {
      // Arrange
      await _settle();
      expect(provider.isFavorite(_quoteA), isFalse);

      // Act
      await provider.toggleFavorite(_quoteA);

      // Assert
      expect(
        provider.isFavorite(_quoteA),
        isTrue,
        reason: 'toggleFavorite must add the quote when it was not a favorite',
      );
    });

    test('removes quote when it is already a favorite', () async {
      // Arrange: pre-add the quote
      await _settle();
      await provider.addFavorite(_quoteA);
      expect(provider.isFavorite(_quoteA), isTrue);

      // Act
      await provider.toggleFavorite(_quoteA);

      // Assert
      expect(
        provider.isFavorite(_quoteA),
        isFalse,
        reason: 'toggleFavorite must remove the quote when it was already '
            'a favorite',
      );
    });

    test('round-trips: add then remove leaves list empty', () async {
      // Arrange
      await _settle();

      // Act: toggle on then off
      await provider.toggleFavorite(_quoteA);
      await provider.toggleFavorite(_quoteA);

      // Assert
      expect(
        provider.favorites,
        isEmpty,
        reason: 'Toggling the same quote twice must produce an empty list — '
            'the net effect is no change',
      );
    });
  });

  // -------------------------------------------------------------------------
  // favorites list immutability
  // -------------------------------------------------------------------------

  group('FavoritesProvider.favorites (list contract)', () {
    test('returns an unmodifiable list — direct mutation throws', () async {
      // Arrange
      await _settle();
      await provider.addFavorite(_quoteA);

      // Act + Assert: the returned list must not be directly mutatable
      final list = provider.favorites;
      expect(
        () => list.add(_quoteB),
        throwsUnsupportedError,
        reason: 'favorites must return an unmodifiable list to prevent callers '
            'from bypassing addFavorite/removeFavorite',
      );
    });
  });

  // -------------------------------------------------------------------------
  // Sprint 2 / Task 05.02 — reload()
  // -------------------------------------------------------------------------
  // These tests verify the continuity hook that allows external code to
  // refresh favorites from storage after quote mutations.
  // See: vault/sprint/backlog/task-05.02-feat-expand-quote-crud-access-and-catalog-state-management.md
  // -------------------------------------------------------------------------

  group('FavoritesProvider.reload()', () {
    test('reload() exists and returns Future<void>', () async {
      // Arrange
      await _settle();

      // Act + Assert: method exists and can be called
      // This will fail at compile time if method does not exist
      await expectLater(provider.reload(), completes);
    });

    test('reload() re-fetches favorites from service', () async {
      // Arrange
      await _settle();
      // Initial load already called once in constructor
      clearInteractions(mockService);

      // Stub: reload returns updated list
      when(() => mockService.loadFavorites())
          .thenAnswer((_) async => [_quoteA, _quoteB]);

      // Act
      await provider.reload();

      // Assert: service was called
      verify(() => mockService.loadFavorites()).called(1);
    });

    test('reload() updates favorites list with fresh data', () async {
      // Arrange
      await _settle();
      expect(provider.favorites, isEmpty);

      // Stub: reload returns updated list
      when(() => mockService.loadFavorites())
          .thenAnswer((_) async => [_quoteA, _quoteB]);

      // Act
      await provider.reload();

      // Assert: favorites now contains fresh data
      expect(provider.favorites.length, equals(2));
      expect(provider.favorites, contains(_quoteA));
      expect(provider.favorites, contains(_quoteB));
    });

    test('reload() replaces existing favorites with fresh data', () async {
      // Arrange: start with _quoteA in favorites
      await _settle();
      await provider.addFavorite(_quoteA);
      expect(provider.favorites.length, equals(1));

      // Stub: reload returns only _quoteB (simulating external change)
      when(() => mockService.loadFavorites())
          .thenAnswer((_) async => [_quoteB]);

      // Act
      await provider.reload();

      // Assert: favorites replaced with fresh data
      expect(provider.favorites.length, equals(1));
      expect(provider.favorites, contains(_quoteB));
      expect(provider.favorites, isNot(contains(_quoteA)));
    });

    test('reload() calls notifyListeners() after update', () async {
      // Arrange
      await _settle();

      var notifyCount = 0;
      provider.addListener(() => notifyCount++);

      when(() => mockService.loadFavorites())
          .thenAnswer((_) async => [_quoteA]);

      // Act
      await provider.reload();

      // Assert
      expect(notifyCount, greaterThanOrEqualTo(1),
          reason: 'reload must call notifyListeners() after update');
    });

    test('reload() handles empty result from service', () async {
      // Arrange
      await _settle();
      await provider.addFavorite(_quoteA);
      expect(provider.favorites, isNotEmpty);

      // Stub: reload returns empty (all favorites removed externally)
      when(() => mockService.loadFavorites()).thenAnswer((_) async => []);

      // Act
      await provider.reload();

      // Assert
      expect(provider.favorites, isEmpty);
    });

    test('reload() preserves isFavorite() correctness after reload', () async {
      // Arrange
      await _settle();

      when(() => mockService.loadFavorites())
          .thenAnswer((_) async => [_quoteA]);

      // Act
      await provider.reload();

      // Assert
      expect(provider.isFavorite(_quoteA), isTrue);
      expect(provider.isFavorite(_quoteB), isFalse);
    });
  });
}
