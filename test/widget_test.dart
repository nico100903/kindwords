import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:kindwords/main.dart';
import 'package:kindwords/providers/quote_provider.dart';
import 'package:kindwords/providers/favorites_provider.dart';
import 'package:kindwords/services/quote_service.dart';
import 'package:kindwords/services/favorites_service.dart';

/// Creates a testable widget tree with providers.
Widget _createTestApp() {
  final quoteService = QuoteService();
  final favoritesService = FavoritesService(quoteService);

  return MultiProvider(
    providers: [
      ChangeNotifierProvider(
        create: (_) => QuoteProvider(quoteService),
      ),
      ChangeNotifierProvider(
        create: (_) => FavoritesProvider(favoritesService),
      ),
    ],
    child: const KindWordsApp(),
  );
}

void main() {
  testWidgets('App launches with KindWords title', (WidgetTester tester) async {
    await tester.pumpWidget(_createTestApp());

    // Verify that the app bar shows 'KindWords'
    expect(find.text('KindWords'), findsOneWidget);
  });

  testWidgets('Home screen has navigation icons', (WidgetTester tester) async {
    await tester.pumpWidget(_createTestApp());

    // Verify favorites navigation icon is present
    expect(find.byIcon(Icons.favorite_outline), findsOneWidget);
    // Verify settings navigation icon is present
    expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
  });

  testWidgets('Home screen displays a quote', (WidgetTester tester) async {
    await tester.pumpWidget(_createTestApp());

    // Verify a quote card is displayed (QuoteProvider ensures non-null quote)
    expect(find.byType(Card), findsOneWidget);
  });
}
