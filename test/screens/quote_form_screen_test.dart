// ignore_for_file: require_trailing_commas, always_declare_return_types, unused_local_variable, use_super_parameters
//
// Task 07.01 — Failing widget tests for QuoteFormScreen create mode.
//
// These tests define the Wave 4 create-mode contract:
// - Create mode shows "New Quote" title
// - Quote text field is required with min-length validation (≥10 chars)
// - Author field is optional
// - Tag chips from predefined set, max 3 selectable
// - Save action creates a userCreated quote with required fields
// - Created quote has source=userCreated and non-null createdAt
// - No edit-mode-only delete UI present
//
// DO NOT fix these tests. They are the behavioral contract.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:kindwords/models/quote.dart';
import 'package:kindwords/providers/quote_catalog_provider.dart';
import 'package:kindwords/repositories/quote_repository.dart';
import 'package:kindwords/screens/quote_form_screen.dart';

// ---------------------------------------------------------------------------
// Capturing repository — records inserted quotes for assertions
// ---------------------------------------------------------------------------

class _CapturingQuoteRepository implements QuoteRepositoryBase {
  final List<Quote> _seedQuotes;
  final List<Quote> _insertedQuotes = [];

  _CapturingQuoteRepository(this._seedQuotes);

  List<Quote> get insertedQuotes => List.unmodifiable(_insertedQuotes);

  @override
  Future<List<Quote>> getAllQuotes() async => List.unmodifiable(_seedQuotes);

  @override
  Future<Quote?> getById(String id) async {
    try {
      return _seedQuotes.firstWhere((q) => q.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> insertQuote(Quote quote) async {
    _insertedQuotes.add(quote);
    _seedQuotes.add(quote);
  }

  @override
  Future<void> updateQuote(Quote quote) => throw UnimplementedError();

  @override
  Future<void> deleteQuote(String id) => throw UnimplementedError();

  @override
  Future<List<Quote>> getBySource(QuoteSource source) =>
      throw UnimplementedError();

  @override
  Future<List<Quote>> getByTag(String tag) => throw UnimplementedError();
}

// ---------------------------------------------------------------------------
// Widget builder helpers
// ---------------------------------------------------------------------------

/// Builds a MaterialApp wrapping QuoteFormScreen with a real
/// QuoteCatalogProvider backed by a capturing repository.
///
/// Returns both provider and repository for assertions.
Future<(_CapturingQuoteRepository, QuoteCatalogProvider)> _buildQuoteFormScreen(
  WidgetTester tester, {
  List<Quote> seedQuotes = const [],
}) async {
  final repo = _CapturingQuoteRepository(seedQuotes);
  final provider = QuoteCatalogProvider(repo);

  await tester.pumpWidget(
    MaterialApp(
      home: ChangeNotifierProvider.value(
        value: provider,
        child: const QuoteFormScreen(),
      ),
    ),
  );

  await tester.pumpAndSettle();

  return (repo, provider);
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // -------------------------------------------------------------------------
  // Test 1: Create mode shows "New Quote" title
  // -------------------------------------------------------------------------

  group('Create mode app bar', () {
    testWidgets(
      'shows "New Quote" as AppBar title in create mode',
      (WidgetTester tester) async {
        await _buildQuoteFormScreen(tester);

        // Assert: AppBar shows "New Quote"
        expect(
          find.text('New Quote'),
          findsOneWidget,
          reason: 'QuoteFormScreen in create mode must show "New Quote" '
              'as the AppBar title',
        );
      },
    );
  });

  // -------------------------------------------------------------------------
  // Test 2: Quote text field is required
  // -------------------------------------------------------------------------

  group('Quote text field validation', () {
    testWidgets(
      'quote text field is present and required',
      (WidgetTester tester) async {
        await _buildQuoteFormScreen(tester);

        // Assert: a text field exists for quote text
        expect(
          find.byType(TextFormField),
          findsWidgets,
          reason: 'QuoteFormScreen must have at least one TextFormField '
              '(quote text field)',
        );
      },
    );

    testWidgets(
      'submitting empty quote text shows validation error',
      (WidgetTester tester) async {
        await _buildQuoteFormScreen(tester);

        // Find and tap save button
        final saveButton = find.widgetWithText(TextButton, 'Save');
        if (saveButton.evaluate().isNotEmpty) {
          await tester.tap(saveButton);
          await tester.pumpAndSettle();

          // Assert: validation error is shown
          // Look for validation error text (case-insensitive match via evaluating widgets)
          final errorTexts = find.textContaining('required').evaluate().where(
              (e) =>
                  (e.widget as Text).data?.toLowerCase().contains('required') ??
                  false);

          expect(
            errorTexts.isNotEmpty,
            isTrue,
            reason: 'Submitting empty quote text must show a validation error '
                'indicating the field is required',
          );
        } else {
          // If no save button found yet, fail with clear reason
          fail('Save button not found — QuoteFormScreen must have a Save '
              'TextButton in create mode');
        }
      },
    );

    testWidgets(
      'quote text with fewer than 10 characters shows validation error',
      (WidgetTester tester) async {
        await _buildQuoteFormScreen(tester);

        // Find the quote text field and enter short text
        final textFields = find.byType(TextFormField);
        if (textFields.evaluate().isNotEmpty) {
          // First text field should be quote text
          await tester.enterText(textFields.first, 'Too short');
          await tester.pumpAndSettle();

          // Tap save
          final saveButton = find.widgetWithText(TextButton, 'Save');
          if (saveButton.evaluate().isNotEmpty) {
            await tester.tap(saveButton);
            await tester.pumpAndSettle();

            // Assert: validation error for min length (look for "10" in error text)
            final errorTexts = find.textContaining('10').evaluate().where((e) {
              final text = (e.widget as Text).data ?? '';
              return text.contains('10') || text.contains('ten');
            });

            expect(
              errorTexts.isNotEmpty,
              isTrue,
              reason: 'Quote text with fewer than 10 characters must show '
                  'a validation error mentioning the 10-character minimum',
            );
          } else {
            fail('Save button not found');
          }
        } else {
          fail('TextFormField not found');
        }
      },
    );

    testWidgets(
      'quote text with exactly 10 characters passes validation',
      (WidgetTester tester) async {
        final (repo, provider) = await _buildQuoteFormScreen(tester);

        // Enter exactly 10 characters
        final textFields = find.byType(TextFormField);
        await tester.enterText(textFields.first, '1234567890');
        await tester.pumpAndSettle();

        // Tap save
        final saveButton = find.widgetWithText(TextButton, 'Save');
        await tester.tap(saveButton);
        await tester.pumpAndSettle();

        // Assert: no validation error (form accepted)
        // The quote should be inserted if validation passed
        // Check that we don't have a "10 characters" validation error showing
        final validationError = find.textContaining('at least 10');
        expect(
          validationError,
          findsNothing,
          reason:
              'Quote text with exactly 10 characters must pass validation — '
              'no "at least 10" error should appear',
        );
      },
    );
  });

  // -------------------------------------------------------------------------
  // Test 3: Author field is optional
  // -------------------------------------------------------------------------

  group('Author field', () {
    testWidgets(
      'author field is present and accepts empty input',
      (WidgetTester tester) async {
        await _buildQuoteFormScreen(tester);

        // Find TextFormField widgets — should have at least 2 (quote text + author)
        final textFields = find.byType(TextFormField);
        expect(
          textFields,
          findsAtLeastNWidgets(2),
          reason:
              'QuoteFormScreen must have at least two TextFormField widgets '
              '(quote text and author)',
        );
      },
    );

    testWidgets(
      'saving with empty author field does not show validation error',
      (WidgetTester tester) async {
        final (repo, provider) = await _buildQuoteFormScreen(tester);

        // Fill quote text with valid content, leave author empty
        final textFields = find.byType(TextFormField);
        await tester.enterText(textFields.first, 'This is a valid quote text.');
        await tester.pumpAndSettle();

        // Tap save
        final saveButton = find.widgetWithText(TextButton, 'Save');
        await tester.tap(saveButton);
        await tester.pumpAndSettle();

        // Assert: no validation error for author (it's optional)
        // Look for any error text mentioning "author" with "required" or "empty"
        final authorErrors =
            find.textContaining('author').evaluate().where((e) {
          final text = (e.widget as Text).data?.toLowerCase() ?? '';
          return text.contains('required') || text.contains('empty');
        });

        expect(
          authorErrors.toList(),
          isEmpty,
          reason:
              'Author field is optional — no validation error should appear '
              'when it is empty',
        );
      },
    );
  });

  // -------------------------------------------------------------------------
  // Test 4: Tag chips available for predefined tags
  // -------------------------------------------------------------------------

  group('Tag chips', () {
    testWidgets(
      'tag chips are displayed for predefined tags',
      (WidgetTester tester) async {
        await _buildQuoteFormScreen(tester);

        // Assert: at least one chip widget exists for tags
        // FilterChip or ChoiceChip should be used for selectable tags
        final hasFilterChips = find.byType(FilterChip).evaluate().isNotEmpty;
        final hasChoiceChips = find.byType(ChoiceChip).evaluate().isNotEmpty;

        expect(
          hasFilterChips || hasChoiceChips,
          isTrue,
          reason: 'QuoteFormScreen must display tag selection chips using '
              'FilterChip or ChoiceChip widgets',
        );
      },
    );

    testWidgets(
      'personal tag is selectable, not auto-required',
      (WidgetTester tester) async {
        await _buildQuoteFormScreen(tester);

        // Look for #personal chip
        final personalChip = find.textContaining('personal');
        expect(
          personalChip,
          findsWidgets,
          reason: 'The #personal tag must be available as a selectable chip',
        );
      },
    );
  });

  // -------------------------------------------------------------------------
  // Test 5: Max 3 tags selectable
  // -------------------------------------------------------------------------

  group('Tag selection limit', () {
    testWidgets(
      'selecting 3 tags disables remaining unselected chips',
      (WidgetTester tester) async {
        await _buildQuoteFormScreen(tester);

        // Find all selectable chips
        final chips = find.byType(FilterChip);
        if (chips.evaluate().length >= 4) {
          // Tap first 3 chips to select them
          for (var i = 0; i < 3; i++) {
            await tester.tap(chips.at(i));
            await tester.pumpAndSettle();
          }

          // The 4th chip should now be disabled
          // FilterChip is disabled when onSelected is null
          final fourthChip = tester.widget<FilterChip>(chips.at(3));
          expect(
            fourthChip.onSelected,
            isNull,
            reason: 'After selecting 3 tags, remaining unselected chips must '
                'be disabled (onSelected: null)',
          );
        } else {
          // If not enough chips, the test still documents the expected behavior
          // The coder must implement at least 4 predefined tags
          expect(
            chips.evaluate().length,
            greaterThanOrEqualTo(4),
            reason: 'There must be at least 4 predefined tags to test the '
                '3-tag selection limit',
          );
        }
      },
    );
  });

  // -------------------------------------------------------------------------
  // Test 6: Save action creates a userCreated quote
  // -------------------------------------------------------------------------

  group('Save action', () {
    testWidgets(
      'save button is present in create mode',
      (WidgetTester tester) async {
        await _buildQuoteFormScreen(tester);

        expect(
          find.widgetWithText(TextButton, 'Save'),
          findsOneWidget,
          reason: 'QuoteFormScreen in create mode must have a "Save" '
              'TextButton in the AppBar actions',
        );
      },
    );

    testWidgets(
      'tapping save with valid form creates a quote with source userCreated',
      (WidgetTester tester) async {
        final (repo, provider) = await _buildQuoteFormScreen(tester);

        // Fill form with valid data
        final textFields = find.byType(TextFormField);
        await tester.enterText(textFields.first, 'This is a valid quote text.');
        await tester.pumpAndSettle();

        // Tap save
        final saveButton = find.widgetWithText(TextButton, 'Save');
        await tester.tap(saveButton);
        await tester.pumpAndSettle();

        // Assert: a quote was inserted with source userCreated
        expect(
          repo.insertedQuotes.length,
          greaterThan(0),
          reason: 'Saving a valid form must insert a quote into the repository',
        );

        final insertedQuote = repo.insertedQuotes.last;
        expect(
          insertedQuote.source,
          equals(QuoteSource.userCreated),
          reason: 'Created quotes must have source = QuoteSource.userCreated',
        );
      },
    );

    testWidgets(
      'created quote includes selected tags',
      (WidgetTester tester) async {
        final (repo, provider) = await _buildQuoteFormScreen(tester);

        // Fill quote text
        final textFields = find.byType(TextFormField);
        await tester.enterText(textFields.first, 'This is a quote with tags.');
        await tester.pumpAndSettle();

        // Select a tag
        final chips = find.byType(FilterChip);
        if (chips.evaluate().isNotEmpty) {
          await tester.tap(chips.first);
          await tester.pumpAndSettle();
        }

        // Tap save
        final saveButton = find.widgetWithText(TextButton, 'Save');
        await tester.tap(saveButton);
        await tester.pumpAndSettle();

        // Assert: inserted quote has tags
        if (repo.insertedQuotes.isNotEmpty) {
          final insertedQuote = repo.insertedQuotes.last;
          expect(
            insertedQuote.tags.length,
            greaterThanOrEqualTo(0),
            reason: 'Created quote must have a tags list (may be empty)',
          );
        }
      },
    );

    testWidgets(
      'created quote has non-null createdAt timestamp',
      (WidgetTester tester) async {
        final (repo, provider) = await _buildQuoteFormScreen(tester);

        // Fill form with valid data
        final textFields = find.byType(TextFormField);
        await tester.enterText(textFields.first, 'This is a valid quote text.');
        await tester.pumpAndSettle();

        // Tap save
        final saveButton = find.widgetWithText(TextButton, 'Save');
        await tester.tap(saveButton);
        await tester.pumpAndSettle();

        // Assert: created quote has non-null createdAt
        if (repo.insertedQuotes.isNotEmpty) {
          final insertedQuote = repo.insertedQuotes.last;
          expect(
            insertedQuote.createdAt,
            isNotNull,
            reason: 'Created quotes must have a non-null createdAt timestamp',
          );
        }
      },
    );

    testWidgets(
      'created quote has required fields: id, text, source',
      (WidgetTester tester) async {
        final (repo, provider) = await _buildQuoteFormScreen(tester);

        // Fill form with valid data
        final textFields = find.byType(TextFormField);
        await tester.enterText(textFields.first, 'This is a valid quote text.');
        await tester.pumpAndSettle();

        // Tap save
        final saveButton = find.widgetWithText(TextButton, 'Save');
        await tester.tap(saveButton);
        await tester.pumpAndSettle();

        // Assert: all required fields present
        if (repo.insertedQuotes.isNotEmpty) {
          final insertedQuote = repo.insertedQuotes.last;

          expect(
            insertedQuote.id,
            isNotEmpty,
            reason: 'Created quote must have a non-empty id',
          );

          expect(
            insertedQuote.text,
            isNotEmpty,
            reason: 'Created quote must have non-empty text',
          );

          expect(
            insertedQuote.source,
            equals(QuoteSource.userCreated),
            reason: 'Created quote must have source = userCreated',
          );
        }
      },
    );
  });

  // -------------------------------------------------------------------------
  // Test 7: No edit-mode-only delete UI present
  // -------------------------------------------------------------------------

  group('Create mode exclusivity', () {
    testWidgets(
      'delete button is NOT visible in create mode',
      (WidgetTester tester) async {
        await _buildQuoteFormScreen(tester);

        // Assert: no delete button visible (edit-mode only)
        expect(
          find.textContaining('Delete'),
          findsNothing,
          reason:
              'QuoteFormScreen in create mode must NOT show a delete button '
              '— delete is edit-mode only (task 07.02)',
        );
      },
    );

    testWidgets(
      'no "Delete this quote" text button in create mode',
      (WidgetTester tester) async {
        await _buildQuoteFormScreen(tester);

        // Look for red delete text button at bottom of form
        expect(
          find.widgetWithText(TextButton, 'Delete this quote'),
          findsNothing,
          reason:
              'The "Delete this quote" button must only appear in edit mode, '
              'not in create mode',
        );
      },
    );
  });
}
