import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kindwords/models/quote.dart';
import 'package:kindwords/widgets/quote_card.dart';

void main() {
  // ---------------------------------------------------------------------------
  // QuoteCard widget contract tests (Wave R6)
  //
  // These tests are FAILING by design — QuoteCard does not exist yet.
  // The coder must implement lib/widgets/quote_card.dart to make them green.
  //
  // Contract:
  //   class QuoteCard extends StatelessWidget {
  //     final Quote quote;
  //     const QuoteCard({super.key, required this.quote});
  //   }
  //
  // The widget must:
  //   1. Display quote.text
  //   2. Display '— ${quote.author}' when author is non-null
  //   3. Display nothing dash-related when author is null
  //   4. Be wrapped in a Card widget
  //   5. Support a const constructor
  // ---------------------------------------------------------------------------

  group('QuoteCard', () {
    // -------------------------------------------------------------------------
    // Test 1 — shows quote text
    // -------------------------------------------------------------------------
    testWidgets('shows quote text', (WidgetTester tester) async {
      const quote = Quote(id: 'q001', text: 'Test quote', author: null);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: QuoteCard(quote: quote),
          ),
        ),
      );

      expect(find.text('Test quote'), findsOneWidget);
    });

    // -------------------------------------------------------------------------
    // Test 2 — shows author formatted with em-dash when author is present
    // -------------------------------------------------------------------------
    testWidgets('shows formatted author when author is present',
        (WidgetTester tester) async {
      const quote = Quote(
        id: 'q002',
        text: 'The obstacle is the way.',
        author: 'Marcus Aurelius',
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: QuoteCard(quote: quote),
          ),
        ),
      );

      expect(find.text('— Marcus Aurelius'), findsOneWidget);
    });

    // -------------------------------------------------------------------------
    // Test 3 — hides author line entirely when author is null
    // -------------------------------------------------------------------------
    testWidgets('hides author when author is null',
        (WidgetTester tester) async {
      const quote = Quote(id: 'q003', text: 'Anonymous quote', author: null);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: QuoteCard(quote: quote),
          ),
        ),
      );

      // No standalone dash text
      expect(find.text('—'), findsNothing);
      // No text containing a dash at all (rules out '— null', '— ', etc.)
      expect(find.textContaining('—'), findsNothing);
    });

    // -------------------------------------------------------------------------
    // Test 4 — is wrapped in a Card widget
    // -------------------------------------------------------------------------
    testWidgets('is wrapped in a Card widget', (WidgetTester tester) async {
      const quote = Quote(id: 'q004', text: 'Another quote', author: null);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: QuoteCard(quote: quote),
          ),
        ),
      );

      expect(find.byType(Card), findsOneWidget);
    });

    // -------------------------------------------------------------------------
    // Test 5 — const constructor: the `const` keyword must compile
    //
    // If QuoteCard lacks a const constructor this file will not compile,
    // producing the expected red state. Using const here is intentional —
    // it is the compile-time proof, not just a style preference.
    // -------------------------------------------------------------------------
    testWidgets('supports const constructor', (WidgetTester tester) async {
      // const usage at the call site — fails compilation without a const ctor
      const card = QuoteCard(
        quote: Quote(id: 'q005', text: 'Const quote', author: 'Epictetus'),
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: card),
        ),
      );

      expect(find.text('Const quote'), findsOneWidget);
      expect(find.text('— Epictetus'), findsOneWidget);
    });
  });
}
