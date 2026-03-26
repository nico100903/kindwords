import 'package:flutter/foundation.dart';

import '../models/quote.dart';
import '../repositories/quote_repository.dart';

/// Provides the full local quote catalog with reactive filter state.
///
/// Holds the canonical in-memory list [_allQuotes] loaded from the
/// repository. Exposes a computed [quotes] getter that applies the active
/// [sourceFilter] and [tagFilter] on every access — no cached mutable list.
///
/// Mutation methods ([createQuote], [updateQuote], [deleteQuote]) persist
/// changes via the repository then update [_allQuotes] in-memory and call
/// [notifyListeners] so the UI reflects the change immediately.
///
/// **Layer boundary:** this class must only depend on [QuoteRepositoryBase].
/// It must NOT import [QuoteDatabase] directly — that would violate the
/// clean-architecture boundary established in Sprint 1.
class QuoteCatalogProvider extends ChangeNotifier {
  final QuoteRepositoryBase _repo;

  List<Quote> _allQuotes = [];
  bool _isLoading = false;

  /// Active source filter. Null means "show all sources".
  QuoteSource? _sourceFilter;

  /// Active tag filter. Null means "no tag filter".
  String? _tagFilter;

  QuoteCatalogProvider(this._repo);

  // ── Public getters ─────────────────────────────────────────────────────────

  /// True while [load()] is in progress.
  bool get isLoading => _isLoading;

  /// The active source filter. Null = All.
  QuoteSource? get sourceFilter => _sourceFilter;

  /// The active tag filter. Null = no filter.
  String? get tagFilter => _tagFilter;

  /// The filtered list of quotes.
  ///
  /// Recomputed on every access from [_allQuotes] using the active
  /// [sourceFilter] and [tagFilter]. This ensures that mutations to
  /// [_allQuotes] are always reflected without an additional step.
  List<Quote> get quotes {
    Iterable<Quote> result = _allQuotes;

    if (_sourceFilter != null) {
      result = result.where((q) => q.source == _sourceFilter);
    }

    if (_tagFilter != null) {
      result = result.where((q) => q.tags.contains(_tagFilter));
    }

    return result.toList();
  }

  // ── Load ───────────────────────────────────────────────────────────────────

  /// Loads all quotes from the repository into [_allQuotes].
  ///
  /// Sets [isLoading] to true before the repository call and false after.
  /// Calls [notifyListeners()] at both state transitions.
  Future<void> load() async {
    _isLoading = true;
    notifyListeners();

    _allQuotes = await _repo.getAllQuotes();

    _isLoading = false;
    notifyListeners();
  }

  // ── Filters ────────────────────────────────────────────────────────────────

  /// Sets the source filter and notifies listeners.
  ///
  /// Pass [null] to clear the filter (show all sources).
  void setSourceFilter(QuoteSource? source) {
    _sourceFilter = source;
    notifyListeners();
  }

  /// Sets the tag filter and notifies listeners.
  ///
  /// Pass [null] to clear the filter (show all tags).
  void setTagFilter(String? tag) {
    _tagFilter = tag;
    notifyListeners();
  }

  // ── CRUD mutations ─────────────────────────────────────────────────────────

  /// Inserts [quote] via the repository, appends it to [_allQuotes],
  /// and notifies listeners.
  ///
  /// The computed [quotes] getter will include the new quote immediately
  /// if it passes the active filters.
  Future<void> createQuote(Quote quote) async {
    await _repo.insertQuote(quote);
    _allQuotes = [..._allQuotes, quote];
    notifyListeners();
  }

  /// Updates [quote] via the repository, replaces its entry in [_allQuotes]
  /// by id, and notifies listeners.
  ///
  /// The computed [quotes] getter will reflect the updated fields immediately,
  /// including any change to tags or source that affects active filters.
  Future<void> updateQuote(Quote quote) async {
    await _repo.updateQuote(quote);
    _allQuotes = _allQuotes.map((q) => q.id == quote.id ? quote : q).toList();
    notifyListeners();
  }

  /// Deletes the quote identified by [id] via the repository, removes it
  /// from [_allQuotes], and notifies listeners.
  ///
  /// The deleted quote will not appear in subsequent [quotes] accesses.
  Future<void> deleteQuote(String id) async {
    await _repo.deleteQuote(id);
    _allQuotes = _allQuotes.where((q) => q.id != id).toList();
    notifyListeners();
  }
}
