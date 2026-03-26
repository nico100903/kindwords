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
class QuoteDatabase {
  Database? _db;

  /// Opens (or creates) the SQLite database file on the device.
  ///
  /// Creates the `quotes` schema on first run via [onCreate].
  Future<void> open() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'kindwords.db');
    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE quotes (
            id TEXT PRIMARY KEY,
            text TEXT NOT NULL,
            author TEXT
          )
        ''');
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
