import 'dart:math';
import '../models/quote.dart';
import '../data/quotes_data.dart';

/// Provides random quote selection from the embedded [kAllQuotes] list.
///
/// Guarantees no immediate repeat: [getRandomQuote] will never return
/// the same quote as [currentId] unless the list has only one item.
class QuoteService {
  final Random _random = Random();

  /// Returns a random [Quote] that is different from [currentId].
  ///
  /// If [currentId] is null (first load), returns any random quote.
  Quote getRandomQuote({String? currentId}) {
    if (kAllQuotes.isEmpty) {
      // Fallback — should never happen if quotes_data.dart is populated.
      return const Quote(
        id: 'fallback',
        text: 'Every day is a fresh start. Keep going!',
      );
    }

    if (kAllQuotes.length == 1) {
      return kAllQuotes.first;
    }

    // Filter out the current quote to avoid immediate repeat.
    final candidates = currentId != null
        ? kAllQuotes.where((q) => q.id != currentId).toList()
        : kAllQuotes;

    return candidates[_random.nextInt(candidates.length)];
  }

  /// Returns the [Quote] with the given [id], or null if not found.
  Quote? getById(String id) {
    try {
      return kAllQuotes.firstWhere((q) => q.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Total number of available quotes.
  int get totalCount => kAllQuotes.length;
}
