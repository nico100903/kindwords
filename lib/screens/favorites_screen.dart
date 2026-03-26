import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/favorites_provider.dart';

/// Favorites screen shell displaying saved quotes.
///
/// Wave 1 task 01.01: Shell with empty state message.
/// Full list and delete functionality deferred to task 02.01.
class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Favorites'),
      ),
      body: Consumer<FavoritesProvider>(
        builder: (context, favProvider, child) {
          if (favProvider.isLoading) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final favorites = favProvider.favorites;

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
            itemBuilder: (context, index) {
              final quote = favorites[index];
              return ListTile(
                title: Text(
                  quote.text,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle:
                    quote.author != null ? Text('— ${quote.author}') : null,
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () {
                    favProvider.removeFavorite(quote);
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
