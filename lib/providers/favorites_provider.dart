import 'package:flutter/foundation.dart';
import '../models/quote.dart';
import '../services/favorites_service.dart';

/// Provides the favorites list state to the widget tree.
///
/// Initializes with an empty list and loads persisted favorites asynchronously.
/// This ensures no crash on startup while waiting for SharedPreferences.
class FavoritesProvider extends ChangeNotifier {
  final FavoritesService _favoritesService;
  List<Quote> _favorites = [];
  bool _isLoading = false;

  FavoritesProvider(this._favoritesService) {
    _loadFavorites();
  }

  /// The current list of favorite quotes. Empty by default.
  List<Quote> get favorites => List.unmodifiable(_favorites);

  /// True while favorites are being loaded from storage.
  bool get isLoading => _isLoading;

  /// Loads favorites from storage asynchronously.
  Future<void> _loadFavorites() async {
    _isLoading = true;
    notifyListeners();

    try {
      _favorites = await _favoritesService.loadFavorites();
    } catch (e) {
      debugPrint('FavoritesProvider: failed to load favorites: $e');
      _favorites = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Adds [quote] to favorites if not already present.
  Future<void> addFavorite(Quote quote) async {
    if (_favorites.any((q) => q.id == quote.id)) return;
    await _favoritesService.addFavorite(quote);
    _favorites = [..._favorites, quote];
    notifyListeners();
  }

  /// Removes [quote] from favorites.
  Future<void> removeFavorite(Quote quote) async {
    await _favoritesService.removeFavorite(quote);
    _favorites = _favorites.where((q) => q.id != quote.id).toList();
    notifyListeners();
  }

  /// Toggles the favorite status of [quote].
  Future<void> toggleFavorite(Quote quote) async {
    if (_favorites.any((q) => q.id == quote.id)) {
      await removeFavorite(quote);
    } else {
      await addFavorite(quote);
    }
  }

  /// Returns true if [quote] is currently a favorite.
  bool isFavorite(Quote quote) {
    return _favorites.any((q) => q.id == quote.id);
  }
}
