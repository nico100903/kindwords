import '../data/quote_database.dart';
import '../models/quote.dart';

/// Abstract interface for quote persistence.
///
/// Services depend on [QuoteRepositoryBase] — not on the concrete
/// [LocalQuoteRepository] — so the implementation can be swapped
/// (e.g. for a future remote source) without touching service code.
///
/// The CRUD and filter methods added in Sprint 2 have default implementations
/// that throw [UnimplementedError]. Existing Sprint-1 in-memory test fakes
/// that implement this interface do not need updating — they will simply not
/// use those methods. Concrete production implementations ([LocalQuoteRepository])
/// override all methods.
abstract class QuoteRepositoryBase {
  Future<List<Quote>> getAllQuotes();
  Future<Quote?> getById(String id);

  // ── CRUD mutations ──────────────────────────────────────────────────────────

  /// Inserts [quote] into the local store.
  Future<void> insertQuote(Quote quote) =>
      throw UnimplementedError('insertQuote not implemented');

  /// Updates the stored record for [quote.id] with the new field values.
  Future<void> updateQuote(Quote quote) =>
      throw UnimplementedError('updateQuote not implemented');

  /// Permanently removes the quote identified by [id] from the local store.
  Future<void> deleteQuote(String id) =>
      throw UnimplementedError('deleteQuote not implemented');

  // ── Filtered reads ──────────────────────────────────────────────────────────

  /// Returns all quotes with the given [source].
  Future<List<Quote>> getBySource(QuoteSource source) =>
      throw UnimplementedError('getBySource not implemented');

  /// Returns all quotes whose tags list contains [tag].
  Future<List<Quote>> getByTag(String tag) =>
      throw UnimplementedError('getByTag not implemented');
}

/// SQLite-backed implementation of [QuoteRepositoryBase].
///
/// All persistence is delegated to [QuoteDatabase]; this class adds
/// no caching, transformation, or business logic.
class LocalQuoteRepository implements QuoteRepositoryBase {
  final QuoteDatabase _db;

  LocalQuoteRepository(this._db);

  @override
  Future<List<Quote>> getAllQuotes() => _db.getAllQuotes();

  @override
  Future<Quote?> getById(String id) => _db.getById(id);

  @override
  Future<void> insertQuote(Quote quote) => _db.insertQuote(quote);

  @override
  Future<void> updateQuote(Quote quote) => _db.updateQuote(quote);

  @override
  Future<void> deleteQuote(String id) => _db.deleteQuote(id);

  @override
  Future<List<Quote>> getBySource(QuoteSource source) =>
      _db.getBySource(source);

  @override
  Future<List<Quote>> getByTag(String tag) => _db.getByTag(tag);
}
