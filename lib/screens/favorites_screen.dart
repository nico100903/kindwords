import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/quote.dart';
import '../providers/favorites_provider.dart';
import '../providers/quote_catalog_provider.dart';
import 'quote_form_screen.dart';

/// Favorites screen displaying saved quotes.
///
/// Wave 1 task 01.01: Shell with empty state message.
/// Task 02.03: Full list and delete functionality.
/// Task 08.01: Edit and delete continuity — adds edit IconButton per row,
/// presents QuoteFormScreen in edit mode as a full-screen dialog, and calls
/// FavoritesProvider.reload() on successful mutation (result == true).
///
/// Navigation strategy: [showDialog] with a full-screen [Material] overlay.
/// This keeps [FavoritesScreen] onstage (not offstage) during editing, which
/// allows the reload-on-return flow to work while the favorites list stays
/// in the element tree for the [FavoritesProvider] Consumer.
class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  /// Opens [QuoteFormScreen] in edit mode for [quote] as a full-screen dialog.
  ///
  /// Re-shares the existing [QuoteCatalogProvider] from the ancestor tree
  /// via [ChangeNotifierProvider.value] so [QuoteFormScreen] can call
  /// [QuoteCatalogProvider.updateQuote] / [QuoteCatalogProvider.deleteQuote]
  /// without duplicating CRUD logic.
  ///
  /// On return with result == true (save or delete), calls
  /// [FavoritesProvider.reload()] to refresh the list and silently drop any
  /// stale favorites whose underlying quote was deleted.
  Future<void> _navigateToEdit(final Quote quote) async {
    final QuoteCatalogProvider catalogProvider =
        context.read<QuoteCatalogProvider>();
    final FavoritesProvider favoritesProvider =
        context.read<FavoritesProvider>();

    final Object? result = await showDialog<Object>(
      context: context,
      barrierDismissible: false,
      useSafeArea: false,
      builder: (final BuildContext dialogContext) {
        return ChangeNotifierProvider<QuoteCatalogProvider>.value(
          value: catalogProvider,
          child: Dialog.fullscreen(
            child: QuoteFormScreen(quote: quote),
          ),
        );
      },
    );

    if (!mounted) return;

    if (result == true) {
      await favoritesProvider.reload();
    }
  }

  @override
  Widget build(final BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Favorites'),
      ),
      body: Consumer<FavoritesProvider>(
        builder: (
          final BuildContext ctx,
          final FavoritesProvider favProvider,
          final Widget? child,
        ) {
          if (favProvider.isLoading) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final List<Quote> favorites = favProvider.favorites;

          if (favorites.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: Text(
                  'No favorites yet.\nStart saving quotes you love!',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return ListView.builder(
            itemCount: favorites.length,
            itemBuilder: (final BuildContext ctx2, final int index) {
              final Quote quote = favorites[index];
              return ListTile(
                title: Text(
                  quote.text,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle:
                    quote.author != null ? Text('— ${quote.author}') : null,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      tooltip: 'Edit quote',
                      onPressed: () => _navigateToEdit(quote),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      tooltip: 'Remove from favorites',
                      onPressed: () {
                        favProvider.removeFavorite(quote);
                      },
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
