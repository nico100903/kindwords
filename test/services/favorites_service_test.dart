// ignore_for_file: require_trailing_commas
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kindwords/models/quote.dart';
import 'package:kindwords/repositories/quote_repository.dart';
import 'package:kindwords/services/favorites_service.dart';

// ---------------------------------------------------------------------------
// Test doubles
// ---------------------------------------------------------------------------

/// Mock that satisfies [QuoteRepositoryBase] — no code generation required.
class MockQuoteRepository extends Mock implements QuoteRepositoryBase {}

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

const _q1 = Quote(id: 'q001', text: 'Test quote one', author: 'Author A');
const _q2 = Quote(id: 'q002', text: 'Test quote two', author: 'Author B');
const _missing = Quote(id: 'missing', text: 'Not in repo', author: null);

void main() {
  late MockQuoteRepository mockRepo;
  late FavoritesService service;

  setUp(() {
    // Reset SharedPreferences to an empty store before each test — standard
    // Flutter pattern that avoids platform-channel calls in unit tests.
    SharedPreferences.setMockInitialValues({});

    mockRepo = MockQuoteRepository();

    // -----------------------------------------------------------------------
    // TEST 1 — Constructor takes QuoteRepositoryBase
    //
    // This line is the primary red gate for Wave R7.
    // FavoritesService currently declares:
    //   FavoritesService(this._quoteService) — QuoteService
    // Passing a QuoteRepositoryBase here causes a compile-time type error
    // until the coder changes the constructor to accept QuoteRepositoryBase.
    // -----------------------------------------------------------------------
    service =
        FavoritesService(mockRepo); // COMPILE ERROR until R7 is implemented
  });

  // -------------------------------------------------------------------------
  // loadFavorites() — repository delegation
  // -------------------------------------------------------------------------

  group('FavoritesService.loadFavorites()', () {
    test('delegates getById to repository for each stored ID', () async {
      // Arrange: pre-load a single favorite ID into SharedPreferences
      SharedPreferences.setMockInitialValues({
        'favorite_quote_ids': '["q001"]',
      });
      service = FavoritesService(mockRepo);

      when(() => mockRepo.getById('q001')).thenAnswer((_) async => _q1);

      // Act
      await service.loadFavorites();

      // Assert: repository.getById was called with the stored ID — not
      // QuoteService.getById (which no longer exists in the dependency graph).
      verify(() => mockRepo.getById('q001')).called(1);
    });

    test('returns resolved Quote objects for stored IDs', () async {
      // Arrange: two IDs stored; repo resolves both
      SharedPreferences.setMockInitialValues({
        'favorite_quote_ids': '["q001","q002"]',
      });
      service = FavoritesService(mockRepo);

      when(() => mockRepo.getById('q001')).thenAnswer((_) async => _q1);
      when(() => mockRepo.getById('q002')).thenAnswer((_) async => _q2);

      // Act
      final result = await service.loadFavorites();

      // Assert: both resolved quotes are returned in order
      expect(result, hasLength(2));
      expect(result[0], equals(_q1));
      expect(result[1], equals(_q2));
    });

    test('silently skips IDs for which repository returns null', () async {
      // Arrange: 'missing' ID no longer exists in the repository
      SharedPreferences.setMockInitialValues({
        'favorite_quote_ids': '["q001","missing"]',
      });
      service = FavoritesService(mockRepo);

      when(() => mockRepo.getById('q001')).thenAnswer((_) async => _q1);
      when(() => mockRepo.getById('missing')).thenAnswer((_) async => null);

      // Act
      final result = await service.loadFavorites();

      // Assert: only the found quote is in results; missing ID is filtered out
      expect(result, hasLength(1));
      expect(result.first, equals(_q1));
    });

    test('returns empty list when no favorites are stored', () async {
      // Arrange: fresh prefs — nothing stored
      // (SharedPreferences.setMockInitialValues({}) already set in setUp)

      // Act
      final result = await service.loadFavorites();

      // Assert: empty list, no repository calls
      expect(result, isEmpty);
      verifyNever(() => mockRepo.getById(any()));
    });
  });

  // -------------------------------------------------------------------------
  // addFavorite()
  // -------------------------------------------------------------------------

  group('FavoritesService.addFavorite()', () {
    test('stores ID in prefs so subsequent loadFavorites returns the quote',
        () async {
      // Arrange: repo will resolve q1 when loadFavorites() calls getById
      when(() => mockRepo.getById('q001')).thenAnswer((_) async => _q1);

      // Act
      await service.addFavorite(_q1);
      final result = await service.loadFavorites();

      // Assert: the added quote appears in the loaded favorites
      expect(result, contains(_q1));
    });

    test('is idempotent — adding the same quote twice does not duplicate entry',
        () async {
      // Arrange: repo resolves q1
      when(() => mockRepo.getById('q001')).thenAnswer((_) async => _q1);

      // Act: add the same quote twice
      await service.addFavorite(_q1);
      await service.addFavorite(_q1);

      final result = await service.loadFavorites();

      // Assert: exactly one entry — not two
      expect(result, hasLength(1));
      expect(result.single, equals(_q1));
    });
  });

  // -------------------------------------------------------------------------
  // removeFavorite()
  // -------------------------------------------------------------------------

  group('FavoritesService.removeFavorite()', () {
    test('removes quote from prefs so subsequent loadFavorites returns empty',
        () async {
      // Arrange: add q1, then remove it
      when(() => mockRepo.getById('q001')).thenAnswer((_) async => _q1);

      await service.addFavorite(_q1);
      await service.removeFavorite(_q1);

      // Act
      final result = await service.loadFavorites();

      // Assert: no favorites remain after removal
      expect(result, isEmpty);
    });

    test('does nothing when removing a quote that is not stored', () async {
      // Arrange: prefs is empty; removing a non-existent quote should be a no-op
      // (no exception thrown, list remains empty)

      // Act + Assert: must not throw
      expect(
        () async => service.removeFavorite(_missing),
        returnsNormally,
      );

      final result = await service.loadFavorites();
      expect(result, isEmpty);
    });
  });

  // -------------------------------------------------------------------------
  // isFavorite()
  // -------------------------------------------------------------------------

  group('FavoritesService.isFavorite()', () {
    test('returns true when quote ID is stored in prefs', () async {
      // Arrange: add q1 first
      await service.addFavorite(_q1);

      // Act
      final result = await service.isFavorite(_q1);

      // Assert
      expect(result, isTrue);
    });

    test('returns false when quote ID is not stored in prefs', () async {
      // Arrange: fresh prefs — q1 was never added

      // Act
      final result = await service.isFavorite(_q1);

      // Assert
      expect(result, isFalse);
    });
  });
}
