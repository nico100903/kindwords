import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/quote_provider.dart';

/// Home screen displaying a quote card, "Save to Favorites" button, and primary CTA.
///
/// Task 01.02: Build the home screen shell with quote card, "Get Motivation" button,
/// and bottom navigation for Home/Favorites/Settings. CTA remains visible without scrolling.
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
        Navigator.pushNamed(context, '/favorites');
        setState(() {
          _selectedIndex = 0; // Reset to Home after navigation
        });
        break;
      case 2:
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
      ),
      body: Column(
        children: [
          // Expanded quote card area
          Expanded(
            child: Consumer<QuoteProvider>(
              builder: (context, quoteProvider, child) {
                final quote = quoteProvider.currentQuote;
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24.0,
                      vertical: 32.0,
                    ),
                    child: SingleChildScrollView(
                      child: Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(32.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                quote.text,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontStyle: FontStyle.italic,
                                  height: 1.4,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              if (quote.author != null) ...[
                                const SizedBox(height: 16),
                                Text(
                                  '— ${quote.author}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          // Save to Favorites button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Consumer<QuoteProvider>(
              builder: (context, quoteProvider, child) {
                return OutlinedButton.icon(
                  onPressed: () {
                    // Placeholder for favorites functionality
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Favorites feature coming soon'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  icon: const Icon(Icons.favorite_outline),
                  label: const Text('Save to Favorites'),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          // Primary "Get Motivation" button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Consumer<QuoteProvider>(
              builder: (context, quoteProvider, child) {
                return SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      quoteProvider.refreshQuote();
                    },
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
                );
              },
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onNavItemTapped,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
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
