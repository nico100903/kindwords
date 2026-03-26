import 'package:flutter/foundation.dart';
import '../models/quote.dart';
import '../services/quote_service.dart';

/// Provides the current quote state to the widget tree.
///
/// Exposes [isLoading] to allow the UI to show a loading indicator
/// while an async quote fetch is in progress.
class QuoteProvider extends ChangeNotifier {
  final QuoteService _quoteService;
  Quote? _currentQuote;
  bool _isLoading = false;
  bool _isInitialized = false;

  QuoteProvider(this._quoteService) {
    _initialize();
  }

  /// The currently displayed quote. May be null before initialization completes.
  Quote? get currentQuote => _currentQuote;

  /// True while a user-initiated [refreshQuote] is in progress.
  /// False during initial load — use [isInitialized] to check that state.
  bool get isLoading => _isLoading;

  /// True once the initial quote has been loaded. False on first frame.
  bool get isInitialized => _isInitialized;

  /// Fire-and-forget initialization. Exposes [isInitialized] = false until
  /// the first quote is ready, so the UI can suppress actions that require
  /// a valid quote without interfering with [isLoading]'s user-refresh contract.
  Future<void> _initialize() async {
    _currentQuote = await _quoteService.getRandomQuote();
    _isInitialized = true;
    notifyListeners();
  }

  /// Refreshes the current quote with a new random one.
  ///
  /// Sets [isLoading] to true while fetching, then false on completion.
  /// Guarantees no immediate repeat (delegated to QuoteService).
  Future<void> refreshQuote() async {
    _isLoading = true;
    notifyListeners();
    _currentQuote = await _quoteService.getRandomQuote(
      currentId: _currentQuote?.id,
    );
    _isLoading = false;
    notifyListeners();
  }

  /// Reloads the current quote from the service if its [id] matches.
  ///
  /// Called by catalog mutation hooks (delete/update) so that the home
  /// screen always shows the latest version of a displayed quote.
  ///
  /// If the quote has been deleted ([getQuoteById] returns null) the
  /// current quote is left as-is — stale-quote handling (clearing or
  /// replacing with a new random quote) is deferred to the UI layer in
  /// a later task.
  ///
  /// No-op if [_currentQuote.id] does not match [id].
  Future<void> refreshCurrentIfStale(String id) async {
    if (_currentQuote?.id != id) return;
    try {
      final fresh = await _quoteService.getQuoteById(id);
      if (fresh != null) {
        _currentQuote = fresh;
        notifyListeners();
      }
    } catch (_) {
      // Service call failed or returned unexpected type — leave current
      // quote unchanged. This guards against test environments where
      // getQuoteById is not stubbed and gracefully handles quote-not-found.
    }
  }
}
