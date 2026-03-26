// Wave R2 — Contract tests for Quote.toMap() and Quote.fromMap()
//
// These tests FAIL until the coder adds toMap() and fromMap() to Quote.
// They define the sqflite serialization contract for the DB schema:
//
//   CREATE TABLE quotes (id TEXT PRIMARY KEY, text TEXT NOT NULL, author TEXT)
//
// Do NOT add toMap/fromMap to quote.dart — that is the coder's job.
//
// ─────────────────────────────────────────────────────────────────────────────
// Sprint 2 / Task 05.01 — v2 Schema Extension
// ─────────────────────────────────────────────────────────────────────────────
// These tests extend the v1 contract to support:
//   - tags: List<String> (stored as JSON array string in DB)
//   - source: QuoteSource enum (stored as string 'seeded' or 'userCreated')
//   - createdAt: DateTime (required, stored as ISO-8601 string)
//   - updatedAt: DateTime? (nullable, stored as ISO-8601 string or null)
//
// Quality Gates from task-05.01:
//   QG1: fromMap() handles v1 rows (missing tags/source/created_at/updated_at)
//        without crashing, providing sensible defaults
//   QG2: Round-trip integrity: fromMap(toMap(quote)) produces equal quote
//   QG5: Equality remains id-based regardless of new field values

import 'package:flutter_test/flutter_test.dart';
import 'package:kindwords/models/quote.dart';

void main() {
  // ─────────────────────────────────────────────────────────────────────────
  // Group 1: toMap()
  // ─────────────────────────────────────────────────────────────────────────
  group('Quote.toMap()', () {
    test('produces correct map when author is present', () {
      const quote = Quote(id: 'q1', text: 'Hello', author: 'Alice');

      // ignore: unnecessary_cast — toMap() does not exist yet; compile fails here
      final map = quote.toMap();

      expect(map['id'], equals('q1'));
      expect(map['text'], equals('Hello'));
      expect(map['author'], equals('Alice'));
      expect(map.length, equals(3));
    });

    test('produces map with null author value when author is null', () {
      // sqflite requires the 'author' key to be present with a null value
      // so the nullable column is written correctly (not omitted).
      const quote = Quote(id: 'q2', text: 'Hi', author: null);

      final map = quote.toMap();

      expect(map['id'], equals('q2'));
      expect(map['text'], equals('Hi'));
      expect(
        map.containsKey('author'),
        isTrue,
        reason: "sqflite nullable column requires key present, value null",
      );
      expect(map['author'], isNull);
      expect(map.length, equals(3));
    });

    test('map values have correct runtime types', () {
      const quote = Quote(id: 'q3', text: 'Test quote', author: 'Bob');

      final map = quote.toMap();

      expect(map['id'], isA<String>());
      expect(map['text'], isA<String>());
      expect(map['author'], isA<String>());
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Group 2: Quote.fromMap()
  // ─────────────────────────────────────────────────────────────────────────
  group('Quote.fromMap()', () {
    test('reconstructs a Quote with author from a DB row map', () {
      final row = <String, Object?>{
        'id': 'q1',
        'text': 'Hello',
        'author': 'Alice',
      };

      final quote = Quote.fromMap(row);

      expect(quote.id, equals('q1'));
      expect(quote.text, equals('Hello'));
      expect(quote.author, equals('Alice'));
    });

    test('reconstructs a Quote with null author from a DB row map', () {
      final row = <String, Object?>{'id': 'q2', 'text': 'Hi', 'author': null};

      final quote = Quote.fromMap(row);

      expect(quote.id, equals('q2'));
      expect(quote.text, equals('Hi'));
      expect(quote.author, isNull);
    });

    test('produces an immutable Quote instance', () {
      final row = <String, Object?>{
        'id': 'q4',
        'text': 'Immutable',
        'author': 'Dev',
      };

      final quote = Quote.fromMap(row);

      // Quote fields are final — verify the returned object is a proper Quote
      expect(quote, isA<Quote>());
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Group 3: Round-trip (toMap → fromMap)
  // ─────────────────────────────────────────────────────────────────────────
  group('Quote round-trip: fromMap(toMap(quote)) == quote', () {
    test('round-trip preserves equality for quote with author', () {
      const original = Quote(id: 'q1', text: 'Hello', author: 'Alice');

      final roundTripped = Quote.fromMap(original.toMap());

      expect(
        roundTripped,
        equals(original),
        reason: 'Quote equality is id-based; round-trip must not change id',
      );
    });

    test('round-trip preserves equality for quote with null author', () {
      const original = Quote(id: 'q2', text: 'Hi', author: null);

      final roundTripped = Quote.fromMap(original.toMap());

      expect(roundTripped, equals(original));
      expect(roundTripped.author, isNull);
    });

    test('round-trip preserves all field values for quote with author', () {
      const original =
          Quote(id: 'q5', text: 'Full fidelity check', author: 'Carol');

      final roundTripped = Quote.fromMap(original.toMap());

      expect(roundTripped.id, equals(original.id));
      expect(roundTripped.text, equals(original.text));
      expect(roundTripped.author, equals(original.author));
    });

    test('round-trip preserves all field values for quote with null author',
        () {
      const original = Quote(id: 'q6', text: 'Anonymous quote', author: null);

      final roundTripped = Quote.fromMap(original.toMap());

      expect(roundTripped.id, equals(original.id));
      expect(roundTripped.text, equals(original.text));
      expect(roundTripped.author, isNull);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Group 4: Existing equality contract (must not be broken by new methods)
  // ─────────────────────────────────────────────────────────────────────────
  group('Quote equality contract — must survive serialization additions', () {
    test('two Quotes with same id are equal regardless of text/author', () {
      const a = Quote(id: 'q1', text: 'Original text', author: 'Alice');
      const b = Quote(id: 'q1', text: 'Different text', author: 'Bob');

      expect(a, equals(b), reason: 'equality is id-only per existing contract');
    });

    test('two Quotes with different ids are not equal', () {
      const a = Quote(id: 'q1', text: 'Hello', author: 'Alice');
      const b = Quote(id: 'q2', text: 'Hello', author: 'Alice');

      expect(a, isNot(equals(b)));
    });

    test('hashCode is consistent with equality (same id → same hashCode)', () {
      const a = Quote(id: 'q1', text: 'Text A', author: 'X');
      const b = Quote(id: 'q1', text: 'Text B', author: 'Y');

      expect(a.hashCode, equals(b.hashCode));
    });

    test('a fromMap-reconstructed quote equals the original by id', () {
      const original = Quote(id: 'q7', text: 'Equality probe', author: 'Dev');

      final reconstructed = Quote.fromMap(original.toMap());

      expect(reconstructed, equals(original));
      expect(reconstructed.hashCode, equals(original.hashCode));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════════
  // SPRINT 2 / TASK 05.01 — v2 SCHEMA EXTENSION TESTS
  // ═══════════════════════════════════════════════════════════════════════════════
  // These tests FAIL until the coder extends Quote with:
  //   - tags: List<String>
  //   - source: QuoteSource enum
  //   - createdAt: DateTime
  //   - updatedAt: DateTime?
  //
  // See: vault/sprint/backlog/task-05.01-feat-extend-quote-entity-and-migrate-local-quote-storage.md
  // ═══════════════════════════════════════════════════════════════════════════════

  // ─────────────────────────────────────────────────────────────────────────
  // Group 5: v2 Quote construction with new fields
  // ─────────────────────────────────────────────────────────────────────────
  group('Quote v2 construction — new fields', () {
    test('accepts tags list in constructor', () {
      // Arrange + Act: create quote with tags
      final quote = Quote(
        id: 'q-v2-001',
        text: 'Motivational text',
        author: 'Author',
        tags: ['motivational', 'focus'],
        source: QuoteSource.seeded,
        createdAt: DateTime.parse('2026-03-27T10:00:00.000Z'),
        updatedAt: null,
      );

      // Assert: tags field exists and has correct values
      expect(quote.tags, equals(['motivational', 'focus']));
      expect(quote.tags, isA<List<String>>());
    });

    test('accepts empty tags list', () {
      final quote = Quote(
        id: 'q-v2-002',
        text: 'Quote without tags',
        author: null,
        tags: [],
        source: QuoteSource.userCreated,
        createdAt: DateTime.parse('2026-03-27T11:00:00.000Z'),
        updatedAt: null,
      );

      expect(quote.tags, isEmpty);
    });

    test('accepts QuoteSource.seeded enum value', () {
      final quote = Quote(
        id: 'q-v2-003',
        text: 'Seeded quote',
        author: 'Famous',
        tags: [],
        source: QuoteSource.seeded,
        createdAt: DateTime.parse('2026-03-27T12:00:00.000Z'),
        updatedAt: null,
      );

      expect(quote.source, equals(QuoteSource.seeded));
    });

    test('accepts QuoteSource.userCreated enum value', () {
      final quote = Quote(
        id: 'q-v2-004',
        text: 'User created quote',
        author: 'Me',
        tags: ['personal'],
        source: QuoteSource.userCreated,
        createdAt: DateTime.parse('2026-03-27T13:00:00.000Z'),
        updatedAt: DateTime.parse('2026-03-27T14:00:00.000Z'),
      );

      expect(quote.source, equals(QuoteSource.userCreated));
    });

    test('accepts createdAt DateTime', () {
      final createdAt = DateTime.parse('2026-03-27T10:00:00.000Z');
      final quote = Quote(
        id: 'q-v2-005',
        text: 'Quote with timestamp',
        author: null,
        tags: [],
        source: QuoteSource.seeded,
        createdAt: createdAt,
        updatedAt: null,
      );

      expect(quote.createdAt, equals(createdAt));
    });

    test('accepts nullable updatedAt DateTime', () {
      // Case 1: null updatedAt (never edited)
      final quote1 = Quote(
        id: 'q-v2-006a',
        text: 'Never edited',
        author: 'Author',
        tags: [],
        source: QuoteSource.seeded,
        createdAt: DateTime.parse('2026-03-27T10:00:00.000Z'),
        updatedAt: null,
      );
      expect(quote1.updatedAt, isNull);

      // Case 2: non-null updatedAt (has been edited)
      final quote2 = Quote(
        id: 'q-v2-006b',
        text: 'Edited quote',
        author: 'Author',
        tags: ['wisdom'],
        source: QuoteSource.userCreated,
        createdAt: DateTime.parse('2026-03-27T10:00:00.000Z'),
        updatedAt: DateTime.parse('2026-03-27T15:00:00.000Z'),
      );
      expect(quote2.updatedAt, isNotNull);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Group 6: v2 toMap() serialization
  // ─────────────────────────────────────────────────────────────────────────
  group('Quote.toMap() v2 — serializes new fields correctly', () {
    test('serializes tags as JSON array string, not raw list', () {
      // Arrange
      final quote = Quote(
        id: 'q-v2-010',
        text: 'Quote with tags',
        author: 'Author',
        tags: ['motivational', 'wisdom', 'focus'],
        source: QuoteSource.seeded,
        createdAt: DateTime.parse('2026-03-27T10:00:00.000Z'),
        updatedAt: null,
      );

      // Act
      final map = quote.toMap();

      // Assert: tags must be a JSON string, NOT a Dart List
      expect(map['tags'], isA<String>(),
          reason: 'tags must be JSON-encoded string for sqflite');
      expect(map['tags'], equals('["motivational","wisdom","focus"]'));
    });

    test('serializes empty tags list as empty JSON array string', () {
      final quote = Quote(
        id: 'q-v2-011',
        text: 'No tags',
        author: null,
        tags: [],
        source: QuoteSource.seeded,
        createdAt: DateTime.parse('2026-03-27T10:00:00.000Z'),
        updatedAt: null,
      );

      final map = quote.toMap();

      expect(map['tags'], equals('[]'),
          reason: 'empty tags list serializes as empty JSON array');
    });

    test('serializes source as string value "seeded"', () {
      final quote = Quote(
        id: 'q-v2-012',
        text: 'Seeded quote',
        author: 'Author',
        tags: [],
        source: QuoteSource.seeded,
        createdAt: DateTime.parse('2026-03-27T10:00:00.000Z'),
        updatedAt: null,
      );

      final map = quote.toMap();

      expect(map['source'], equals('seeded'),
          reason: 'QuoteSource.seeded serializes as string "seeded"');
      expect(map['source'], isA<String>());
    });

    test('serializes source as string value "userCreated"', () {
      final quote = Quote(
        id: 'q-v2-013',
        text: 'User quote',
        author: 'Me',
        tags: ['personal'],
        source: QuoteSource.userCreated,
        createdAt: DateTime.parse('2026-03-27T10:00:00.000Z'),
        updatedAt: DateTime.parse('2026-03-27T11:00:00.000Z'),
      );

      final map = quote.toMap();

      expect(map['source'], equals('userCreated'),
          reason: 'QuoteSource.userCreated serializes as string "userCreated"');
    });

    test('serializes createdAt as ISO-8601 string under key "created_at"', () {
      final createdAt = DateTime.parse('2026-03-27T10:30:45.123Z');
      final quote = Quote(
        id: 'q-v2-014',
        text: 'Timestamped quote',
        author: 'Author',
        tags: [],
        source: QuoteSource.seeded,
        createdAt: createdAt,
        updatedAt: null,
      );

      final map = quote.toMap();

      expect(map['created_at'], isA<String>(),
          reason: 'createdAt must serialize as ISO-8601 string');
      expect(map['created_at'], equals('2026-03-27T10:30:45.123Z'));
    });

    test('serializes updatedAt as ISO-8601 string under key "updated_at"', () {
      final updatedAt = DateTime.parse('2026-03-27T15:45:30.000Z');
      final quote = Quote(
        id: 'q-v2-015',
        text: 'Edited quote',
        author: 'Author',
        tags: [],
        source: QuoteSource.userCreated,
        createdAt: DateTime.parse('2026-03-27T10:00:00.000Z'),
        updatedAt: updatedAt,
      );

      final map = quote.toMap();

      expect(map['updated_at'], isA<String>());
      expect(map['updated_at'], equals('2026-03-27T15:45:30.000Z'));
    });

    test('serializes null updatedAt as null under key "updated_at"', () {
      final quote = Quote(
        id: 'q-v2-016',
        text: 'Never edited',
        author: 'Author',
        tags: [],
        source: QuoteSource.seeded,
        createdAt: DateTime.parse('2026-03-27T10:00:00.000Z'),
        updatedAt: null,
      );

      final map = quote.toMap();

      expect(map.containsKey('updated_at'), isTrue,
          reason: 'updated_at key must be present even when null');
      expect(map['updated_at'], isNull);
    });

    test('v2 map contains all 7 keys for fully populated quote', () {
      final quote = Quote(
        id: 'q-v2-017',
        text: 'Complete quote',
        author: 'Author',
        tags: ['motivational'],
        source: QuoteSource.userCreated,
        createdAt: DateTime.parse('2026-03-27T10:00:00.000Z'),
        updatedAt: DateTime.parse('2026-03-27T11:00:00.000Z'),
      );

      final map = quote.toMap();

      expect(map.keys, containsAll(['id', 'text', 'author', 'tags', 'source', 'created_at', 'updated_at']));
      expect(map.length, equals(7));
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Group 7: v2 fromMap() deserialization with full v2 row
  // ─────────────────────────────────────────────────────────────────────────
  group('Quote.fromMap() v2 — deserializes v2 schema rows', () {
    test('reconstructs quote with tags from v2 row', () {
      final row = <String, Object?>{
        'id': 'q-v2-020',
        'text': 'Quote with tags',
        'author': 'Author',
        'tags': '["motivational","wisdom"]',
        'source': 'seeded',
        'created_at': '2026-03-27T10:00:00.000Z',
        'updated_at': null,
      };

      final quote = Quote.fromMap(row);

      expect(quote.id, equals('q-v2-020'));
      expect(quote.text, equals('Quote with tags'));
      expect(quote.author, equals('Author'));
      expect(quote.tags, equals(['motivational', 'wisdom']));
    });

    test('reconstructs quote with empty tags from v2 row', () {
      final row = <String, Object?>{
        'id': 'q-v2-021',
        'text': 'No tags',
        'author': null,
        'tags': '[]',
        'source': 'seeded',
        'created_at': '2026-03-27T10:00:00.000Z',
        'updated_at': null,
      };

      final quote = Quote.fromMap(row);

      expect(quote.tags, isEmpty);
    });

    test('reconstructs quote with seeded source from v2 row', () {
      final row = <String, Object?>{
        'id': 'q-v2-022',
        'text': 'Seeded',
        'author': 'Author',
        'tags': '[]',
        'source': 'seeded',
        'created_at': '2026-03-27T10:00:00.000Z',
        'updated_at': null,
      };

      final quote = Quote.fromMap(row);

      expect(quote.source, equals(QuoteSource.seeded));
    });

    test('reconstructs quote with userCreated source from v2 row', () {
      final row = <String, Object?>{
        'id': 'q-v2-023',
        'text': 'User created',
        'author': 'Me',
        'tags': '["personal"]',
        'source': 'userCreated',
        'created_at': '2026-03-27T10:00:00.000Z',
        'updated_at': '2026-03-27T11:00:00.000Z',
      };

      final quote = Quote.fromMap(row);

      expect(quote.source, equals(QuoteSource.userCreated));
    });

    test('reconstructs createdAt from ISO-8601 string', () {
      final row = <String, Object?>{
        'id': 'q-v2-024',
        'text': 'Timestamped',
        'author': 'Author',
        'tags': '[]',
        'source': 'seeded',
        'created_at': '2026-03-27T10:30:45.123Z',
        'updated_at': null,
      };

      final quote = Quote.fromMap(row);

      expect(quote.createdAt, equals(DateTime.parse('2026-03-27T10:30:45.123Z')));
    });

    test('reconstructs non-null updatedAt from ISO-8601 string', () {
      final row = <String, Object?>{
        'id': 'q-v2-025',
        'text': 'Edited',
        'author': 'Author',
        'tags': '[]',
        'source': 'userCreated',
        'created_at': '2026-03-27T10:00:00.000Z',
        'updated_at': '2026-03-27T15:45:30.000Z',
      };

      final quote = Quote.fromMap(row);

      expect(quote.updatedAt, equals(DateTime.parse('2026-03-27T15:45:30.000Z')));
    });

    test('reconstructs null updatedAt correctly', () {
      final row = <String, Object?>{
        'id': 'q-v2-026',
        'text': 'Never edited',
        'author': 'Author',
        'tags': '[]',
        'source': 'seeded',
        'created_at': '2026-03-27T10:00:00.000Z',
        'updated_at': null,
      };

      final quote = Quote.fromMap(row);

      expect(quote.updatedAt, isNull);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Group 8: v1 → v2 BACKWARD COMPATIBILITY (QG1)
  // ─────────────────────────────────────────────────────────────────────────
  group('Quote.fromMap() backward compatibility — v1 rows without new columns',
      () {
    test('handles v1 row with only id, text, author (missing tags)', () {
      // This simulates a row from v1 schema that has no 'tags' column
      final v1Row = <String, Object?>{
        'id': 'q-v1-001',
        'text': 'Legacy quote',
        'author': 'Famous Author',
        // tags column missing
        'source': 'seeded', // may or may not be present after migration
        'created_at': '2026-03-27T00:00:00.000Z',
        'updated_at': null,
      };

      // Act + Assert: must not throw
      final quote = Quote.fromMap(v1Row);

      expect(quote.id, equals('q-v1-001'));
      expect(quote.text, equals('Legacy quote'));
      expect(quote.author, equals('Famous Author'));
    });

    test('provides default empty list for missing tags column', () {
      // v1 row missing 'tags' entirely
      final v1Row = <String, Object?>{
        'id': 'q-v1-002',
        'text': 'Old quote',
        'author': 'Author',
      };

      final quote = Quote.fromMap(v1Row);

      expect(quote.tags, isEmpty,
          reason: 'missing tags column must default to empty list');
      expect(quote.tags, isA<List<String>>());
    });

    test('provides default QuoteSource.seeded for missing source column', () {
      // v1 row missing 'source' entirely
      final v1Row = <String, Object?>{
        'id': 'q-v1-003',
        'text': 'Old quote',
        'author': 'Author',
      };

      final quote = Quote.fromMap(v1Row);

      expect(quote.source, equals(QuoteSource.seeded),
          reason: 'missing source column must default to seeded');
    });

    test('provides fallback createdAt for missing created_at column', () {
      // v1 row missing 'created_at'
      final v1Row = <String, Object?>{
        'id': 'q-v1-004',
        'text': 'Old quote',
        'author': 'Author',
      };

      // Act: must not throw, must provide a non-null DateTime
      final quote = Quote.fromMap(v1Row);

      expect(quote.createdAt, isNotNull,
          reason: 'createdAt is required even for v1 rows');
      expect(quote.createdAt, isA<DateTime>());
    });

    test('provides default null for missing updated_at column', () {
      // v1 row missing 'updated_at'
      final v1Row = <String, Object?>{
        'id': 'q-v1-005',
        'text': 'Old quote',
        'author': 'Author',
      };

      final quote = Quote.fromMap(v1Row);

      expect(quote.updatedAt, isNull,
          reason: 'missing updated_at must default to null');
    });

    test('handles completely minimal v1 row (id, text, author only)', () {
      // The most minimal v1 row possible
      final minimalV1Row = <String, Object?>{
        'id': 'q-v1-006',
        'text': 'Minimal v1 quote',
        'author': null,
      };

      // Act: must not throw
      final quote = Quote.fromMap(minimalV1Row);

      // Assert all defaults applied
      expect(quote.id, equals('q-v1-006'));
      expect(quote.text, equals('Minimal v1 quote'));
      expect(quote.author, isNull);
      expect(quote.tags, isEmpty);
      expect(quote.source, equals(QuoteSource.seeded));
      expect(quote.createdAt, isNotNull);
      expect(quote.updatedAt, isNull);
    });

    test('handles v1 row with null author and all new columns missing', () {
      final v1AnonRow = <String, Object?>{
        'id': 'q-v1-007',
        'text': 'Anonymous legacy',
        'author': null,
      };

      final quote = Quote.fromMap(v1AnonRow);

      expect(quote.author, isNull);
      expect(quote.tags, isEmpty);
      expect(quote.source, equals(QuoteSource.seeded));
      expect(quote.createdAt, isNotNull);
      expect(quote.updatedAt, isNull);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Group 9: v2 Round-trip integrity (QG2)
  // ─────────────────────────────────────────────────────────────────────────
  group('Quote v2 round-trip: fromMap(toMap(quote)) preserves all fields', () {
    test('round-trip preserves tags', () {
      final original = Quote(
        id: 'q-rt-001',
        text: 'Quote with tags',
        author: 'Author',
        tags: ['motivational', 'wisdom', 'focus'],
        source: QuoteSource.seeded,
        createdAt: DateTime.parse('2026-03-27T10:00:00.000Z'),
        updatedAt: null,
      );

      final roundTripped = Quote.fromMap(original.toMap());

      expect(roundTripped.tags, equals(['motivational', 'wisdom', 'focus']));
    });

    test('round-trip preserves empty tags', () {
      final original = Quote(
        id: 'q-rt-002',
        text: 'No tags',
        author: 'Author',
        tags: [],
        source: QuoteSource.seeded,
        createdAt: DateTime.parse('2026-03-27T10:00:00.000Z'),
        updatedAt: null,
      );

      final roundTripped = Quote.fromMap(original.toMap());

      expect(roundTripped.tags, isEmpty);
    });

    test('round-trip preserves source seeded', () {
      final original = Quote(
        id: 'q-rt-003',
        text: 'Seeded quote',
        author: 'Author',
        tags: [],
        source: QuoteSource.seeded,
        createdAt: DateTime.parse('2026-03-27T10:00:00.000Z'),
        updatedAt: null,
      );

      final roundTripped = Quote.fromMap(original.toMap());

      expect(roundTripped.source, equals(QuoteSource.seeded));
    });

    test('round-trip preserves source userCreated', () {
      final original = Quote(
        id: 'q-rt-004',
        text: 'User quote',
        author: 'Me',
        tags: ['personal'],
        source: QuoteSource.userCreated,
        createdAt: DateTime.parse('2026-03-27T10:00:00.000Z'),
        updatedAt: DateTime.parse('2026-03-27T11:00:00.000Z'),
      );

      final roundTripped = Quote.fromMap(original.toMap());

      expect(roundTripped.source, equals(QuoteSource.userCreated));
    });

    test('round-trip preserves createdAt timestamp', () {
      final createdAt = DateTime.parse('2026-03-27T10:30:45.123Z');
      final original = Quote(
        id: 'q-rt-005',
        text: 'Timestamped',
        author: 'Author',
        tags: [],
        source: QuoteSource.seeded,
        createdAt: createdAt,
        updatedAt: null,
      );

      final roundTripped = Quote.fromMap(original.toMap());

      expect(roundTripped.createdAt, equals(createdAt));
    });

    test('round-trip preserves non-null updatedAt', () {
      final updatedAt = DateTime.parse('2026-03-27T15:45:30.000Z');
      final original = Quote(
        id: 'q-rt-006',
        text: 'Edited',
        author: 'Author',
        tags: [],
        source: QuoteSource.userCreated,
        createdAt: DateTime.parse('2026-03-27T10:00:00.000Z'),
        updatedAt: updatedAt,
      );

      final roundTripped = Quote.fromMap(original.toMap());

      expect(roundTripped.updatedAt, equals(updatedAt));
    });

    test('round-trip preserves null updatedAt', () {
      final original = Quote(
        id: 'q-rt-007',
        text: 'Never edited',
        author: 'Author',
        tags: [],
        source: QuoteSource.seeded,
        createdAt: DateTime.parse('2026-03-27T10:00:00.000Z'),
        updatedAt: null,
      );

      final roundTripped = Quote.fromMap(original.toMap());

      expect(roundTripped.updatedAt, isNull);
    });

    test('round-trip preserves all v2 fields together', () {
      final original = Quote(
        id: 'q-rt-008',
        text: 'Complete v2 quote with all fields',
        author: 'Famous Author',
        tags: ['motivational', 'wisdom'],
        source: QuoteSource.userCreated,
        createdAt: DateTime.parse('2026-03-27T10:00:00.000Z'),
        updatedAt: DateTime.parse('2026-03-27T12:00:00.000Z'),
      );

      final roundTripped = Quote.fromMap(original.toMap());

      expect(roundTripped.id, equals(original.id));
      expect(roundTripped.text, equals(original.text));
      expect(roundTripped.author, equals(original.author));
      expect(roundTripped.tags, equals(original.tags));
      expect(roundTripped.source, equals(original.source));
      expect(roundTripped.createdAt, equals(original.createdAt));
      expect(roundTripped.updatedAt, equals(original.updatedAt));
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Group 10: v2 Equality contract — must remain id-based (QG5)
  // ─────────────────────────────────────────────────────────────────────────
  group('Quote v2 equality contract — equality remains id-based', () {
    test('quotes with same id but different tags are equal', () {
      final a = Quote(
        id: 'q-eq-001',
        text: 'Same quote',
        author: 'Author',
        tags: ['motivational'],
        source: QuoteSource.seeded,
        createdAt: DateTime.parse('2026-03-27T10:00:00.000Z'),
        updatedAt: null,
      );
      final b = Quote(
        id: 'q-eq-001',
        text: 'Same quote',
        author: 'Author',
        tags: ['wisdom', 'focus'], // different tags
        source: QuoteSource.seeded,
        createdAt: DateTime.parse('2026-03-27T10:00:00.000Z'),
        updatedAt: null,
      );

      expect(a, equals(b),
          reason: 'equality is id-only; different tags must not affect equality');
    });

    test('quotes with same id but different source are equal', () {
      final a = Quote(
        id: 'q-eq-002',
        text: 'Same quote',
        author: 'Author',
        tags: [],
        source: QuoteSource.seeded,
        createdAt: DateTime.parse('2026-03-27T10:00:00.000Z'),
        updatedAt: null,
      );
      final b = Quote(
        id: 'q-eq-002',
        text: 'Same quote',
        author: 'Author',
        tags: [],
        source: QuoteSource.userCreated, // different source
        createdAt: DateTime.parse('2026-03-27T10:00:00.000Z'),
        updatedAt: null,
      );

      expect(a, equals(b),
          reason: 'equality is id-only; different source must not affect equality');
    });

    test('quotes with same id but different createdAt are equal', () {
      final a = Quote(
        id: 'q-eq-003',
        text: 'Same quote',
        author: 'Author',
        tags: [],
        source: QuoteSource.seeded,
        createdAt: DateTime.parse('2026-03-27T10:00:00.000Z'),
        updatedAt: null,
      );
      final b = Quote(
        id: 'q-eq-003',
        text: 'Same quote',
        author: 'Author',
        tags: [],
        source: QuoteSource.seeded,
        createdAt: DateTime.parse('2026-03-01T00:00:00.000Z'), // different createdAt
        updatedAt: null,
      );

      expect(a, equals(b),
          reason: 'equality is id-only; different createdAt must not affect equality');
    });

    test('quotes with same id but different updatedAt are equal', () {
      final a = Quote(
        id: 'q-eq-004',
        text: 'Same quote',
        author: 'Author',
        tags: [],
        source: QuoteSource.seeded,
        createdAt: DateTime.parse('2026-03-27T10:00:00.000Z'),
        updatedAt: null,
      );
      final b = Quote(
        id: 'q-eq-004',
        text: 'Same quote',
        author: 'Author',
        tags: [],
        source: QuoteSource.seeded,
        createdAt: DateTime.parse('2026-03-27T10:00:00.000Z'),
        updatedAt: DateTime.parse('2026-03-27T12:00:00.000Z'), // different updatedAt
      );

      expect(a, equals(b),
          reason: 'equality is id-only; different updatedAt must not affect equality');
    });

    test('quotes with different ids are not equal regardless of other fields', () {
      final a = Quote(
        id: 'q-eq-005a',
        text: 'Identical content',
        author: 'Same Author',
        tags: ['motivational'],
        source: QuoteSource.seeded,
        createdAt: DateTime.parse('2026-03-27T10:00:00.000Z'),
        updatedAt: null,
      );
      final b = Quote(
        id: 'q-eq-005b', // different id
        text: 'Identical content',
        author: 'Same Author',
        tags: ['motivational'],
        source: QuoteSource.seeded,
        createdAt: DateTime.parse('2026-03-27T10:00:00.000Z'),
        updatedAt: null,
      );

      expect(a, isNot(equals(b)),
          reason: 'different ids means different quotes');
    });

    test('hashCode is consistent with id-based equality', () {
      final a = Quote(
        id: 'q-eq-006',
        text: 'Quote A',
        author: 'Author A',
        tags: ['motivational'],
        source: QuoteSource.seeded,
        createdAt: DateTime.parse('2026-03-27T10:00:00.000Z'),
        updatedAt: null,
      );
      final b = Quote(
        id: 'q-eq-006', // same id
        text: 'Quote B',
        author: 'Author B',
        tags: ['wisdom'],
        source: QuoteSource.userCreated,
        createdAt: DateTime.parse('2026-03-01T00:00:00.000Z'),
        updatedAt: DateTime.parse('2026-03-27T12:00:00.000Z'),
      );

      expect(a.hashCode, equals(b.hashCode),
          reason: 'same id must produce same hashCode');
    });

    test('v2 round-trip quote equals original by id', () {
      final original = Quote(
        id: 'q-eq-007',
        text: 'Round-trip equality test',
        author: 'Author',
        tags: ['focus'],
        source: QuoteSource.userCreated,
        createdAt: DateTime.parse('2026-03-27T10:00:00.000Z'),
        updatedAt: DateTime.parse('2026-03-27T11:00:00.000Z'),
      );

      final roundTripped = Quote.fromMap(original.toMap());

      expect(roundTripped, equals(original));
      expect(roundTripped.hashCode, equals(original.hashCode));
    });
  });
}
