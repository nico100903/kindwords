import 'package:flutter/material.dart';
import 'package:kindwords/models/quote.dart';

/// A stateless card widget that displays a [Quote]'s text and optional author.
///
/// Extracted from [HomeScreen] in Wave R6. Wraps content in a [Card] with
/// padding and styled [Text] widgets. The author line is only rendered when
/// [quote.author] is non-null.
class QuoteCard extends StatelessWidget {
  final Quote quote;

  const QuoteCard({super.key, required this.quote});

  @override
  Widget build(BuildContext context) {
    return Card(
      key: key,
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
    );
  }
}
