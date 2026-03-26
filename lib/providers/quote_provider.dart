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
}
