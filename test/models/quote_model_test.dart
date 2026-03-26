// Wave R2 — Contract tests for Quote.toMap() and Quote.fromMap()
//
// These tests FAIL until the coder adds toMap() and fromMap() to Quote.
// They define the sqflite serialization contract for the DB schema:
//
//   CREATE TABLE quotes (id TEXT PRIMARY KEY, text TEXT NOT NULL, author TEXT)
//
// Do NOT add toMap/fromMap to quote.dart — that is the coder's job.

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
}
