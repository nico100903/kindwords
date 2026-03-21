import 'package:flutter/foundation.dart';
import '../models/quote.dart';
import '../services/quote_service.dart';

/// Provides the current quote state to the widget tree.
///
/// QuoteProvider ensures a non-null [currentQuote] is always available
/// by fetching a random quote in the constructor.
class QuoteProvider extends ChangeNotifier {
  final QuoteService _quoteService;
  late Quote _currentQuote;

  QuoteProvider(this._quoteService) {
    _currentQuote = _quoteService.getRandomQuote();
  }

  /// The currently displayed quote. Never null.
  Quote get currentQuote => _currentQuote;

  /// Refreshes the current quote with a new random one.
  ///
  /// Guarantees no immediate repeat (delegated to QuoteService).
  void refreshQuote() {
    _currentQuote = _quoteService.getRandomQuote(currentId: _currentQuote.id);
    notifyListeners();
  }
}
