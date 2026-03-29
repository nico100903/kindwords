import 'package:flutter/material.dart';
import 'package:kindwords/widgets/quote_card.dart';
import 'package:provider/provider.dart';
import '../providers/favorites_provider.dart';
import '../providers/quote_provider.dart';

/// Home screen displaying a quote card and primary CTA button.
///
/// Task 01.02: Build the home screen shell with quote card, visible CTA button,
/// and bottom navigation for Home/Favorites/Settings. CTA remains visible without scrolling.
/// Random quote replacement behavior is implemented in task 01.04.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  void _onNavItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });

    switch (index) {
      case 0:
        // Home is already selected, no navigation needed
        break;
      case 1:
        Navigator.pushNamed(context, '/quotes');
        setState(() {
          _selectedIndex = 0; // Reset to Home after navigation
        });
        break;
      case 2:
        Navigator.pushNamed(context, '/favorites');
        setState(() {
          _selectedIndex = 0; // Reset to Home after navigation
        });
        break;
      case 3:
        Navigator.pushNamed(context, '/settings');
        setState(() {
          _selectedIndex = 0; // Reset to Home after navigation
        });
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('KindWords'),
        centerTitle: false,
        elevation: 0,
        actions: [
          Consumer2<QuoteProvider, FavoritesProvider>(
            builder: (context, quoteProvider, favProvider, _) {
              final quote = quoteProvider.currentQuote;
              if (!quoteProvider.isInitialized ||
                  quote == null ||
                  favProvider.isLoading) {
                return const SizedBox.shrink();
              }
              final isFav = favProvider.isFavorite(quote);
              return IconButton(
                icon: Icon(isFav ? Icons.favorite : Icons.favorite_outline),
                onPressed: () =>
                    context.read<FavoritesProvider>().toggleFavorite(quote),
                tooltip: isFav ? 'Remove from favorites' : 'Save to favorites',
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Expanded quote card area
          Expanded(
            child: Consumer<QuoteProvider>(
              builder: (context, quoteProvider, child) {
                if (quoteProvider.isLoading ||
                    quoteProvider.currentQuote == null) {
                  return const Center(child: CircularProgressIndicator());
                }
                final quote = quoteProvider.currentQuote!;
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24.0,
                      vertical: 32.0,
                    ),
                    child: SingleChildScrollView(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        transitionBuilder:
                            (Widget child, Animation<double> animation) {
                          return FadeTransition(
                            opacity: animation,
                            child: child,
                          );
                        },
                        child: QuoteCard(
                          key: ValueKey<String>(quote.id),
                          quote: quote,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          // Primary "Get Motivation" button (behavior implemented in task 01.04)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => context.read<QuoteProvider>().refreshQuote(),
                icon: const Icon(Icons.refresh),
                label: const Text('New Quote'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        onTap: _onNavItemTapped,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.format_quote_outlined),
            activeIcon: Icon(Icons.format_quote),
            label: 'Quotes',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.favorite_outline),
            activeIcon: Icon(Icons.favorite),
            label: 'Favorites',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            activeIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
