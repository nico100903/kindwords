import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/quote.dart';

/// SQLite data-access layer for KindWords quotes.
///
/// Responsibilities:
/// - Open / create the `kindwords.db` database.
/// - Seed the `quotes` table from a provided list if it is empty.
/// - Read all quotes or look up a single quote by stable ID.
///
/// This class is the only place in the codebase that imports `sqflite`
/// directly. All higher layers (repository, service, providers) go through
/// [LocalQuoteRepository] which depends on this class.
///
/// ## Schema versioning
///
/// v1 — columns: `id`, `text`, `author`
/// v2 — added: `tags`, `source`, `created_at`, `updated_at`
class QuoteDatabase {
  Database? _db;

  /// Opens (or creates) the SQLite database file on the device.
  ///
  /// Creates the full v2 `quotes` schema on fresh installs via [onCreate].
  /// Migrates existing v1 databases to v2 via [onUpgrade].
  Future<void> open() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'kindwords.db');
    _db = await openDatabase(
      path,
      version: 2,
      onCreate: (db, version) async {
        // Full v2 schema for fresh installs
        await db.execute('''
          CREATE TABLE quotes (
            id TEXT PRIMARY KEY,
            text TEXT NOT NULL,
            author TEXT,
            tags TEXT NOT NULL DEFAULT '[]',
            source TEXT NOT NULL DEFAULT 'seeded',
            created_at TEXT NOT NULL DEFAULT '',
            updated_at TEXT
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          // Non-destructive migration: add the four new v2 columns to existing
          // tables. Existing rows survive; defaults fill in new values.
          // The empty-string default for created_at is intentional — fromMap()
          // treats '' the same as null and substitutes the migration fallback.
          await db.execute(
            "ALTER TABLE quotes ADD COLUMN tags TEXT NOT NULL DEFAULT '[]'",
          );
          await db.execute(
            "ALTER TABLE quotes ADD COLUMN source TEXT NOT NULL DEFAULT 'seeded'",
          );
          await db.execute(
            "ALTER TABLE quotes ADD COLUMN created_at TEXT NOT NULL DEFAULT ''",
          );
          await db.execute(
            'ALTER TABLE quotes ADD COLUMN updated_at TEXT',
          );
        }
      },
    );
  }

  /// Seeds the `quotes` table from [quotes] if it is currently empty.
  ///
  /// Idempotent: if any rows exist the entire list is skipped.
  /// Uses a batch with [ConflictAlgorithm.ignore] — safe to call again
  /// without duplicating rows even if the count-check were somehow bypassed.
  Future<void> seedIfEmpty(List<Quote> quotes) async {
    final count = Sqflite.firstIntValue(
          await _db!.rawQuery('SELECT COUNT(*) FROM quotes'),
        ) ??
        0;
    if (count > 0) return;

    final batch = _db!.batch();
    for (final q in quotes) {
      batch.insert(
        'quotes',
        q.toMap(),
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
    await batch.commit(noResult: true);
  }

  /// Returns every row in the `quotes` table as a [List<Quote>].
  Future<List<Quote>> getAllQuotes() async {
    final rows = await _db!.query('quotes');
    return rows.map(Quote.fromMap).toList();
  }

  /// Returns the [Quote] whose `id` matches [id], or `null` if not found.
  Future<Quote?> getById(String id) async {
    final rows = await _db!.query(
      'quotes',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (rows.isEmpty) return null;
    return Quote.fromMap(rows.first);
  }
}
