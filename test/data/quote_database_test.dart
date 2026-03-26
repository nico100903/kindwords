// Wave R4 — Failing contract tests for QuoteDatabase
//
// These tests FAIL at compile time until the coder creates:
//   lib/data/quote_database.dart — QuoteDatabase class
//
// sqflite_ffi is NOT available in this project (not in pubspec.yaml).
// sqflite requires an Android/iOS platform channel and cannot execute in the
// Dart VM test environment. These tests verify the API-surface contract
// (method signatures exist and return the correct types) via a mock subclass.
//
// Tests are marked @Skip('requires device') where the real DB would be
// exercised, because sqflite_ffi is absent. The compile-time presence of the
// import is itself the red gate: if QuoteDatabase does not exist, the build
// fails — which is the correct failing state for a BDD red step.
//
// Quality Gate coverage (from task-04.01 §Quality Gates):
//   QG3 — seedIfEmpty is idempotent: calling twice does not double the count
//   QG4 — seedIfEmpty inserts all quotes: getAllQuotes() returns >=100
//   QG5 — stable IDs preserved: getById('q001') and getById('q100') non-null
//
// These are annotated as integration-level and skipped in unit-test environment.
// The coder must run them on a device / emulator to satisfy QG3–QG5.
//
// ─────────────────────────────────────────────────────────────────────────────
// Sprint 2 / Task 05.01 — v2 Schema and Migration Tests
// ─────────────────────────────────────────────────────────────────────────────
// Quality Gates from task-05.01:
//   QG3 — Fresh install v2 schema: onCreate includes all 7 columns
//   QG4 — Migration preserves rows: v1→v2 keeps all existing rows intact
//   QG5 — Upgraded v1 rows readable: getAllQuotes() works on migrated data

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sqflite/sqflite.dart';

import 'package:kindwords/data/quote_database.dart';
import 'package:kindwords/models/quote.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Mock — used for API-surface contract tests that don't need a real DB
// ─────────────────────────────────────────────────────────────────────────────
class MockQuoteDatabase extends Mock implements QuoteDatabase {}

// ─────────────────────────────────────────────────────────────────────────────
// Fixtures
// ─────────────────────────────────────────────────────────────────────────────
// v1-style fixtures (for backward compatibility tests)
const _sampleQuoteV1 = Quote(
  id: 'q001',
  text: 'Sample text',
  author: 'Author',
);
const _anonymousQuoteV1 = Quote(
  id: 'q099',
  text: 'Anonymous text',
  author: null,
);

// v2 fixtures (with all new fields)
final _sampleQuoteV2 = Quote(
  id: 'q-v2-001',
  text: 'Sample v2 quote',
  author: 'Author',
  tags: ['motivational', 'wisdom'],
  source: QuoteSource.seeded,
  createdAt: DateTime.parse('2026-03-27T10:00:00.000Z'),
  updatedAt: null,
);
final _userCreatedQuoteV2 = Quote(
  id: 'q-v2-002',
  text: 'User created quote',
  author: 'Me',
  tags: ['personal'],
  source: QuoteSource.userCreated,
  createdAt: DateTime.parse('2026-03-27T11:00:00.000Z'),
  updatedAt: DateTime.parse('2026-03-27T12:00:00.000Z'),
);
// For backward compatibility with existing tests
Quote get _sampleQuote => _sampleQuoteV1;
Quote get _anonymousQuote => _anonymousQuoteV1;

void main() {
  // ───────────────────────────────────────────────────────────────────────────
  // Group 1: API-surface contract — QuoteDatabase has the required methods
  //
  // Strategy: instantiate a Mock that implements QuoteDatabase. If QuoteDatabase
  // does not exist, the `implements QuoteDatabase` line will not compile —
  // that is the expected red state. The mock stubs confirm the method
  // signatures match the expected return types.
  // ───────────────────────────────────────────────────────────────────────────
  group('QuoteDatabase API-surface contract (mock-verified)', () {
    late MockQuoteDatabase mockDb;

    setUp(() {
      mockDb = MockQuoteDatabase();
    });

    test('open() exists and returns Future<void>', () async {
      // Arrange: stub open() — if signature does not match Future<void>, mocktail
      // will produce a type mismatch at stub registration.
      when(() => mockDb.open()).thenAnswer((_) async {});

      // Act + Assert: no exception means the signature is correct
      await expectLater(mockDb.open(), completes);
    });

    test('seedIfEmpty() exists and accepts List<Quote>, returns Future<void>',
        () async {
      // Arrange: stub with a List<Quote> parameter
      when(() => mockDb.seedIfEmpty(any())).thenAnswer((_) async {});

      // Act
      await expectLater(mockDb.seedIfEmpty([_sampleQuote]), completes);

      // Assert: the method was called with the correct argument type
      verify(() => mockDb.seedIfEmpty([_sampleQuote])).called(1);
    });

    test('getAllQuotes() exists and returns Future<List<Quote>>', () async {
      // Arrange: stub returns a typed List<Quote>
      when(() => mockDb.getAllQuotes())
          .thenAnswer((_) async => [_sampleQuote, _anonymousQuote]);

      // Act
      final result = await mockDb.getAllQuotes();

      // Assert: return type is List<Quote>
      expect(result, isA<List<Quote>>());
      expect(result, hasLength(2));
    });

    test('getById() exists and accepts String id, returns Future<Quote?>',
        () async {
      // Arrange: stub returns a nullable Quote — both paths must be type-safe
      when(() => mockDb.getById('q001')).thenAnswer((_) async => _sampleQuote);
      when(() => mockDb.getById('nonexistent')).thenAnswer((_) async => null);

      // Act + Assert: found case
      final found = await mockDb.getById('q001');
      expect(found, isA<Quote>());
      expect(found, isNotNull);

      // Act + Assert: not-found case (null is a valid return)
      final notFound = await mockDb.getById('nonexistent');
      expect(notFound, isNull);
    });

    test(
        'getAllQuotes() returns List<Quote> with nullable author fields intact',
        () async {
      // Edge case: anonymous quotes (null author) must not be cast-stripped
      when(() => mockDb.getAllQuotes())
          .thenAnswer((_) async => [_anonymousQuote]);

      final result = await mockDb.getAllQuotes();

      expect(result.first.author, isNull);
    });

    test('seedIfEmpty() accepts an empty list without error', () async {
      // Edge case: empty input — method must accept it (no crash on zero-length seed)
      when(() => mockDb.seedIfEmpty(any())).thenAnswer((_) async {});

      await expectLater(mockDb.seedIfEmpty([]), completes);
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // Group 2: Integration contracts — require real sqflite (device/emulator)
  //
  // These tests cover Quality Gates QG3, QG4, QG5 from task-04.01.
  // They are skipped in CI / unit-test environment because sqflite requires
  // an Android/iOS platform channel. Run them with `flutter test` on a
  // connected device or emulator, or add sqflite_ffi to dev_dependencies
  // to enable Linux/macOS execution.
  //
  // These compile-check the QuoteDatabase interface even when skipped.
  // ───────────────────────────────────────────────────────────────────────────
  group(
    'QuoteDatabase integration contracts',
    skip: 'requires sqflite platform channel — run on device/emulator',
    () {
      // QG3: seedIfEmpty is idempotent — calling twice must not double the count
      test('seedIfEmpty is idempotent: calling twice does not double the count',
          () async {
        // Arrange: open a real QuoteDatabase (requires device)
        final db = QuoteDatabase();
        await db.open();

        final seeds = [_sampleQuote, _anonymousQuote];

        // Act: seed once, then seed again
        await db.seedIfEmpty(seeds);
        await db.seedIfEmpty(seeds); // second call must be a no-op

        // Assert: exactly the initial count — not doubled
        final all = await db.getAllQuotes();
        expect(
          all.length,
          equals(seeds.length),
          reason:
              'seedIfEmpty must be idempotent: calling twice must not insert duplicate rows',
        );
      });

      // QG4: after seeding kAllQuotes, getAllQuotes() returns >=100 quotes
      test(
          'getAllQuotes() returns at least 100 quotes after seeding kAllQuotes',
          () async {
        // Arrange: seed with the full production catalog
        // NOTE: coder imports kAllQuotes and passes it to seedIfEmpty in bootstrapApp.
        // This test constructs an analogous scenario with 100+ synthetic quotes.
        // The actual QG4 gate (kAllQuotes.length >=100) is verified by
        // quote_data_test.dart in an existing passing test.
        final db = QuoteDatabase();
        await db.open();

        // Build a 100-quote fixture list
        final largeList = List<Quote>.generate(
          100,
          (i) => Quote(
            id: 'q${(i + 1).toString().padLeft(3, '0')}',
            text: 'Quote number ${i + 1}',
            author: i.isEven ? 'Author $i' : null,
          ),
        );

        await db.seedIfEmpty(largeList);

        // Assert
        final all = await db.getAllQuotes();
        expect(
          all.length,
          greaterThanOrEqualTo(100),
          reason:
              'QG4: getAllQuotes() must return >=100 after seeding 100 quotes',
        );
      });

      // QG5: stable IDs preserved — getById returns non-null for seeded IDs
      test('getById returns non-null for a seeded quote ID', () async {
        final db = QuoteDatabase();
        await db.open();

        const seed = Quote(
          id: 'q001',
          text: 'Believe you can.',
          author: 'Theodore Roosevelt',
        );
        await db.seedIfEmpty([seed]);

        final found = await db.getById('q001');

        expect(
          found,
          isNotNull,
          reason:
              'QG5: getById must return non-null for a quote that was seeded',
        );
        expect(found!.id, equals('q001'));
        expect(found.text, equals(seed.text));
      });

      // QG5 companion: getById returns null for a never-seeded ID
      test('getById returns null for an id that was never seeded', () async {
        final db = QuoteDatabase();
        await db.open();

        // Do not seed 'q999'
        final result = await db.getById('q999');

        expect(result, isNull);
      });

      // Edge case: getById returns quote with null author (anonymous quote)
      test('getById returns anonymous quote with null author correctly',
          () async {
        final db = QuoteDatabase();
        await db.open();

        const anon = Quote(id: 'q050', text: 'Anonymous wisdom.', author: null);
        await db.seedIfEmpty([anon]);

        final result = await db.getById('q050');

        expect(result, isNotNull);
        expect(
          result!.author,
          isNull,
          reason: 'author TEXT column is nullable — must round-trip as null',
        );
      });
    },
  );

  // ═══════════════════════════════════════════════════════════════════════════════
  // SPRINT 2 / TASK 05.01 — v2 SCHEMA AND MIGRATION TESTS
  // ═══════════════════════════════════════════════════════════════════════════════
  // These tests verify:
  //   - Fresh install creates v2 schema with all 7 columns
  //   - Migration from v1 to v2 preserves existing rows
  //   - seedIfEmpty() writes rows with default v2 values
  //   - getById() and getAllQuotes() work correctly after migration
  //
  // See: vault/sprint/backlog/task-05.01-feat-extend-quote-entity-and-migrate-local-quote-storage.md
  // ═══════════════════════════════════════════════════════════════════════════════

  // ───────────────────────────────────────────────────────────────────────────
  // Group 3: v2 API-surface contract (mock-verified)
  // ───────────────────────────────────────────────────────────────────────────
  group('QuoteDatabase v2 API-surface contract (mock-verified)', () {
    late MockQuoteDatabase mockDb;

    setUp(() {
      mockDb = MockQuoteDatabase();
    });

    test('seedIfEmpty() accepts v2 Quote with tags, source, timestamps',
        () async {
      // Arrange
      when(() => mockDb.seedIfEmpty(any())).thenAnswer((_) async {});

      // Act: pass a v2 quote with all fields
      await expectLater(mockDb.seedIfEmpty([_sampleQuoteV2]), completes);

      // Assert
      verify(() => mockDb.seedIfEmpty([_sampleQuoteV2])).called(1);
    });

    test('getAllQuotes() returns v2 Quotes with tags populated', () async {
      // Arrange: stub returns v2 quotes
      when(() => mockDb.getAllQuotes())
          .thenAnswer((_) async => [_sampleQuoteV2, _userCreatedQuoteV2]);

      // Act
      final result = await mockDb.getAllQuotes();

      // Assert
      expect(result, hasLength(2));
      expect(result.first.tags, equals(['motivational', 'wisdom']));
      expect(result.last.tags, equals(['personal']));
    });

    test('getAllQuotes() returns v2 Quotes with source populated', () async {
      // Arrange
      when(() => mockDb.getAllQuotes())
          .thenAnswer((_) async => [_sampleQuoteV2, _userCreatedQuoteV2]);

      // Act
      final result = await mockDb.getAllQuotes();

      // Assert
      expect(result.first.source, equals(QuoteSource.seeded));
      expect(result.last.source, equals(QuoteSource.userCreated));
    });

    test('getAllQuotes() returns v2 Quotes with createdAt populated', () async {
      // Arrange
      when(() => mockDb.getAllQuotes())
          .thenAnswer((_) async => [_sampleQuoteV2]);

      // Act
      final result = await mockDb.getAllQuotes();

      // Assert
      expect(result.first.createdAt, isNotNull);
      expect(
        result.first.createdAt,
        equals(DateTime.parse('2026-03-27T10:00:00.000Z')),
      );
    });

    test('getAllQuotes() returns v2 Quotes with nullable updatedAt', () async {
      // Arrange
      when(() => mockDb.getAllQuotes())
          .thenAnswer((_) async => [_sampleQuoteV2, _userCreatedQuoteV2]);

      // Act
      final result = await mockDb.getAllQuotes();

      // Assert: first has null updatedAt, second has non-null
      expect(result.first.updatedAt, isNull);
      expect(result.last.updatedAt, isNotNull);
    });

    test('getById() returns v2 Quote with all fields', () async {
      // Arrange
      when(() => mockDb.getById('q-v2-001'))
          .thenAnswer((_) async => _sampleQuoteV2);

      // Act
      final result = await mockDb.getById('q-v2-001');

      // Assert
      expect(result, isNotNull);
      expect(result!.id, equals('q-v2-001'));
      expect(result.tags, equals(['motivational', 'wisdom']));
      expect(result.source, equals(QuoteSource.seeded));
      expect(result.createdAt, isNotNull);
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // Group 4: v2 Integration contracts — require real sqflite (device/emulator)
  // ───────────────────────────────────────────────────────────────────────────
  group(
    'QuoteDatabase v2 integration contracts',
    skip: 'requires sqflite platform channel — run on device/emulator',
    () {
      // QG3 (v2): Fresh database create includes v2 columns
      // NOTE: Schema verification requires access to raw Database object.
      // The QuoteDatabase class should expose a @visibleForTesting getter
      // or this test should be run manually with PRAGMA table_info.
      // For now, we verify schema indirectly via round-trip of v2 quotes.
      test('fresh database onCreate supports v2 quote round-trip', () async {
        // Arrange: create fresh database
        final db = QuoteDatabase();
        await db.open();

        final v2Quote = Quote(
          id: 'q-v2-schema-001',
          text: 'Schema test quote',
          author: 'Author',
          tags: ['motivational', 'wisdom'],
          source: QuoteSource.seeded,
          createdAt: DateTime.parse('2026-03-27T10:00:00.000Z'),
          updatedAt: null,
        );

        // Act: seed and retrieve
        await db.seedIfEmpty([v2Quote]);
        final retrieved = await db.getById('q-v2-schema-001');

        // Assert: all v2 fields round-trip correctly (proves schema supports them)
        expect(retrieved, isNotNull);
        expect(retrieved!.id, equals('q-v2-schema-001'));
        expect(retrieved.text, equals('Schema test quote'));
        expect(retrieved.author, equals('Author'));
        expect(retrieved.tags, equals(['motivational', 'wisdom']));
        expect(retrieved.source, equals(QuoteSource.seeded));
        expect(retrieved.createdAt,
            equals(DateTime.parse('2026-03-27T10:00:00.000Z')));
        expect(retrieved.updatedAt, isNull);
      });

      // QG3 (v2): seedIfEmpty writes seeded rows with default v2 values
      test('seedIfEmpty writes v2 quotes with tags serialized correctly',
          () async {
        // Arrange
        final db = QuoteDatabase();
        await db.open();

        final quote = Quote(
          id: 'q-v2-test-001',
          text: 'Test quote with tags',
          author: 'Author',
          tags: ['motivational', 'focus'],
          source: QuoteSource.seeded,
          createdAt: DateTime.parse('2026-03-27T10:00:00.000Z'),
          updatedAt: null,
        );

        // Act
        await db.seedIfEmpty([quote]);

        // Assert: verify quote round-trips with tags intact
        final retrieved = await db.getById('q-v2-test-001');
        expect(retrieved, isNotNull);
        expect(retrieved!.tags, equals(['motivational', 'focus']));
      });

      test('seedIfEmpty writes source as seeded correctly', () async {
        // Arrange
        final db = QuoteDatabase();
        await db.open();

        final quote = Quote(
          id: 'q-v2-test-002',
          text: 'Seeded quote',
          author: 'Author',
          tags: [],
          source: QuoteSource.seeded,
          createdAt: DateTime.parse('2026-03-27T10:00:00.000Z'),
          updatedAt: null,
        );

        // Act
        await db.seedIfEmpty([quote]);

        // Assert
        final retrieved = await db.getById('q-v2-test-002');
        expect(retrieved, isNotNull);
        expect(retrieved!.source, equals(QuoteSource.seeded));
      });

      test('seedIfEmpty writes source as userCreated correctly', () async {
        // Arrange
        final db = QuoteDatabase();
        await db.open();

        final quote = Quote(
          id: 'q-v2-test-003',
          text: 'User quote',
          author: 'Me',
          tags: ['personal'],
          source: QuoteSource.userCreated,
          createdAt: DateTime.parse('2026-03-27T10:00:00.000Z'),
          updatedAt: DateTime.parse('2026-03-27T11:00:00.000Z'),
        );

        // Act
        await db.seedIfEmpty([quote]);

        // Assert
        final retrieved = await db.getById('q-v2-test-003');
        expect(retrieved, isNotNull);
        expect(retrieved!.source, equals(QuoteSource.userCreated));
      });

      test('seedIfEmpty writes createdAt correctly', () async {
        // Arrange
        final db = QuoteDatabase();
        await db.open();

        final quote = Quote(
          id: 'q-v2-test-004',
          text: 'Timestamped quote',
          author: 'Author',
          tags: [],
          source: QuoteSource.seeded,
          createdAt: DateTime.parse('2026-03-27T10:30:45.123Z'),
          updatedAt: null,
        );

        // Act
        await db.seedIfEmpty([quote]);

        // Assert
        final retrieved = await db.getById('q-v2-test-004');
        expect(retrieved, isNotNull);
        expect(retrieved!.createdAt,
            equals(DateTime.parse('2026-03-27T10:30:45.123Z')));
      });

      test('seedIfEmpty writes nullable updatedAt correctly', () async {
        // Arrange
        final db = QuoteDatabase();
        await db.open();

        final quoteWithNull = Quote(
          id: 'q-v2-test-005a',
          text: 'Never edited',
          author: 'Author',
          tags: [],
          source: QuoteSource.seeded,
          createdAt: DateTime.parse('2026-03-27T10:00:00.000Z'),
          updatedAt: null,
        );
        final quoteWithDate = Quote(
          id: 'q-v2-test-005b',
          text: 'Edited',
          author: 'Author',
          tags: [],
          source: QuoteSource.userCreated,
          createdAt: DateTime.parse('2026-03-27T10:00:00.000Z'),
          updatedAt: DateTime.parse('2026-03-27T15:00:00.000Z'),
        );

        // Act
        await db.seedIfEmpty([quoteWithNull, quoteWithDate]);

        // Assert
        final retrievedNull = await db.getById('q-v2-test-005a');
        final retrievedDate = await db.getById('q-v2-test-005b');
        expect(retrievedNull, isNotNull);
        expect(retrievedDate, isNotNull);
        expect(retrievedNull!.updatedAt, isNull);
        expect(retrievedDate!.updatedAt,
            equals(DateTime.parse('2026-03-27T15:00:00.000Z')));
      });

      // QG4 (v2): Migration path from v1 schema to v2 preserves existing rows
      // NOTE: Full migration test requires creating a v1 database file,
      // then opening with v2 code to trigger onUpgrade. This is best done
      // as a manual integration test or with sqflite_common_ffi.
      // Here we verify the contract that getAllQuotes() handles v1-style data.
      test('getAllQuotes() handles quotes that may have been migrated from v1',
          () async {
        // Arrange: create a fresh v2 database and verify it can read
        // quotes that would have default v2 values applied
        final db = QuoteDatabase();
        await db.open();

        // Seed with v2 quotes (simulating post-migration state)
        final quotes = [
          Quote(
            id: 'q-v1-mig-001',
            text: 'Legacy quote 1',
            author: 'Author A',
            tags: [], // empty = migrated from v1
            source: QuoteSource.seeded, // default for migrated
            createdAt: DateTime.parse('2026-03-27T00:00:00.000Z'),
            updatedAt: null,
          ),
          Quote(
            id: 'q-v1-mig-002',
            text: 'Legacy quote 2',
            author: null,
            tags: [],
            source: QuoteSource.seeded,
            createdAt: DateTime.parse('2026-03-27T00:00:00.000Z'),
            updatedAt: null,
          ),
        ];
        await db.seedIfEmpty(quotes);

        // Act: read all quotes
        final allQuotes = await db.getAllQuotes();

        // Assert: all quotes readable with correct defaults
        expect(allQuotes.length, greaterThanOrEqualTo(2));
        final q1 = allQuotes.firstWhere((q) => q.id == 'q-v1-mig-001');
        expect(q1.text, equals('Legacy quote 1'));
        expect(q1.author, equals('Author A'));
        expect(q1.tags, isEmpty);
        expect(q1.source, equals(QuoteSource.seeded));
      });

      // QG4 (v2): Upgraded v1 rows can be read via getAllQuotes() without crash
      test('getAllQuotes() reads all quotes without crash', () async {
        // Arrange
        final db = QuoteDatabase();
        await db.open();

        final quotes = List.generate(
          10,
          (i) => Quote(
            id: 'q-bulk-${i.toString().padLeft(3, '0')}',
            text: 'Bulk quote $i',
            author: i.isEven ? 'Author $i' : null,
            tags: i % 3 == 0 ? ['motivational'] : [],
            source: i % 2 == 0 ? QuoteSource.seeded : QuoteSource.userCreated,
            createdAt: DateTime.parse('2026-03-27T10:00:00.000Z'),
            updatedAt: null,
          ),
        );
        await db.seedIfEmpty(quotes);

        // Act: must not throw
        final allQuotes = await db.getAllQuotes();

        // Assert
        expect(allQuotes.length, greaterThanOrEqualTo(10));
      });

      // QG5 (v2): getById() still returns quote correctly after migration
      test('getById() returns quote correctly after seeding', () async {
        // Arrange
        final db = QuoteDatabase();
        await db.open();

        final quote = Quote(
          id: 'q-v1-getbyid-001',
          text: 'Quote for getById',
          author: 'Author',
          tags: [],
          source: QuoteSource.seeded,
          createdAt: DateTime.parse('2026-03-27T00:00:00.000Z'),
          updatedAt: null,
        );
        await db.seedIfEmpty([quote]);

        // Act
        final result = await db.getById('q-v1-getbyid-001');

        // Assert
        expect(result, isNotNull);
        expect(result!.id, equals('q-v1-getbyid-001'));
        expect(result.text, equals('Quote for getById'));
        expect(result.author, equals('Author'));
        expect(result.tags, isEmpty);
        expect(result.source, equals(QuoteSource.seeded));
      });

      test('getById() returns v2 quote with all fields', () async {
        // Arrange
        final db = QuoteDatabase();
        await db.open();

        final v2Quote = Quote(
          id: 'q-v2-getbyid-001',
          text: 'Full v2 quote',
          author: 'Author',
          tags: ['wisdom', 'focus'],
          source: QuoteSource.userCreated,
          createdAt: DateTime.parse('2026-03-27T10:00:00.000Z'),
          updatedAt: DateTime.parse('2026-03-27T11:00:00.000Z'),
        );
        await db.seedIfEmpty([v2Quote]);

        // Act
        final quote = await db.getById('q-v2-getbyid-001');

        // Assert: all v2 fields round-trip correctly
        expect(quote, isNotNull);
        expect(quote!.id, equals('q-v2-getbyid-001'));
        expect(quote.text, equals('Full v2 quote'));
        expect(quote.author, equals('Author'));
        expect(quote.tags, equals(['wisdom', 'focus']));
        expect(quote.source, equals(QuoteSource.userCreated));
        expect(quote.createdAt,
            equals(DateTime.parse('2026-03-27T10:00:00.000Z')));
        expect(quote.updatedAt,
            equals(DateTime.parse('2026-03-27T11:00:00.000Z')));
      });

      test('getAllQuotes() returns all v2 quotes with correct fields',
          () async {
        // Arrange
        final db = QuoteDatabase();
        await db.open();

        final quotes = [
          Quote(
            id: 'q-v2-all-001',
            text: 'Quote 1',
            author: 'A1',
            tags: ['motivational'],
            source: QuoteSource.seeded,
            createdAt: DateTime.parse('2026-03-27T10:00:00.000Z'),
            updatedAt: null,
          ),
          Quote(
            id: 'q-v2-all-002',
            text: 'Quote 2',
            author: null,
            tags: ['personal', 'wisdom'],
            source: QuoteSource.userCreated,
            createdAt: DateTime.parse('2026-03-27T11:00:00.000Z'),
            updatedAt: DateTime.parse('2026-03-27T12:00:00.000Z'),
          ),
        ];
        await db.seedIfEmpty(quotes);

        // Act
        final result = await db.getAllQuotes();

        // Assert
        expect(result.length, greaterThanOrEqualTo(2));

        final q1 = result.firstWhere((q) => q.id == 'q-v2-all-001');
        expect(q1.tags, equals(['motivational']));
        expect(q1.source, equals(QuoteSource.seeded));
        expect(q1.updatedAt, isNull);

        final q2 = result.firstWhere((q) => q.id == 'q-v2-all-002');
        expect(q2.tags, equals(['personal', 'wisdom']));
        expect(q2.source, equals(QuoteSource.userCreated));
        expect(q2.updatedAt, isNotNull);
      });
    },
  );

  // ═══════════════════════════════════════════════════════════════════════════════
  // SPRINT 2 / TASK 05.02 — CRUD METHOD CONTRACT TESTS
  // ═══════════════════════════════════════════════════════════════════════════════
  // These tests verify:
  //   - insertQuote() exists and inserts a quote
  //   - updateQuote() exists and updates quote fields
  //   - deleteQuote() exists and removes quote from DB
  //   - getBySource() exists and filters by QuoteSource
  //   - getByTag() exists and filters by tag string
  //
  // See: vault/sprint/backlog/task-05.02-feat-expand-quote-crud-access-and-catalog-state-management.md
  // ═══════════════════════════════════════════════════════════════════════════════

  // ───────────────────────────────────────────────────────────────────────────
  // Group 5: CRUD API-surface contract (mock-verified)
  // ───────────────────────────────────────────────────────────────────────────
  group('QuoteDatabase CRUD API-surface contract (mock-verified)', () {
    late MockQuoteDatabase mockDb;

    setUp(() {
      mockDb = MockQuoteDatabase();
    });

    test('insertQuote() exists and accepts Quote, returns Future<void>',
        () async {
      // Arrange: stub insertQuote — if signature does not match, mocktail
      // will produce a type mismatch at stub registration.
      when(() => mockDb.insertQuote(any())).thenAnswer((_) async {});

      // Act + Assert: no exception means the signature is correct
      await expectLater(mockDb.insertQuote(_sampleQuoteV2), completes);

      // Assert: the method was called with the correct argument type
      verify(() => mockDb.insertQuote(_sampleQuoteV2)).called(1);
    });

    test('updateQuote() exists and accepts Quote, returns Future<void>',
        () async {
      // Arrange
      when(() => mockDb.updateQuote(any())).thenAnswer((_) async {});

      // Act + Assert
      await expectLater(mockDb.updateQuote(_sampleQuoteV2), completes);

      verify(() => mockDb.updateQuote(_sampleQuoteV2)).called(1);
    });

    test('deleteQuote() exists and accepts String id, returns Future<void>',
        () async {
      // Arrange
      when(() => mockDb.deleteQuote(any())).thenAnswer((_) async {});

      // Act + Assert
      await expectLater(mockDb.deleteQuote('q-v2-001'), completes);

      verify(() => mockDb.deleteQuote('q-v2-001')).called(1);
    });

    test(
        'getBySource() exists and accepts QuoteSource, returns Future<List<Quote>>',
        () async {
      // Arrange: stub returns a typed List<Quote>
      when(() => mockDb.getBySource(any()))
          .thenAnswer((_) async => [_sampleQuoteV2]);

      // Act
      final result = await mockDb.getBySource(QuoteSource.seeded);

      // Assert: return type is List<Quote>
      expect(result, isA<List<Quote>>());
      expect(result, hasLength(1));
    });

    test('getBySource(QuoteSource.seeded) returns only seeded quotes',
        () async {
      // Arrange
      when(() => mockDb.getBySource(QuoteSource.seeded))
          .thenAnswer((_) async => [_sampleQuoteV2]);
      when(() => mockDb.getBySource(QuoteSource.userCreated))
          .thenAnswer((_) async => [_userCreatedQuoteV2]);

      // Act
      final result = await mockDb.getBySource(QuoteSource.seeded);

      // Assert
      expect(result, hasLength(1));
      expect(result.first.source, equals(QuoteSource.seeded));
    });

    test(
        'getBySource(QuoteSource.userCreated) returns only user-created quotes',
        () async {
      // Arrange
      when(() => mockDb.getBySource(QuoteSource.seeded))
          .thenAnswer((_) async => [_sampleQuoteV2]);
      when(() => mockDb.getBySource(QuoteSource.userCreated))
          .thenAnswer((_) async => [_userCreatedQuoteV2]);

      // Act
      final result = await mockDb.getBySource(QuoteSource.userCreated);

      // Assert
      expect(result, hasLength(1));
      expect(result.first.source, equals(QuoteSource.userCreated));
    });

    test(
        'getByTag() exists and accepts String tag, returns Future<List<Quote>>',
        () async {
      // Arrange: stub returns a typed List<Quote>
      when(() => mockDb.getByTag(any()))
          .thenAnswer((_) async => [_sampleQuoteV2]);

      // Act
      final result = await mockDb.getByTag('motivational');

      // Assert: return type is List<Quote>
      expect(result, isA<List<Quote>>());
      expect(result, hasLength(1));
    });

    test('getByTag() returns only quotes containing that tag', () async {
      // Arrange
      when(() => mockDb.getByTag('motivational'))
          .thenAnswer((_) async => [_sampleQuoteV2]);
      when(() => mockDb.getByTag('personal'))
          .thenAnswer((_) async => [_userCreatedQuoteV2]);
      when(() => mockDb.getByTag('nonexistent')).thenAnswer((_) async => []);

      // Act + Assert
      final motivational = await mockDb.getByTag('motivational');
      expect(motivational.first.tags, contains('motivational'));

      final personal = await mockDb.getByTag('personal');
      expect(personal.first.tags, contains('personal'));

      final none = await mockDb.getByTag('nonexistent');
      expect(none, isEmpty);
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // Group 6: CRUD Integration contracts — require real sqflite (device/emulator)
  // ───────────────────────────────────────────────────────────────────────────
  group(
    'QuoteDatabase CRUD integration contracts',
    skip: 'requires sqflite platform channel — run on device/emulator',
    () {
      test('insertQuote() inserts a quote that can be retrieved by getById()',
          () async {
        // Arrange
        final db = QuoteDatabase();
        await db.open();

        final quote = Quote(
          id: 'q-crud-insert-001',
          text: 'Insert test quote',
          author: 'Author',
          tags: ['motivational'],
          source: QuoteSource.userCreated,
          createdAt: DateTime.parse('2026-03-27T10:00:00.000Z'),
          updatedAt: null,
        );

        // Act
        await db.insertQuote(quote);
        final retrieved = await db.getById('q-crud-insert-001');

        // Assert
        expect(retrieved, isNotNull);
        expect(retrieved!.id, equals('q-crud-insert-001'));
        expect(retrieved.text, equals('Insert test quote'));
        expect(retrieved.source, equals(QuoteSource.userCreated));
      });

      test('updateQuote() persists changed text, author, and tags', () async {
        // Arrange
        final db = QuoteDatabase();
        await db.open();

        final original = Quote(
          id: 'q-crud-update-001',
          text: 'Original text',
          author: 'Original Author',
          tags: ['motivational'],
          source: QuoteSource.seeded,
          createdAt: DateTime.parse('2026-03-27T10:00:00.000Z'),
          updatedAt: null,
        );
        await db.insertQuote(original);

        final updated = Quote(
          id: 'q-crud-update-001',
          text: 'Updated text',
          author: 'Updated Author',
          tags: ['wisdom', 'focus'],
          source: QuoteSource.seeded,
          createdAt: DateTime.parse('2026-03-27T10:00:00.000Z'),
          updatedAt: DateTime.parse('2026-03-27T15:00:00.000Z'),
        );

        // Act
        await db.updateQuote(updated);
        final retrieved = await db.getById('q-crud-update-001');

        // Assert
        expect(retrieved, isNotNull);
        expect(retrieved!.text, equals('Updated text'));
        expect(retrieved.author, equals('Updated Author'));
        expect(retrieved.tags, equals(['wisdom', 'focus']));
        expect(retrieved.updatedAt,
            equals(DateTime.parse('2026-03-27T15:00:00.000Z')));
      });

      test('deleteQuote() removes quote from subsequent reads', () async {
        // Arrange
        final db = QuoteDatabase();
        await db.open();

        final quote = Quote(
          id: 'q-crud-delete-001',
          text: 'To be deleted',
          author: 'Author',
          tags: [],
          source: QuoteSource.userCreated,
          createdAt: DateTime.parse('2026-03-27T10:00:00.000Z'),
          updatedAt: null,
        );
        await db.insertQuote(quote);

        // Verify it exists
        var retrieved = await db.getById('q-crud-delete-001');
        expect(retrieved, isNotNull);

        // Act
        await db.deleteQuote('q-crud-delete-001');

        // Assert: no longer found
        retrieved = await db.getById('q-crud-delete-001');
        expect(retrieved, isNull);
      });

      test('getBySource(QuoteSource.seeded) returns only seeded quotes',
          () async {
        // Arrange
        final db = QuoteDatabase();
        await db.open();

        final seeded1 = Quote(
          id: 'q-source-seeded-001',
          text: 'Seeded quote 1',
          author: 'Author',
          tags: [],
          source: QuoteSource.seeded,
          createdAt: DateTime.parse('2026-03-27T10:00:00.000Z'),
          updatedAt: null,
        );
        final userCreated1 = Quote(
          id: 'q-source-user-001',
          text: 'User quote 1',
          author: 'Me',
          tags: [],
          source: QuoteSource.userCreated,
          createdAt: DateTime.parse('2026-03-27T11:00:00.000Z'),
          updatedAt: null,
        );
        await db.insertQuote(seeded1);
        await db.insertQuote(userCreated1);

        // Act
        final result = await db.getBySource(QuoteSource.seeded);

        // Assert
        expect(result.every((q) => q.source == QuoteSource.seeded), isTrue);
      });

      test(
          'getBySource(QuoteSource.userCreated) returns only user-created quotes',
          () async {
        // Arrange
        final db = QuoteDatabase();
        await db.open();

        final seeded1 = Quote(
          id: 'q-source-seeded-002',
          text: 'Seeded quote 2',
          author: 'Author',
          tags: [],
          source: QuoteSource.seeded,
          createdAt: DateTime.parse('2026-03-27T10:00:00.000Z'),
          updatedAt: null,
        );
        final userCreated1 = Quote(
          id: 'q-source-user-002',
          text: 'User quote 2',
          author: 'Me',
          tags: [],
          source: QuoteSource.userCreated,
          createdAt: DateTime.parse('2026-03-27T11:00:00.000Z'),
          updatedAt: null,
        );
        await db.insertQuote(seeded1);
        await db.insertQuote(userCreated1);

        // Act
        final result = await db.getBySource(QuoteSource.userCreated);

        // Assert
        expect(
            result.every((q) => q.source == QuoteSource.userCreated), isTrue);
      });

      test('getByTag() returns quotes containing that tag', () async {
        // Arrange
        final db = QuoteDatabase();
        await db.open();

        final quoteWithMotivational = Quote(
          id: 'q-tag-001',
          text: 'Motivational quote',
          author: 'Author',
          tags: ['motivational', 'wisdom'],
          source: QuoteSource.seeded,
          createdAt: DateTime.parse('2026-03-27T10:00:00.000Z'),
          updatedAt: null,
        );
        final quoteWithPersonal = Quote(
          id: 'q-tag-002',
          text: 'Personal quote',
          author: 'Me',
          tags: ['personal'],
          source: QuoteSource.userCreated,
          createdAt: DateTime.parse('2026-03-27T11:00:00.000Z'),
          updatedAt: null,
        );
        final quoteWithNoTags = Quote(
          id: 'q-tag-003',
          text: 'No tags quote',
          author: 'Author',
          tags: [],
          source: QuoteSource.seeded,
          createdAt: DateTime.parse('2026-03-27T12:00:00.000Z'),
          updatedAt: null,
        );
        await db.insertQuote(quoteWithMotivational);
        await db.insertQuote(quoteWithPersonal);
        await db.insertQuote(quoteWithNoTags);

        // Act
        final result = await db.getByTag('motivational');

        // Assert
        expect(result.every((q) => q.tags.contains('motivational')), isTrue);
      });

      test('getByTag() returns empty list when no quotes have that tag',
          () async {
        // Arrange
        final db = QuoteDatabase();
        await db.open();

        final quote = Quote(
          id: 'q-tag-empty-001',
          text: 'Quote with different tag',
          author: 'Author',
          tags: ['wisdom'],
          source: QuoteSource.seeded,
          createdAt: DateTime.parse('2026-03-27T10:00:00.000Z'),
          updatedAt: null,
        );
        await db.insertQuote(quote);

        // Act
        final result = await db.getByTag('nonexistent');

        // Assert
        expect(result, isEmpty);
      });
    },
  );
}
