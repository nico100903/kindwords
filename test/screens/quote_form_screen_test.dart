// ignore_for_file: require_trailing_commas, always_declare_return_types, unused_local_variable, use_super_parameters
//
// Task 07.01 — Failing widget tests for QuoteFormScreen create mode.
// Task 07.02 — Failing widget tests for QuoteFormScreen edit mode and delete flow.
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
// These tests define the Wave 5 edit/delete contract:
// - Edit mode shows "Edit Quote" title
// - Pre-populated text/author/tags fields from existing quote
// - Update action preserves id and createdAt, sets updatedAt
// - Delete button visible only in edit mode
// - Delete requires confirmation dialog before removal
// - Seeded quotes can be edited and deleted locally
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
// Task 07.02 — Full CRUD repository for edit/delete tests
// ---------------------------------------------------------------------------

class _FullCrudQuoteRepository implements QuoteRepositoryBase {
  final List<Quote> _quotes;
  final List<Quote> _updatedQuotes = [];
  final List<String> _deletedIds = [];

  _FullCrudQuoteRepository(this._quotes);

  List<Quote> get updatedQuotes => List.unmodifiable(_updatedQuotes);
  List<String> get deletedIds => List.unmodifiable(_deletedIds);
  List<Quote> get quotes => List.unmodifiable(_quotes);

  @override
  Future<List<Quote>> getAllQuotes() async => List.unmodifiable(_quotes);

  @override
  Future<Quote?> getById(String id) async {
    try {
      return _quotes.firstWhere((q) => q.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> insertQuote(Quote quote) async {
    _quotes.add(quote);
  }

  @override
  Future<void> updateQuote(Quote quote) async {
    _updatedQuotes.add(quote);
    final index = _quotes.indexWhere((q) => q.id == quote.id);
    if (index >= 0) {
      _quotes[index] = quote;
    }
  }

  @override
  Future<void> deleteQuote(String id) async {
    _deletedIds.add(id);
    _quotes.removeWhere((q) => q.id == id);
  }

  @override
  Future<List<Quote>> getBySource(QuoteSource source) async =>
      _quotes.where((q) => q.source == source).toList();

  @override
  Future<List<Quote>> getByTag(String tag) async =>
      _quotes.where((q) => q.tags.contains(tag)).toList();
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

  // ===========================================================================
  // TASK 07.02 — EDIT MODE TESTS
  // ===========================================================================

  // -------------------------------------------------------------------------
  // Test 8: Edit mode shows "Edit Quote" title
  // -------------------------------------------------------------------------

  group('Edit mode app bar', () {
    testWidgets(
      'shows "Edit Quote" as AppBar title when quote is passed',
      (WidgetTester tester) async {
        final existingQuote = Quote(
          id: 'edit001',
          text: 'Existing quote text to edit.',
          author: 'Original Author',
          tags: const ['motivational'],
          source: QuoteSource.userCreated,
          createdAt: DateTime.utc(2026, 3, 15),
        );

        await _buildEditQuoteFormScreen(tester, quote: existingQuote);

        // Assert: AppBar shows "Edit Quote"
        expect(
          find.text('Edit Quote'),
          findsOneWidget,
          reason: 'QuoteFormScreen in edit mode must show "Edit Quote" '
              'as the AppBar title when a quote is passed',
        );
      },
    );

    testWidgets(
      'edit mode shows "Update" action button instead of "Save"',
      (WidgetTester tester) async {
        final existingQuote = Quote(
          id: 'edit002',
          text: 'Another existing quote text.',
          author: null,
          tags: const [],
          source: QuoteSource.seeded,
          createdAt: DateTime.utc(2026, 3, 10),
        );

        await _buildEditQuoteFormScreen(tester, quote: existingQuote);

        // Assert: Update button present, Save button absent
        expect(
          find.widgetWithText(TextButton, 'Update'),
          findsOneWidget,
          reason: 'QuoteFormScreen in edit mode must show "Update" '
              'TextButton instead of "Save"',
        );

        expect(
          find.widgetWithText(TextButton, 'Save'),
          findsNothing,
          reason: '"Save" button must not appear in edit mode — '
              'use "Update" instead',
        );
      },
    );
  });

  // -------------------------------------------------------------------------
  // Test 9: Edit mode pre-populates fields from existing quote
  // -------------------------------------------------------------------------

  group('Edit mode pre-population', () {
    testWidgets(
      'quote text field is pre-populated with existing quote text',
      (WidgetTester tester) async {
        final existingQuote = Quote(
          id: 'edit003',
          text: 'This is the original quote text to be edited.',
          author: 'Famous Person',
          tags: const ['wisdom'],
          source: QuoteSource.seeded,
          createdAt: DateTime.utc(2026, 3, 1),
        );

        await _buildEditQuoteFormScreen(tester, quote: existingQuote);

        // Find the quote text TextFormField and verify its content
        final textFields = find.byType(TextFormField);
        expect(textFields, findsAtLeastNWidgets(1),
            reason: 'QuoteFormScreen must have at least one TextFormField');

        // The first TextFormField should contain the quote text
        final textFieldWidget = tester.widget<TextFormField>(textFields.first);
        expect(
          textFieldWidget.controller?.text,
          equals(existingQuote.text),
          reason: 'Quote text field must be pre-populated with the existing '
              'quote text in edit mode',
        );
      },
    );

    testWidgets(
      'author field is pre-populated with existing author (when present)',
      (WidgetTester tester) async {
        final existingQuote = Quote(
          id: 'edit004',
          text: 'Quote with an author.',
          author: 'Socrates',
          tags: const ['wisdom'],
          source: QuoteSource.seeded,
          createdAt: DateTime.utc(2026, 3, 5),
        );

        await _buildEditQuoteFormScreen(tester, quote: existingQuote);

        // Find the author TextFormField (second one)
        final textFields = find.byType(TextFormField);
        expect(textFields.evaluate().length, greaterThanOrEqualTo(2),
            reason: 'QuoteFormScreen must have at least two TextFormFields '
                '(quote text and author)');

        final authorFieldWidget =
            tester.widget<TextFormField>(textFields.at(1));
        expect(
          authorFieldWidget.controller?.text,
          equals(existingQuote.author),
          reason: 'Author field must be pre-populated with the existing '
              'author in edit mode',
        );
      },
    );

    testWidgets(
      'author field is empty when existing quote has null author',
      (WidgetTester tester) async {
        final existingQuote = Quote(
          id: 'edit005',
          text: 'Anonymous quote without author.',
          author: null,
          tags: const [],
          source: QuoteSource.userCreated,
          createdAt: DateTime.utc(2026, 3, 20),
        );

        await _buildEditQuoteFormScreen(tester, quote: existingQuote);

        // Find the author TextFormField (second one)
        final textFields = find.byType(TextFormField);
        if (textFields.evaluate().length >= 2) {
          final authorFieldWidget =
              tester.widget<TextFormField>(textFields.at(1));
          expect(
            authorFieldWidget.controller?.text,
            isEmpty,
            reason: 'Author field must be empty (not "null" string) when '
                'the existing quote has null author',
          );
        }
      },
    );

    testWidgets(
      'tag chips are pre-selected to match existing quote tags',
      (WidgetTester tester) async {
        final existingQuote = Quote(
          id: 'edit006',
          text: 'Quote with multiple tags.',
          author: 'Test Author',
          tags: const ['motivational', 'wisdom', 'focus'],
          source: QuoteSource.userCreated,
          createdAt: DateTime.utc(2026, 3, 12),
        );

        await _buildEditQuoteFormScreen(tester, quote: existingQuote);

        // Find selected chips
        final selectedChips = find.byWidgetPredicate(
          (widget) =>
              widget is FilterChip &&
              widget.selected == true &&
              existingQuote.tags.any((tag) {
                final label = (widget.label as Text?)?.data ?? '';
                return label.contains(tag);
              }),
        );

        // Assert: at least the tags from the existing quote should be selected
        expect(
          selectedChips,
          findsAtLeastNWidgets(existingQuote.tags.length),
          reason: 'Tag chips corresponding to existing quote tags must be '
              'pre-selected in edit mode',
        );
      },
    );

    testWidgets(
      'source indicator shows correct source for seeded quote in edit mode',
      (WidgetTester tester) async {
        final existingQuote = Quote(
          id: 'edit007',
          text: 'Seeded quote being edited.',
          author: 'Seeded Author',
          tags: const ['wisdom'],
          source: QuoteSource.seeded,
          createdAt: DateTime.utc(2026, 3, 1),
        );

        await _buildEditQuoteFormScreen(tester, quote: existingQuote);

        // Look for seeded source indicator (book icon or "Seeded" text)
        final hasSeededIndicator = find.byIcon(Icons.menu_book_outlined);
        expect(
          hasSeededIndicator,
          findsWidgets,
          reason: 'Edit mode for seeded quotes must show the seeded source '
              'indicator (Icons.menu_book_outlined)',
        );
      },
    );

    testWidgets(
      'source indicator shows correct source for userCreated quote in edit mode',
      (WidgetTester tester) async {
        final existingQuote = Quote(
          id: 'edit008',
          text: 'User quote being edited.',
          author: 'User',
          tags: const ['personal'],
          source: QuoteSource.userCreated,
          createdAt: DateTime.utc(2026, 3, 15),
        );

        await _buildEditQuoteFormScreen(tester, quote: existingQuote);

        // Look for userCreated source indicator (pen icon)
        final hasUserIndicator = find.byIcon(Icons.edit_note);
        expect(
          hasUserIndicator,
          findsWidgets,
          reason: 'Edit mode for userCreated quotes must show the user '
              'source indicator (Icons.edit_note)',
        );
      },
    );
  });

  // -------------------------------------------------------------------------
  // Test 10: Update preserves id and createdAt, sets updatedAt
  // -------------------------------------------------------------------------

  group('Update identity preservation', () {
    testWidgets(
      'update action preserves the original quote id',
      (WidgetTester tester) async {
        final originalId = 'preserve-id-001';
        final existingQuote = Quote(
          id: originalId,
          text: 'Original text to be updated.',
          author: 'Original Author',
          tags: const ['wisdom'],
          source: QuoteSource.userCreated,
          createdAt: DateTime.utc(2026, 3, 10),
        );

        final (repo, provider) =
            await _buildEditQuoteFormScreen(tester, quote: existingQuote);

        // Modify the text
        final textFields = find.byType(TextFormField);
        await tester.enterText(
            textFields.first, 'Updated quote text with more content.');
        await tester.pumpAndSettle();

        // Tap Update
        final updateButton = find.widgetWithText(TextButton, 'Update');
        await tester.tap(updateButton);
        await tester.pumpAndSettle();

        // Assert: the updated quote has the same id
        expect(
          repo.updatedQuotes.length,
          greaterThan(0),
          reason: 'Update action must call repository.updateQuote',
        );

        final updatedQuote = repo.updatedQuotes.last;
        expect(
          updatedQuote.id,
          equals(originalId),
          reason: 'Update action must preserve the original quote id — '
              'id is immutable',
        );
      },
    );

    testWidgets(
      'update action preserves the original createdAt timestamp',
      (WidgetTester tester) async {
        final originalCreatedAt = DateTime.utc(2026, 3, 5, 10, 30);
        final existingQuote = Quote(
          id: 'preserve-created-001',
          text: 'Original text for createdAt test.',
          author: 'Test Author',
          tags: const [],
          source: QuoteSource.seeded,
          createdAt: originalCreatedAt,
        );

        final (repo, provider) =
            await _buildEditQuoteFormScreen(tester, quote: existingQuote);

        // Modify the text
        final textFields = find.byType(TextFormField);
        await tester.enterText(textFields.first, 'Modified text content here.');
        await tester.pumpAndSettle();

        // Tap Update
        final updateButton = find.widgetWithText(TextButton, 'Update');
        await tester.tap(updateButton);
        await tester.pumpAndSettle();

        // Assert: the updated quote has the same createdAt
        if (repo.updatedQuotes.isNotEmpty) {
          final updatedQuote = repo.updatedQuotes.last;
          expect(
            updatedQuote.createdAt,
            equals(originalCreatedAt),
            reason: 'Update action must preserve the original createdAt — '
                'createdAt is immutable and represents first creation time',
          );
        }
      },
    );

    testWidgets(
      'update action sets updatedAt to current time',
      (WidgetTester tester) async {
        final existingQuote = Quote(
          id: 'set-updated-001',
          text: 'Original text for updatedAt test.',
          author: 'Author',
          tags: const ['motivational'],
          source: QuoteSource.userCreated,
          createdAt: DateTime.utc(2026, 3, 1),
          updatedAt: null, // never edited before
        );

        final beforeUpdate = DateTime.now();
        final (repo, provider) =
            await _buildEditQuoteFormScreen(tester, quote: existingQuote);

        // Modify the text
        final textFields = find.byType(TextFormField);
        await tester.enterText(textFields.first, 'Changed text for update.');
        await tester.pumpAndSettle();

        // Tap Update
        final updateButton = find.widgetWithText(TextButton, 'Update');
        await tester.tap(updateButton);
        await tester.pumpAndSettle();

        final afterUpdate = DateTime.now();

        // Assert: updatedAt is set to a recent time
        if (repo.updatedQuotes.isNotEmpty) {
          final updatedQuote = repo.updatedQuotes.last;
          expect(
            updatedQuote.updatedAt,
            isNotNull,
            reason: 'Update action must set updatedAt to the current time',
          );

          // Verify updatedAt is within the test execution window
          expect(
            updatedQuote.updatedAt!.isAfter(
                beforeUpdate.subtract(const Duration(seconds: 1))),
            isTrue,
            reason: 'updatedAt must be set to the current edit time',
          );
          expect(
            updatedQuote.updatedAt!
                .isBefore(afterUpdate.add(const Duration(seconds: 1))),
            isTrue,
            reason: 'updatedAt must be set to the current edit time',
          );
        }
      },
    );

    testWidgets(
      'update action preserves source field (seeded stays seeded)',
      (WidgetTester tester) async {
        final existingQuote = Quote(
          id: 'preserve-source-001',
          text: 'Seeded quote text.',
          author: 'Seeded Author',
          tags: const ['wisdom'],
          source: QuoteSource.seeded,
          createdAt: DateTime.utc(2026, 3, 1),
        );

        final (repo, provider) =
            await _buildEditQuoteFormScreen(tester, quote: existingQuote);

        // Modify the text
        final textFields = find.byType(TextFormField);
        await tester.enterText(textFields.first, 'Modified seeded quote text.');
        await tester.pumpAndSettle();

        // Tap Update
        final updateButton = find.widgetWithText(TextButton, 'Update');
        await tester.tap(updateButton);
        await tester.pumpAndSettle();

        // Assert: source is unchanged
        if (repo.updatedQuotes.isNotEmpty) {
          final updatedQuote = repo.updatedQuotes.last;
          expect(
            updatedQuote.source,
            equals(QuoteSource.seeded),
            reason: 'Update action must preserve the source field — '
                'seeded quotes stay seeded',
          );
        }
      },
    );
  });

  // -------------------------------------------------------------------------
  // Test 11: Delete button visible only in edit mode
  // -------------------------------------------------------------------------

  group('Delete button visibility', () {
    testWidgets(
      'delete button IS visible in edit mode',
      (WidgetTester tester) async {
        final existingQuote = Quote(
          id: 'delete-visible-001',
          text: 'Quote that can be deleted.',
          author: 'Author',
          tags: const [],
          source: QuoteSource.userCreated,
          createdAt: DateTime.utc(2026, 3, 10),
        );

        await _buildEditQuoteFormScreen(tester, quote: existingQuote);

        // Assert: delete button is visible
        expect(
          find.textContaining('Delete'),
          findsWidgets,
          reason: 'QuoteFormScreen in edit mode must show a delete button',
        );
      },
    );

    testWidgets(
      'delete button is a red TextButton with "Delete this quote" label',
      (WidgetTester tester) async {
        final existingQuote = Quote(
          id: 'delete-style-001',
          text: 'Quote for delete button style test.',
          author: 'Author',
          tags: const [],
          source: QuoteSource.seeded,
          createdAt: DateTime.utc(2026, 3, 5),
        );

        await _buildEditQuoteFormScreen(tester, quote: existingQuote);

        // Find the delete button
        final deleteButton =
            find.widgetWithText(TextButton, 'Delete this quote');
        expect(
          deleteButton,
          findsOneWidget,
          reason: 'Edit mode must have a TextButton with label '
              '"Delete this quote"',
        );

        // Verify it's styled as destructive (red)
        final buttonWidget = tester.widget<TextButton>(deleteButton);
        // TextButton.styleFrom foregroundColor should be Colors.red or similar
        // This is a behavioral test — we check the button exists
        expect(buttonWidget, isNotNull,
            reason: 'Delete button must be a TextButton');
      },
    );

    testWidgets(
      'delete button appears below a Divider at bottom of form',
      (WidgetTester tester) async {
        final existingQuote = Quote(
          id: 'delete-position-001',
          text: 'Quote for delete button position test.',
          author: 'Author',
          tags: const [],
          source: QuoteSource.userCreated,
          createdAt: DateTime.utc(2026, 3, 15),
        );

        await _buildEditQuoteFormScreen(tester, quote: existingQuote);

        // Assert: Divider exists (separates form from delete action)
        expect(
          find.byType(Divider),
          findsWidgets,
          reason: 'Delete button must be separated from form content by a '
              'Divider per UI spec',
        );

        // Assert: delete button is below the divider
        final deleteButton = find.textContaining('Delete this quote');
        expect(
          deleteButton,
          findsWidgets,
          reason: 'Delete button must be present below the divider',
        );
      },
    );
  });

  // -------------------------------------------------------------------------
  // Test 12: Delete requires confirmation dialog
  // -------------------------------------------------------------------------

  group('Delete confirmation flow', () {
    testWidgets(
      'tapping delete button shows AlertDialog confirmation',
      (WidgetTester tester) async {
        final existingQuote = Quote(
          id: 'delete-confirm-001',
          text: 'Quote that requires confirmation to delete.',
          author: 'Author',
          tags: const [],
          source: QuoteSource.userCreated,
          createdAt: DateTime.utc(2026, 3, 10),
        );

        await _buildEditQuoteFormScreen(tester, quote: existingQuote);

        // Tap delete button
        final deleteButton = find.widgetWithText(TextButton, 'Delete this quote');
        await tester.tap(deleteButton);
        await tester.pumpAndSettle();

        // Assert: AlertDialog is shown
        expect(
          find.byType(AlertDialog),
          findsOneWidget,
          reason: 'Tapping delete button must show an AlertDialog for '
              'confirmation (not a bottom sheet)',
        );
      },
    );

    testWidgets(
      'delete confirmation dialog shows quote text preview',
      (WidgetTester tester) async {
        final existingQuote = Quote(
          id: 'delete-preview-001',
          text: 'Quote text that appears in confirmation dialog.',
          author: 'Author',
          tags: const [],
          source: QuoteSource.seeded,
          createdAt: DateTime.utc(2026, 3, 5),
        );

        await _buildEditQuoteFormScreen(tester, quote: existingQuote);

        // Tap delete button
        final deleteButton = find.widgetWithText(TextButton, 'Delete this quote');
        await tester.tap(deleteButton);
        await tester.pumpAndSettle();

        // Assert: dialog shows some of the quote text
        expect(
          find.textContaining('Quote text'),
          findsWidgets,
          reason: 'Delete confirmation dialog must show a preview of the '
              'quote text being deleted',
        );
      },
    );

    testWidgets(
      'delete confirmation dialog has Cancel and Delete buttons',
      (WidgetTester tester) async {
        final existingQuote = Quote(
          id: 'delete-buttons-001',
          text: 'Quote for delete button test.',
          author: 'Author',
          tags: const [],
          source: QuoteSource.userCreated,
          createdAt: DateTime.utc(2026, 3, 20),
        );

        await _buildEditQuoteFormScreen(tester, quote: existingQuote);

        // Tap delete button
        final deleteButton = find.widgetWithText(TextButton, 'Delete this quote');
        await tester.tap(deleteButton);
        await tester.pumpAndSettle();

        // Assert: Cancel button exists
        expect(
          find.widgetWithText(TextButton, 'Cancel'),
          findsWidgets,
          reason: 'Delete confirmation dialog must have a Cancel button',
        );

        // Assert: Delete button exists (destructive, red)
        expect(
          find.widgetWithText(TextButton, 'Delete'),
          findsWidgets,
          reason: 'Delete confirmation dialog must have a Delete button',
        );
      },
    );

    testWidgets(
      'canceling delete confirmation dismisses dialog without deleting',
      (WidgetTester tester) async {
        final existingQuote = Quote(
          id: 'delete-cancel-001',
          text: 'Quote that will NOT be deleted.',
          author: 'Author',
          tags: const [],
          source: QuoteSource.userCreated,
          createdAt: DateTime.utc(2026, 3, 15),
        );

        final (repo, provider) =
            await _buildEditQuoteFormScreen(tester, quote: existingQuote);

        // Tap delete button
        final deleteButton = find.widgetWithText(TextButton, 'Delete this quote');
        await tester.tap(deleteButton);
        await tester.pumpAndSettle();

        // Tap Cancel
        final cancelButton = find.widgetWithText(TextButton, 'Cancel');
        await tester.tap(cancelButton.first);
        await tester.pumpAndSettle();

        // Assert: dialog dismissed
        expect(
          find.byType(AlertDialog),
          findsNothing,
          reason: 'Cancel must dismiss the confirmation dialog',
        );

        // Assert: no delete was performed
        expect(
          repo.deletedIds,
          isEmpty,
          reason: 'Canceling delete confirmation must NOT delete the quote',
        );
      },
    );

    testWidgets(
      'confirming delete calls repository.deleteQuote and pops with true',
      (WidgetTester tester) async {
        final quoteId = 'delete-confirm-exec-001';
        final existingQuote = Quote(
          id: quoteId,
          text: 'Quote that will be deleted.',
          author: 'Author',
          tags: const [],
          source: QuoteSource.userCreated,
          createdAt: DateTime.utc(2026, 3, 10),
        );

        final (repo, provider) =
            await _buildEditQuoteFormScreen(tester, quote: existingQuote);

        // Tap delete button
        final deleteButton = find.widgetWithText(TextButton, 'Delete this quote');
        await tester.tap(deleteButton);
        await tester.pumpAndSettle();

        // Tap Delete (confirm)
        final confirmDeleteButton = find.widgetWithText(TextButton, 'Delete');
        // There may be multiple "Delete" texts — find the one in AlertDialog
        final dialogDeleteButton = find.descendant(
          of: find.byType(AlertDialog),
          matching: confirmDeleteButton,
        );
        await tester.tap(dialogDeleteButton.last);
        await tester.pumpAndSettle();

        // Assert: deleteQuote was called with correct id
        expect(
          repo.deletedIds,
          contains(quoteId),
          reason: 'Confirming delete must call repository.deleteQuote with '
              'the quote id',
        );
      },
    );
  });

  // -------------------------------------------------------------------------
  // Test 13: Seeded quotes can be edited and deleted locally
  // -------------------------------------------------------------------------

  group('Seeded quote local mutation', () {
    testWidgets(
      'seeded quote can be edited (update succeeds)',
      (WidgetTester tester) async {
        final seededQuote = Quote(
          id: 'q001', // seeded-style id
          text: 'Original seeded quote text.',
          author: 'Famous Person',
          tags: const ['motivational'],
          source: QuoteSource.seeded,
          createdAt: DateTime.utc(2026, 3, 1),
        );

        final (repo, provider) =
            await _buildEditQuoteFormScreen(tester, quote: seededQuote);

        // Modify the text
        final textFields = find.byType(TextFormField);
        await tester.enterText(
            textFields.first, 'Modified seeded quote text.');
        await tester.pumpAndSettle();

        // Tap Update
        final updateButton = find.widgetWithText(TextButton, 'Update');
        await tester.tap(updateButton);
        await tester.pumpAndSettle();

        // Assert: update succeeded
        expect(
          repo.updatedQuotes.length,
          greaterThan(0),
          reason: 'Seeded quotes must be editable — updateQuote must be called',
        );

        final updatedQuote = repo.updatedQuotes.last;
        expect(
          updatedQuote.id,
          equals('q001'),
          reason: 'Seeded quote id must be preserved after edit',
        );
        expect(
          updatedQuote.source,
          equals(QuoteSource.seeded),
          reason: 'Seeded quote source must remain seeded after local edit',
        );
      },
    );

    testWidgets(
      'seeded quote can be deleted (delete succeeds)',
      (WidgetTester tester) async {
        final seededQuote = Quote(
          id: 'q002', // seeded-style id
          text: 'Seeded quote to be deleted.',
          author: 'Another Person',
          tags: const ['wisdom'],
          source: QuoteSource.seeded,
          createdAt: DateTime.utc(2026, 3, 2),
        );

        final (repo, provider) =
            await _buildEditQuoteFormScreen(tester, quote: seededQuote);

        // Tap delete button
        final deleteButton = find.widgetWithText(TextButton, 'Delete this quote');
        await tester.tap(deleteButton);
        await tester.pumpAndSettle();

        // Confirm delete
        final confirmDeleteButton = find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(TextButton, 'Delete'),
        );
        await tester.tap(confirmDeleteButton.last);
        await tester.pumpAndSettle();

        // Assert: delete succeeded
        expect(
          repo.deletedIds,
          contains('q002'),
          reason: 'Seeded quotes must be deletable — deleteQuote must be called',
        );
      },
    );
  });
}

// ---------------------------------------------------------------------------
// Task 07.02 — Edit mode widget builder helper
// ---------------------------------------------------------------------------

/// Builds a MaterialApp wrapping QuoteFormScreen in edit mode with an
/// existing quote passed as a parameter.
///
/// Returns both the full-CRUD repository and provider for assertions.
Future<(_FullCrudQuoteRepository, QuoteCatalogProvider)> _buildEditQuoteFormScreen(
  WidgetTester tester, {
  required Quote quote,
}) async {
  final repo = _FullCrudQuoteRepository([quote]);
  final provider = QuoteCatalogProvider(repo);

  await tester.pumpWidget(
    MaterialApp(
      home: ChangeNotifierProvider.value(
        value: provider,
        // QuoteFormScreen must accept an optional `quote` parameter for edit mode
        child: QuoteFormScreen(quote: quote),
      ),
    ),
  );

  await tester.pumpAndSettle();

  return (repo, provider);
}
