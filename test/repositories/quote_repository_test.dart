// Wave R4 — Failing contract tests for LocalQuoteRepository
//
// These tests FAIL at compile time until the coder creates:
//   lib/data/quote_database.dart   — QuoteDatabase class
//   lib/repositories/quote_repository.dart — QuoteRepositoryBase + LocalQuoteRepository
//
// Strategy: mock QuoteDatabase with mocktail; test that LocalQuoteRepository
// delegates correctly and satisfies the QuoteRepositoryBase interface.
//
// sqflite_ffi is NOT available in this project (not in pubspec.yaml).
// All QuoteDatabase interaction is mocked at the boundary — correct per
// testing.standard[qa]: mock boundaries only (DB, HTTP, external services).

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:kindwords/data/quote_database.dart';
import 'package:kindwords/models/quote.dart';
import 'package:kindwords/repositories/quote_repository.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Mock — QuoteDatabase is the boundary we mock (the real class uses sqflite,
// which requires a platform channel). Mocking at the DB boundary is the
// correct isolation point: LocalQuoteRepository delegates to it.
// ─────────────────────────────────────────────────────────────────────────────
class MockQuoteDatabase extends Mock implements QuoteDatabase {}

// ─────────────────────────────────────────────────────────────────────────────
// Fixtures
// ─────────────────────────────────────────────────────────────────────────────
const _quoteWithAuthor = Quote(
  id: 'q001',
  text: 'Believe you can and you\'re halfway there.',
  author: 'Theodore Roosevelt',
);

const _quoteAnonymous = Quote(
  id: 'q002',
  text: 'You are braver than you believe.',
  author: null,
);

void main() {
  late MockQuoteDatabase mockDb;
  late LocalQuoteRepository repo;

  setUp(() {
    mockDb = MockQuoteDatabase();
    repo = LocalQuoteRepository(mockDb);
  });

  // ───────────────────────────────────────────────────────────────────────────
  // Group 1: Type contract — LocalQuoteRepository is a QuoteRepositoryBase
  // ───────────────────────────────────────────────────────────────────────────
  group('LocalQuoteRepository type contract', () {
    test('LocalQuoteRepository is a QuoteRepositoryBase', () {
      // This is the core architectural assertion:
      // services throughout the app depend on QuoteRepositoryBase, not on the
      // concrete class — so LocalQuoteRepository must satisfy that interface.
      expect(repo, isA<QuoteRepositoryBase>());
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // Group 2: getAllQuotes() — delegation and return value pass-through
  // ───────────────────────────────────────────────────────────────────────────
  group('LocalQuoteRepository.getAllQuotes()', () {
    test('delegates to QuoteDatabase.getAllQuotes() and returns the result', () async {
      // Arrange: DB returns a known list
      final expected = [_quoteWithAuthor, _quoteAnonymous];
      when(() => mockDb.getAllQuotes()).thenAnswer((_) async => expected);

      // Act
      final result = await repo.getAllQuotes();

      // Assert: same list returned, DB called exactly once
      expect(result, equals(expected));
      verify(() => mockDb.getAllQuotes()).called(1);
    });

    test('returns an empty list when QuoteDatabase returns empty', () async {
      // Edge case: empty catalog — no quotes seeded yet or DB is wiped
      when(() => mockDb.getAllQuotes()).thenAnswer((_) async => []);

      final result = await repo.getAllQuotes();

      expect(result, isEmpty);
      verify(() => mockDb.getAllQuotes()).called(1);
    });

    test('returns a list containing quotes with null author', () async {
      // Edge case: anonymous quotes must not be dropped or cause cast errors
      final expected = [_quoteAnonymous];
      when(() => mockDb.getAllQuotes()).thenAnswer((_) async => expected);

      final result = await repo.getAllQuotes();

      expect(result, hasLength(1));
      expect(result.first.author, isNull);
    });

    test('does not call QuoteDatabase.getById() when getAllQuotes() is called', () async {
      // Isolation: getAllQuotes must not leak into other DB methods
      when(() => mockDb.getAllQuotes()).thenAnswer((_) async => []);

      await repo.getAllQuotes();

      verifyNever(() => mockDb.getById(any()));
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // Group 3: getById() — delegation, found case, not-found case
  // ───────────────────────────────────────────────────────────────────────────
  group('LocalQuoteRepository.getById()', () {
    test('delegates to QuoteDatabase.getById() and returns the found Quote', () async {
      // Arrange: DB finds q001
      when(() => mockDb.getById('q001'))
          .thenAnswer((_) async => _quoteWithAuthor);

      // Act
      final result = await repo.getById('q001');

      // Assert: quote is returned, DB called once with correct id
      expect(result, equals(_quoteWithAuthor));
      verify(() => mockDb.getById('q001')).called(1);
    });

    test('returns null when QuoteDatabase returns null for an unknown id', () async {
      // Edge case: nonexistent id — repository must pass null through unchanged,
      // not throw, not substitute a default quote.
      when(() => mockDb.getById('nonexistent')).thenAnswer((_) async => null);

      final result = await repo.getById('nonexistent');

      expect(result, isNull);
      verify(() => mockDb.getById('nonexistent')).called(1);
    });

    test('returns a Quote with null author when DB returns an anonymous quote', () async {
      // Edge case: author nullable field must survive the delegation path
      when(() => mockDb.getById('q002'))
          .thenAnswer((_) async => _quoteAnonymous);

      final result = await repo.getById('q002');

      expect(result, isNotNull);
      expect(result!.author, isNull);
    });

    test('does not call QuoteDatabase.getAllQuotes() when getById() is called', () async {
      // Isolation: getById must not trigger a full table scan
      when(() => mockDb.getById(any())).thenAnswer((_) async => null);

      await repo.getById('q001');

      verifyNever(() => mockDb.getAllQuotes());
    });

    test('passes the exact id string to QuoteDatabase.getById()', () async {
      // Contract: id must be forwarded verbatim — no transformation, trimming,
      // or normalization is permitted at the repository layer.
      const targetId = 'q100';
      when(() => mockDb.getById(targetId)).thenAnswer((_) async => null);

      await repo.getById(targetId);

      verify(() => mockDb.getById(targetId)).called(1);
    });
  });
}
