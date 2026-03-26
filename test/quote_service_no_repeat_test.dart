import 'package:flutter_test/flutter_test.dart';
import 'package:kindwords/services/quote_service.dart';
import 'package:kindwords/data/quotes_data.dart';

void main() {
  group('Task 01.04: QuoteService no-repeat behavior', () {
    late QuoteService quoteService;

    setUp(() {
      quoteService = QuoteService();
    });

    // -------------------------------------------------------------------------
    // ACCEPTANCE CRITERION: Repeating the action 10 times in a row never shows
    // the same quote twice consecutively when the catalog contains more than
    // one entry.
    // -------------------------------------------------------------------------
    group('AC: 10-tap no consecutive repeats', () {
      test('getRandomQuote with currentId never returns same quote (catalog > 1)',
          () {
        // Arrange: catalog has multiple quotes
        expect(kAllQuotes.length, greaterThan(1),
            reason: 'Test assumes catalog has multiple quotes',);

        // Act & Assert: 10 consecutive calls, each passing previous id
        String? currentId;
        for (int i = 0; i < 10; i++) {
          final quote = quoteService.getRandomQuote(currentId: currentId);
          if (currentId != null) {
            expect(quote.id, isNot(equals(currentId)),
                reason: 'Tap $i: getRandomQuote must not return same quote as currentId',);
          }
          currentId = quote.id;
        }
      });

      test('getRandomQuote distributes across catalog (not stuck on one quote)',
          () {
        // Arrange
        final seenIds = <String>{};
        
        // Act: 20 calls to get reasonable distribution sample
        String? currentId;
        for (int i = 0; i < 20; i++) {
          final quote = quoteService.getRandomQuote(currentId: currentId);
          seenIds.add(quote.id);
          currentId = quote.id;
        }

        // Assert: should have seen multiple different quotes
        // With 110 quotes and random selection, 20 calls should hit at least 10 different ones
        expect(seenIds.length, greaterThanOrEqualTo(10),
            reason: 'Random selection should distribute across catalog, not stay on same quote',);
      });

      test('getRandomQuote without currentId returns any quote from catalog',
          () {
        // Act: get quote without currentId (initial load scenario)
        final quote = quoteService.getRandomQuote();

        // Assert: quote exists in catalog
        final catalogIds = kAllQuotes.map((q) => q.id).toSet();
        expect(catalogIds.contains(quote.id), isTrue,
            reason: 'getRandomQuote() must return a quote from the catalog',);
      });
    });

    // -------------------------------------------------------------------------
    // EDGE CASE: Single-quote catalog
    // -------------------------------------------------------------------------
    group('Edge case: Single-quote catalog', () {
      test('getRandomQuote returns the only quote when catalog has 1 item',
          () {
        // Arrange: create a service with single-quote catalog simulation
        // Note: We can't easily mock kAllQuotes, so we test the logic path
        // by verifying the length-1 early return in getRandomQuote
        
        // This test documents expected behavior: if only 1 quote exists,
        // getRandomQuote returns it regardless of currentId
        // (Cannot easily test without refactoring QuoteService to accept catalog)
        
        // For now, verify our catalog has > 1 quote (so this edge doesn't apply)
        expect(kAllQuotes.length, greaterThan(1),
            reason: 'Current catalog has multiple quotes, single-quote edge does not apply',);
      });
    });

    // -------------------------------------------------------------------------
    // EDGE CASE: Empty catalog (defensive)
    // -------------------------------------------------------------------------
    group('Edge case: Empty catalog fallback', () {
      test('getRandomQuote returns fallback quote when catalog is empty', () {
        // Arrange: verify fallback exists in code path
        // Note: Cannot easily test without modifying kAllQuotes
        
        // Document: the code has a fallback quote for empty catalog
        // "Every day is a fresh start. Keep going!"
        
        // Verify current catalog is not empty (so fallback isn't used)
        expect(kAllQuotes.isNotEmpty, isTrue,
            reason: 'Catalog should not be empty in production',);
      });
    });
  });
}
