import 'package:flutter_test/flutter_test.dart';
import 'package:kindwords/data/quotes_data.dart';

void main() {
  group('Quote Catalog - Data Integrity', () {
    test('Catalog contains at least 100 quotes', () {
      expect(kAllQuotes.length, greaterThanOrEqualTo(100));
    });

    test('Catalog has exactly 110 quotes', () {
      expect(kAllQuotes.length, equals(110));
    });

    test('No quote has empty text', () {
      for (final quote in kAllQuotes) {
        expect(
          quote.text.isNotEmpty,
          true,
          reason: 'Quote ${quote.id} has empty text',
        );
      }
    });

    test('All quote IDs are unique', () {
      final ids = kAllQuotes.map((q) => q.id).toList();
      final uniqueIds = ids.toSet();
      expect(uniqueIds.length, equals(ids.length),
          reason: 'Duplicate IDs found: ${ids.where((id) => ids.indexOf(id) != ids.lastIndexOf(id)).toSet()}');
    });

    test('All quote IDs match the q### format', () {
      final pattern = RegExp(r'^q\d{3,}$');
      for (final quote in kAllQuotes) {
        expect(pattern.hasMatch(quote.id), true,
            reason: 'Quote ID ${quote.id} does not match pattern q###');
      }
    });

    test('First 10 quotes are preserved from original set', () {
      expect(kAllQuotes[0].id, equals('q001'));
      expect(kAllQuotes[0].text, contains('Believe you can'));
      expect(kAllQuotes[9].id, equals('q010'));
      expect(kAllQuotes[9].text, contains('Be the energy'));
    });

    test('Quote IDs are sequentially numbered from q001 to q110', () {
      for (int i = 0; i < kAllQuotes.length; i++) {
        final expectedId = 'q${(i + 1).toString().padLeft(3, '0')}';
        expect(kAllQuotes[i].id, equals(expectedId),
            reason: 'Quote at index $i has incorrect ID');
      }
    });

    test('Author field can be null or non-empty string', () {
      for (final quote in kAllQuotes) {
        if (quote.author != null) {
          expect(quote.author!.isNotEmpty, true,
              reason: 'Quote ${quote.id} has non-null but empty author');
        }
      }
    });
  });
}
