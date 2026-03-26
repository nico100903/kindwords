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

  QuoteProvider(this._quoteService) {
    _initialize();
  }

  /// The currently displayed quote. May be null before initialization completes.
  Quote? get currentQuote => _currentQuote;

  /// True while an async quote fetch is in progress.
  bool get isLoading => _isLoading;

  /// Fire-and-forget initialization — does NOT set isLoading=true synchronously.
  Future<void> _initialize() async {
    _currentQuote = await _quoteService.getRandomQuote();
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
