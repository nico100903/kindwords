// ignore_for_file: require_trailing_commas
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

// v2 fixtures (with all new fields)
final _seededQuoteV2 = Quote(
  id: 'q-v2-seeded-001',
  text: 'Seeded quote for CRUD',
  author: 'Author',
  tags: ['motivational', 'wisdom'],
  source: QuoteSource.seeded,
  createdAt: DateTime.parse('2026-03-27T10:00:00.000Z'),
  updatedAt: null,
);

final _userCreatedQuoteV2 = Quote(
  id: 'q-v2-user-001',
  text: 'User created quote for CRUD',
  author: 'Me',
  tags: ['personal'],
  source: QuoteSource.userCreated,
  createdAt: DateTime.parse('2026-03-27T11:00:00.000Z'),
  updatedAt: DateTime.parse('2026-03-27T12:00:00.000Z'),
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
    test('delegates to QuoteDatabase.getAllQuotes() and returns the result',
        () async {
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

    test('does not call QuoteDatabase.getById() when getAllQuotes() is called',
        () async {
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
    test('delegates to QuoteDatabase.getById() and returns the found Quote',
        () async {
      // Arrange: DB finds q001
      when(() => mockDb.getById('q001'))
          .thenAnswer((_) async => _quoteWithAuthor);

      // Act
      final result = await repo.getById('q001');

      // Assert: quote is returned, DB called once with correct id
      expect(result, equals(_quoteWithAuthor));
      verify(() => mockDb.getById('q001')).called(1);
    });

    test('returns null when QuoteDatabase returns null for an unknown id',
        () async {
      // Edge case: nonexistent id — repository must pass null through unchanged,
      // not throw, not substitute a default quote.
      when(() => mockDb.getById('nonexistent')).thenAnswer((_) async => null);

      final result = await repo.getById('nonexistent');

      expect(result, isNull);
      verify(() => mockDb.getById('nonexistent')).called(1);
    });

    test('returns a Quote with null author when DB returns an anonymous quote',
        () async {
      // Edge case: author nullable field must survive the delegation path
      when(() => mockDb.getById('q002'))
          .thenAnswer((_) async => _quoteAnonymous);

      final result = await repo.getById('q002');

      expect(result, isNotNull);
      expect(result!.author, isNull);
    });

    test('does not call QuoteDatabase.getAllQuotes() when getById() is called',
        () async {
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

  // ═══════════════════════════════════════════════════════════════════════════════
  // SPRINT 2 / TASK 05.02 — CRUD METHOD CONTRACT TESTS
  // ═══════════════════════════════════════════════════════════════════════════════
  // These tests verify:
  //   - insertQuote() delegates to DB and returns void
  //   - updateQuote() delegates to DB and returns void
  //   - deleteQuote() delegates to DB and returns void
  //   - getBySource() delegates to DB and returns filtered list
  //   - getByTag() delegates to DB and returns filtered list
  //
  // See: vault/sprint/backlog/task-05.02-feat-expand-quote-crud-access-and-catalog-state-management.md
  // ═══════════════════════════════════════════════════════════════════════════════

  // ───────────────────────────────────────────────────────────────────────────
  // Group 4: insertQuote() — delegation
  // ───────────────────────────────────────────────────────────────────────────
  group('LocalQuoteRepository.insertQuote()', () {
    test('delegates to QuoteDatabase.insertQuote() and completes', () async {
      // Arrange
      when(() => mockDb.insertQuote(any())).thenAnswer((_) async {});

      // Act
      await repo.insertQuote(_userCreatedQuoteV2);

      // Assert: DB called exactly once with correct quote
      verify(() => mockDb.insertQuote(_userCreatedQuoteV2)).called(1);
    });

    test('passes v2 Quote with all fields to database', () async {
      // Arrange
      when(() => mockDb.insertQuote(any())).thenAnswer((_) async {});

      // Act
      await repo.insertQuote(_userCreatedQuoteV2);

      // Assert
      final captured = verify(() => mockDb.insertQuote(captureAny()))
          .captured
          .single as Quote;
      expect(captured.id, equals('q-v2-user-001'));
      expect(captured.source, equals(QuoteSource.userCreated));
      expect(captured.tags, equals(['personal']));
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // Group 5: updateQuote() — delegation
  // ───────────────────────────────────────────────────────────────────────────
  group('LocalQuoteRepository.updateQuote()', () {
    test('delegates to QuoteDatabase.updateQuote() and completes', () async {
      // Arrange
      when(() => mockDb.updateQuote(any())).thenAnswer((_) async {});

      // Act
      await repo.updateQuote(_seededQuoteV2);

      // Assert: DB called exactly once
      verify(() => mockDb.updateQuote(_seededQuoteV2)).called(1);
    });

    test('passes updated Quote with changed fields to database', () async {
      // Arrange
      when(() => mockDb.updateQuote(any())).thenAnswer((_) async {});

      final updated = Quote(
        id: 'q-v2-seeded-001',
        text: 'Updated text',
        author: 'New Author',
        tags: ['focus'],
        source: QuoteSource.seeded,
        createdAt: DateTime.parse('2026-03-27T10:00:00.000Z'),
        updatedAt: DateTime.parse('2026-03-27T15:00:00.000Z'),
      );

      // Act
      await repo.updateQuote(updated);

      // Assert
      final captured = verify(() => mockDb.updateQuote(captureAny()))
          .captured
          .single as Quote;
      expect(captured.text, equals('Updated text'));
      expect(captured.author, equals('New Author'));
      expect(captured.tags, equals(['focus']));
      expect(captured.updatedAt, isNotNull);
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // Group 6: deleteQuote() — delegation
  // ───────────────────────────────────────────────────────────────────────────
  group('LocalQuoteRepository.deleteQuote()', () {
    test('delegates to QuoteDatabase.deleteQuote() and completes', () async {
      // Arrange
      when(() => mockDb.deleteQuote(any())).thenAnswer((_) async {});

      // Act
      await repo.deleteQuote('q-v2-seeded-001');

      // Assert: DB called exactly once with correct id
      verify(() => mockDb.deleteQuote('q-v2-seeded-001')).called(1);
    });

    test('passes exact id string to database without modification', () async {
      // Contract: id must be forwarded verbatim
      const targetId = 'q-delete-target';
      when(() => mockDb.deleteQuote(any())).thenAnswer((_) async {});

      await repo.deleteQuote(targetId);

      verify(() => mockDb.deleteQuote(targetId)).called(1);
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // Group 7: getBySource() — delegation and filtering
  // ───────────────────────────────────────────────────────────────────────────
  group('LocalQuoteRepository.getBySource()', () {
    test('delegates to QuoteDatabase.getBySource() and returns the result',
        () async {
      // Arrange
      when(() => mockDb.getBySource(QuoteSource.seeded))
          .thenAnswer((_) async => [_seededQuoteV2]);

      // Act
      final result = await repo.getBySource(QuoteSource.seeded);

      // Assert
      expect(result, hasLength(1));
      expect(result.first.source, equals(QuoteSource.seeded));
      verify(() => mockDb.getBySource(QuoteSource.seeded)).called(1);
    });

    test('returns empty list when DB returns no matching quotes', () async {
      // Edge case: no quotes with that source
      when(() => mockDb.getBySource(QuoteSource.userCreated))
          .thenAnswer((_) async => []);

      final result = await repo.getBySource(QuoteSource.userCreated);

      expect(result, isEmpty);
    });

    test(
        'getBySource(QuoteSource.userCreated) returns only user-created quotes',
        () async {
      // Arrange
      when(() => mockDb.getBySource(QuoteSource.userCreated))
          .thenAnswer((_) async => [_userCreatedQuoteV2]);

      // Act
      final result = await repo.getBySource(QuoteSource.userCreated);

      // Assert
      expect(result.every((q) => q.source == QuoteSource.userCreated), isTrue);
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // Group 8: getByTag() — delegation and filtering
  // ───────────────────────────────────────────────────────────────────────────
  group('LocalQuoteRepository.getByTag()', () {
    test('delegates to QuoteDatabase.getByTag() and returns the result',
        () async {
      // Arrange
      when(() => mockDb.getByTag('motivational'))
          .thenAnswer((_) async => [_seededQuoteV2]);

      // Act
      final result = await repo.getByTag('motivational');

      // Assert
      expect(result, hasLength(1));
      expect(result.first.tags, contains('motivational'));
      verify(() => mockDb.getByTag('motivational')).called(1);
    });

    test('returns empty list when no quotes have that tag', () async {
      // Edge case: no matching tags
      when(() => mockDb.getByTag('nonexistent')).thenAnswer((_) async => []);

      final result = await repo.getByTag('nonexistent');

      expect(result, isEmpty);
    });

    test('passes exact tag string to database without modification', () async {
      // Contract: tag must be forwarded verbatim
      const targetTag = 'personal';
      when(() => mockDb.getByTag(any())).thenAnswer((_) async => []);

      await repo.getByTag(targetTag);

      verify(() => mockDb.getByTag(targetTag)).called(1);
    });
  });
}
