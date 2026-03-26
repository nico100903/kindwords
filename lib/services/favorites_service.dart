import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/quote.dart';
import '../repositories/quote_repository.dart';

/// Persists favorite quote IDs using [SharedPreferences].
///
/// Stores a JSON-encoded list of quote ID strings under [_favoritesKey].
/// Favorites survive app restarts and device reboots.
class FavoritesService {
  static const String _favoritesKey = 'favorite_quote_ids';

  final QuoteRepositoryBase _repository;

  FavoritesService(this._repository);

  /// Loads all saved favorite [Quote] objects from storage.
  ///
  /// IDs that no longer exist in the repository are silently skipped.
  Future<List<Quote>> loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_favoritesKey);
    if (raw == null) return [];

    final ids = List<String>.from(jsonDecode(raw) as List);
    final results = <Quote>[];
    for (final id in ids) {
      final quote = await _repository.getById(id);
      if (quote != null) {
        results.add(quote);
      }
    }
    return results;
  }

  /// Saves [quote] to favorites. Does nothing if already saved.
  Future<void> addFavorite(Quote quote) async {
    final prefs = await SharedPreferences.getInstance();
    final ids = await _loadIds(prefs);
    if (ids.contains(quote.id)) return; // prevent duplicates
    ids.add(quote.id);
    await prefs.setString(_favoritesKey, jsonEncode(ids));
  }

  /// Removes [quote] from favorites. Does nothing if not saved.
  Future<void> removeFavorite(Quote quote) async {
    final prefs = await SharedPreferences.getInstance();
    final ids = await _loadIds(prefs);
    ids.remove(quote.id);
    await prefs.setString(_favoritesKey, jsonEncode(ids));
  }

  /// Returns true if [quote] is currently saved as a favorite.
  Future<bool> isFavorite(Quote quote) async {
    final prefs = await SharedPreferences.getInstance();
    final ids = await _loadIds(prefs);
    return ids.contains(quote.id);
  }

  Future<List<String>> _loadIds(SharedPreferences prefs) async {
    final raw = prefs.getString(_favoritesKey);
    if (raw == null) return [];
    return List<String>.from(jsonDecode(raw) as List);
  }
}
