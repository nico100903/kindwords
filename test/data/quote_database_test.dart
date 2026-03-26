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

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:kindwords/data/quote_database.dart';
import 'package:kindwords/models/quote.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Mock — used for API-surface contract tests that don't need a real DB
// ─────────────────────────────────────────────────────────────────────────────
class MockQuoteDatabase extends Mock implements QuoteDatabase {}

// ─────────────────────────────────────────────────────────────────────────────
// Fixtures
// ─────────────────────────────────────────────────────────────────────────────
const _sampleQuote = Quote(id: 'q001', text: 'Sample text', author: 'Author');
const _anonymousQuote = Quote(id: 'q099', text: 'Anonymous text', author: null);

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

    test('seedIfEmpty() exists and accepts List<Quote>, returns Future<void>', () async {
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

    test('getById() exists and accepts String id, returns Future<Quote?>', () async {
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

    test('getAllQuotes() returns List<Quote> with nullable author fields intact', () async {
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
      test('getAllQuotes() returns at least 100 quotes after seeding kAllQuotes',
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
          reason: 'QG4: getAllQuotes() must return >=100 after seeding 100 quotes',
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
          reason: 'QG5: getById must return non-null for a quote that was seeded',
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
      test('getById returns anonymous quote with null author correctly', () async {
        final db = QuoteDatabase();
        await db.open();

        const anon = Quote(id: 'q050', text: 'Anonymous wisdom.', author: null);
        await db.seedIfEmpty([anon]);

        final result = await db.getById('q050');

        expect(result, isNotNull);
        expect(result!.author, isNull,
            reason: 'author TEXT column is nullable — must round-trip as null');
      });
    },
  );
}
