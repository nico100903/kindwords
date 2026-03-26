import '../data/quote_database.dart';
import '../models/quote.dart';

/// Abstract interface for quote persistence.
///
/// Services depend on [QuoteRepositoryBase] — not on the concrete
/// [LocalQuoteRepository] — so the implementation can be swapped
/// (e.g. for a future remote source) without touching service code.
abstract class QuoteRepositoryBase {
  Future<List<Quote>> getAllQuotes();
  Future<Quote?> getById(String id);
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
}
