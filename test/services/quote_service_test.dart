// ignore_for_file: require_trailing_commas
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:kindwords/models/quote.dart';
import 'package:kindwords/repositories/quote_repository.dart';
import 'package:kindwords/services/quote_service.dart';

// ---------------------------------------------------------------------------
// Test doubles
// ---------------------------------------------------------------------------

class MockQuoteRepository extends Mock implements QuoteRepositoryBase {}

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

const _q1 = Quote(id: 'q001', text: 'Test quote one', author: 'Author A');
const _q2 = Quote(id: 'q002', text: 'Test quote two', author: 'Author B');
const _q3 = Quote(id: 'q003', text: 'Test quote three', author: null);

void main() {
  late MockQuoteRepository mockRepo;
  late QuoteService service;

  setUp(() {
    mockRepo = MockQuoteRepository();
    // New async contract: QuoteService receives a QuoteRepositoryBase.
    // The current implementation has no such constructor — this line causes a
    // compile error until the coder migrates QuoteService (R5).
    service = QuoteService(mockRepo);
  });

  // -------------------------------------------------------------------------
  // getRandomQuote()
  // -------------------------------------------------------------------------

  group('QuoteService.getRandomQuote()', () {
    test('returns a Quote that exists in the repository result', () async {
      // Arrange
      when(() => mockRepo.getAllQuotes())
          .thenAnswer((_) async => [_q1, _q2, _q3]);

      // Act — async in the new contract
      final result = await service.getRandomQuote();

      // Assert: result must be one of the quotes returned by the repo
      expect(result, isA<Quote>());
      expect(
        [_q1.id, _q2.id, _q3.id],
        contains(result.id),
        reason:
            'getRandomQuote() must return a quote from repository.getAllQuotes()',
      );
    });

    test('calls repository.getAllQuotes() exactly once per invocation',
        () async {
      // Arrange
      when(() => mockRepo.getAllQuotes()).thenAnswer((_) async => [_q1, _q2]);

      // Act
      await service.getRandomQuote();

      // Assert: exactly one call to the repo per refresh
      verify(() => mockRepo.getAllQuotes()).called(1);
    });

    test('no-repeat guarantee: never returns quote with currentId', () async {
      // Arrange: repo returns two quotes
      when(() => mockRepo.getAllQuotes()).thenAnswer((_) async => [_q1, _q2]);

      // Act & Assert: run 20 times — with only 2 quotes, the result must always
      // be the other quote when currentId is given.
      for (var i = 0; i < 20; i++) {
        final result = await service.getRandomQuote(currentId: 'q001');
        expect(
          result.id,
          isNot(equals('q001')),
          reason:
              'getRandomQuote(currentId: q001) must never return the same quote',
        );
      }
    });

    test('returns fallback quote when repository returns empty list', () async {
      // Arrange: empty repo (e.g., DB not yet seeded)
      when(() => mockRepo.getAllQuotes()).thenAnswer((_) async => []);

      // Act: must not throw; must return a valid Quote
      final result = await service.getRandomQuote();

      // Assert: some non-null Quote is returned (the hardcoded fallback)
      expect(result, isA<Quote>());
      expect(result.text, isNotEmpty,
          reason:
              'Fallback quote must have non-empty text so UI can display it');
    });
  });

  // -------------------------------------------------------------------------
  // getById()
  // -------------------------------------------------------------------------

  group('QuoteService.getById()', () {
    test('delegates to repository.getById() and returns the result', () async {
      // Arrange
      when(() => mockRepo.getById('q001')).thenAnswer((_) async => _q1);

      // Act
      final result = await service.getById('q001');

      // Assert: the exact quote returned by the repo is passed through
      expect(result, equals(_q1));
      verify(() => mockRepo.getById('q001')).called(1);
    });

    test('returns null when repository.getById() returns null (not found)',
        () async {
      // Arrange: repo signals quote not found
      when(() => mockRepo.getById('nonexistent')).thenAnswer((_) async => null);

      // Act
      final result = await service.getById('nonexistent');

      // Assert: null is passed through, not transformed into an error/fallback
      expect(result, isNull);
    });
  });
}
