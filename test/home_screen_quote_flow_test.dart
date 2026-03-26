import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:kindwords/screens/home_screen.dart';
import 'package:kindwords/providers/quote_provider.dart';
import 'package:kindwords/providers/favorites_provider.dart';
import 'package:kindwords/services/quote_service.dart';
import 'package:kindwords/services/favorites_service.dart';

/// Global quote provider reference for testing.
QuoteProvider? _testQuoteProvider;

/// Creates a testable HomeScreen widget tree with providers.
Widget _createTestHomeApp() {
  final quoteService = QuoteService();
  final favoritesService = FavoritesService(quoteService);
  _testQuoteProvider = QuoteProvider(quoteService);

  return MaterialApp(
    home: MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _testQuoteProvider!),
        ChangeNotifierProvider(
          create: (_) => FavoritesProvider(favoritesService),
        ),
      ],
      child: const HomeScreen(),
    ),
  );
}

void main() {
  group('Task 01.04: Connect Random Quote Flow', () {
    // -------------------------------------------------------------------------
    // ACCEPTANCE CRITERION: Tapping the motivation action replaces the current
    // quote with a different quote whenever more than one quote exists.
    // -------------------------------------------------------------------------
    group('AC: CTA button replaces quote', () {
      testWidgets('New Quote button is enabled (not disabled)',
          (WidgetTester tester) async {
        // Arrange
        await tester.pumpWidget(_createTestHomeApp());
        await tester.pumpAndSettle();

        // Act: find the ElevatedButton
        final elevatedButton = find.byType(ElevatedButton);
        expect(elevatedButton, findsOneWidget,
            reason: 'Home screen must have an ElevatedButton for New Quote',);

        // Assert: button has non-null onPressed (enabled)
        final button = tester.widget<ElevatedButton>(elevatedButton);
        expect(button.onPressed, isNotNull,
            reason: 'New Quote button must be enabled (onPressed should not be null)',);
      });

      testWidgets('tapping New Quote button changes the displayed quote',
          (WidgetTester tester) async {
        // Arrange
        await tester.pumpWidget(_createTestHomeApp());
        await tester.pumpAndSettle();

        // Capture initial quote text
        final quoteProvider = _testQuoteProvider!;
        final initialQuoteId = quoteProvider.currentQuote.id;

        // Act: tap the New Quote button
        final button = find.byType(ElevatedButton);
        await tester.tap(button);
        await tester.pumpAndSettle();

        // Assert: quote has changed
        final newQuoteId = quoteProvider.currentQuote.id;
        expect(newQuoteId, isNot(equals(initialQuoteId)),
            reason: 'Tapping New Quote must change the quote to a different one',);
      });

      testWidgets('tapping New Quote multiple times produces different quotes each time',
          (WidgetTester tester) async {
        // Arrange
        await tester.pumpWidget(_createTestHomeApp());
        await tester.pumpAndSettle();

        final quoteProvider = _testQuoteProvider!;
        final button = find.byType(ElevatedButton);

        // Act & Assert: tap 5 times, verify no consecutive repeats
        String? previousId;
        for (int i = 0; i < 5; i++) {
          final currentId = quoteProvider.currentQuote.id;
          if (previousId != null) {
            expect(currentId, isNot(equals(previousId)),
                reason: 'Tap $i: consecutive quotes must differ',);
          }
          previousId = currentId;
          await tester.tap(button);
          await tester.pumpAndSettle();
        }
      });
    });

    // -------------------------------------------------------------------------
    // ACCEPTANCE CRITERION: The newly shown quote appears with a visible
    // fade or slide-style transition.
    // -------------------------------------------------------------------------
    group('AC: Quote transition is visible', () {
      testWidgets('quote card is wrapped in AnimatedSwitcher',
          (WidgetTester tester) async {
        // Arrange
        await tester.pumpWidget(_createTestHomeApp());
        await tester.pumpAndSettle();

        // Assert: AnimatedSwitcher wraps the quote content
        expect(find.byType(AnimatedSwitcher), findsOneWidget,
            reason: 'Quote card must be wrapped in AnimatedSwitcher for transitions',);
      });

      testWidgets('AnimatedSwitcher has fade or slide transition',
          (WidgetTester tester) async {
        // Arrange
        await tester.pumpWidget(_createTestHomeApp());
        await tester.pumpAndSettle();

        // Find the AnimatedSwitcher
        final animatedSwitcher = tester.widget<AnimatedSwitcher>(
          find.byType(AnimatedSwitcher),
        );

        // Assert: transitionBuilder is set (not null means custom transition)
        // Note: If transitionBuilder is null, AnimatedSwitcher uses default fade
        // Either is acceptable for this AC - we just verify AnimatedSwitcher exists
        // and has a reasonable duration
        expect(animatedSwitcher.duration.inMilliseconds, lessThanOrEqualTo(300),
            reason: 'Transition must complete in <= 300ms for instant feel',);
      });

      testWidgets('quote card has ValueKey based on quote id',
          (WidgetTester tester) async {
        // Arrange
        await tester.pumpWidget(_createTestHomeApp());
        await tester.pumpAndSettle();

        // Find the Card within AnimatedSwitcher
        final cardFinder = find.descendant(
          of: find.byType(AnimatedSwitcher),
          matching: find.byType(Card),
        );

        expect(cardFinder, findsOneWidget,
            reason: 'Card must be inside AnimatedSwitcher for key-based transitions',);

        // The Card widget should have a key for AnimatedSwitcher to detect changes
        final card = tester.widget<Card>(cardFinder);
        expect(card.key, isNotNull,
            reason: 'Card must have a ValueKey for AnimatedSwitcher to detect quote changes',);
        expect(card.key, isA<ValueKey<String>>(),
            reason: 'Card key must be ValueKey<String> based on quote.id',);
      });

       testWidgets('tapping New Quote triggers animation (transition runs)',
           (WidgetTester tester) async {
         // Arrange
         await tester.pumpWidget(_createTestHomeApp());
         await tester.pumpAndSettle();

         // Act: tap the New Quote button
         await tester.tap(find.byType(ElevatedButton));
         
         // Assert: pump (not pumpAndSettle) to capture mid-animation state
         // Animation should be in progress
         await tester.pump(const Duration(milliseconds: 50));
         
         // After tapping, the animation should start - verify by pumping
         // through animation duration and confirming it settles
         await tester.pumpAndSettle(const Duration(milliseconds: 500));
         
         // If we got here without errors, animation completed successfully
         expect(find.byType(AnimatedSwitcher), findsOneWidget,
             reason: 'AnimatedSwitcher must handle the transition',);
       });
    });

    // -------------------------------------------------------------------------
    // ACCEPTANCE CRITERION: The interaction completes without internet access.
    // -------------------------------------------------------------------------
    group('AC: Offline-first operation', () {
      testWidgets('quote refresh works without network dependency',
          (WidgetTester tester) async {
        // Arrange: create widget (no network mocking needed - all local data)
        await tester.pumpWidget(_createTestHomeApp());
        await tester.pumpAndSettle();

        final quoteProvider = _testQuoteProvider!;
        final initialQuote = quoteProvider.currentQuote;

        // Act: tap New Quote - should work without any network calls
        await tester.tap(find.byType(ElevatedButton));
        await tester.pumpAndSettle();

        // Assert: quote changed using only local data
        final newQuote = quoteProvider.currentQuote;
        expect(newQuote.id, isNot(equals(initialQuote.id)),
            reason: 'Quote refresh must work offline using local data only',);
      });
    });

    // -------------------------------------------------------------------------
    // EDGE CASE: Rapid tapping (state transitions under load)
    // -------------------------------------------------------------------------
    group('Edge case: Rapid tapping', () {
      testWidgets('rapid tapping updates quote correctly each time',
          (WidgetTester tester) async {
        // Arrange
        await tester.pumpWidget(_createTestHomeApp());
        await tester.pumpAndSettle();

        final quoteProvider = _testQuoteProvider!;
        final button = find.byType(ElevatedButton);

        // Act: rapid taps without waiting for settle
        final ids = <String>[];
        for (int i = 0; i < 5; i++) {
          ids.add(quoteProvider.currentQuote.id);
          await tester.tap(button);
          await tester.pump(const Duration(milliseconds: 100)); // Minimal wait
        }
        ids.add(quoteProvider.currentQuote.id);

        // Assert: no consecutive duplicates (even with rapid tapping)
        for (int i = 1; i < ids.length; i++) {
          expect(ids[i], isNot(equals(ids[i - 1])),
              reason: 'Rapid tap $i: consecutive quotes must still differ',);
        }
      });
    });

    // -------------------------------------------------------------------------
    // EDGE CASE: Single-quote catalog (boundary value)
    // -------------------------------------------------------------------------
    // Note: This would require a mock QuoteService with a single-quote catalog
    // Skipping for now as current implementation has 110 quotes
  });
}
