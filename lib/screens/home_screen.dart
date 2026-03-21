import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/quote_provider.dart';
import '../providers/favorites_provider.dart';

/// Home screen shell displaying the current quote and navigation.
///
/// Wave 1 task 01.01: Basic shell with placeholder quote, navigation icons.
/// Polish and animations deferred to task 01.02.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('KindWords'),
        actions: [
          IconButton(
            icon: const Icon(Icons.favorite_outline),
            tooltip: 'Favorites',
            onPressed: () {
              Navigator.pushNamed(context, '/favorites');
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () {
              Navigator.pushNamed(context, '/settings');
            },
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Consumer<QuoteProvider>(
            builder: (context, quoteProvider, child) {
              final quote = quoteProvider.currentQuote;
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Quote card placeholder
                  Card(
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        children: [
                          Text(
                            quote.text,
                            style: const TextStyle(
                              fontSize: 18,
                              fontStyle: FontStyle.italic,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          if (quote.author != null) ...[
                            const SizedBox(height: 12),
                            Text(
                              '— ${quote.author}',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Favorite toggle button
                  Consumer<FavoritesProvider>(
                    builder: (context, favProvider, child) {
                      final isFav = favProvider.isFavorite(quote);
                      return IconButton(
                        icon: Icon(
                          isFav ? Icons.favorite : Icons.favorite_outline,
                          color: isFav ? Colors.red : null,
                        ),
                        onPressed: () {
                          favProvider.toggleFavorite(quote);
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  // Get Motivation button
                  ElevatedButton.icon(
                    onPressed: () {
                      quoteProvider.refreshQuote();
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Get Motivation'),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
