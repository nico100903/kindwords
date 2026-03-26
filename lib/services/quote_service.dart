import 'dart:math';
import '../models/quote.dart';
import '../repositories/quote_repository.dart';

/// Provides random quote selection from the repository.
///
/// Guarantees no immediate repeat: [getRandomQuote] will never return
/// the same quote as [currentId] unless the list has only one item.
///
/// Implements [QuoteRepositoryBase] so it can be passed wherever a repository
/// is expected (e.g. in widget tests that wire [FavoritesService] directly).
class QuoteService implements QuoteRepositoryBase {
  final QuoteRepositoryBase _repository;
  final Random _random = Random();

  QuoteService(this._repository);

  /// Returns a random [Quote] that is different from [currentId].
  ///
  /// If [currentId] is null (first load), returns any random quote.
  Future<Quote> getRandomQuote({String? currentId}) async {
    final all = await _repository.getAllQuotes();

    if (all.isEmpty) {
      return const Quote(
        id: 'fallback',
        text: 'Every day is a fresh start. Keep going!',
      );
    }

    if (all.length == 1) return all.first;

    // Filter out the current quote to avoid immediate repeat.
    final candidates =
        currentId != null ? all.where((q) => q.id != currentId).toList() : all;

    return candidates[_random.nextInt(candidates.length)];
  }

  /// Returns all quotes from the repository.
  @override
  Future<List<Quote>> getAllQuotes() => _repository.getAllQuotes();

  /// Returns the [Quote] with the given [id], or null if not found.
  @override
  Future<Quote?> getById(String id) => _repository.getById(id);

  /// Total number of available quotes.
  Future<int> get totalCount async {
    final all = await _repository.getAllQuotes();
    return all.length;
  }
}
