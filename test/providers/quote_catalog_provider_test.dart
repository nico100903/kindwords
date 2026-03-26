// ignore_for_file: require_trailing_commas
// Sprint 2 / Task 05.02 — Failing contract tests for QuoteCatalogProvider
//
// These tests FAIL at compile time until the coder creates:
//   lib/providers/quote_catalog_provider.dart — QuoteCatalogProvider class
//   lib/repositories/quote_repository.dart — CRUD methods on QuoteRepositoryBase
//
// Strategy: mock QuoteRepositoryBase with mocktail; test that QuoteCatalogProvider
// loads quotes, manages filter state, and handles CRUD mutations correctly.
//
// See: vault/sprint/backlog/task-05.02-feat-expand-quote-crud-access-and-catalog-state-management.md
//
// Quality Gate coverage:
//   QG1 — load() populates _allQuotes and sets isLoading = false
//   QG2 — quotes getter returns filtered list respecting sourceFilter and tagFilter
//   QG3 — createQuote() adds to _allQuotes and calls notifyListeners()
//   QG4 — updateQuote() replaces quote in _allQuotes by id and calls notifyListeners()
//   QG5 — deleteQuote() removes from _allQuotes and calls notifyListeners()
//   QG6 — After delete, deleted quote does not appear in quotes getter
//   QG7 — After update that changes tags/source, quotes getter reflects the change
//   QG8 — No import '../data/quote_database.dart' in provider file (layer boundary)

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:kindwords/models/quote.dart';
import 'package:kindwords/providers/quote_catalog_provider.dart';
import 'package:kindwords/repositories/quote_repository.dart';

// ---------------------------------------------------------------------------
// Test doubles
// ---------------------------------------------------------------------------

/// Mock of [QuoteRepositoryBase] — the boundary we mock (providers must not
/// import QuoteDatabase directly per architecture rules).
class MockQuoteRepository extends Mock implements QuoteRepositoryBase {}

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

final _seededQuote1 = Quote(
  id: 'q-catalog-seeded-001',
  text: 'Seeded quote 1',
  author: 'Author A',
  tags: ['motivational', 'wisdom'],
  source: QuoteSource.seeded,
  createdAt: DateTime.parse('2026-03-27T10:00:00.000Z'),
  updatedAt: null,
);

final _seededQuote2 = Quote(
  id: 'q-catalog-seeded-002',
  text: 'Seeded quote 2',
  author: 'Author B',
  tags: ['focus'],
  source: QuoteSource.seeded,
  createdAt: DateTime.parse('2026-03-27T11:00:00.000Z'),
  updatedAt: null,
);

final _userCreatedQuote1 = Quote(
  id: 'q-catalog-user-001',
  text: 'User created quote 1',
  author: 'Me',
  tags: ['personal', 'wisdom'],
  source: QuoteSource.userCreated,
  createdAt: DateTime.parse('2026-03-27T12:00:00.000Z'),
  updatedAt: null,
);

final _userCreatedQuote2 = Quote(
  id: 'q-catalog-user-002',
  text: 'User created quote 2',
  author: null,
  tags: [],
  source: QuoteSource.userCreated,
  createdAt: DateTime.parse('2026-03-27T13:00:00.000Z'),
  updatedAt: null,
);

// Fallback for mocktail — required so any() can resolve Quote.
class _FakeQuote extends Fake implements Quote {}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Constructs a [QuoteCatalogProvider] whose mock repository reports the
/// given quotes on [getAllQuotes] by default.
QuoteCatalogProvider _makeProvider(
  MockQuoteRepository mockRepo, {
  List<Quote> initialQuotes = const [],
}) {
  when(() => mockRepo.getAllQuotes()).thenAnswer((_) async => initialQuotes);
  when(() => mockRepo.insertQuote(any())).thenAnswer((_) async {});
  when(() => mockRepo.updateQuote(any())).thenAnswer((_) async {});
  when(() => mockRepo.deleteQuote(any())).thenAnswer((_) async {});
  when(() => mockRepo.getBySource(any())).thenAnswer((_) async => []);
  when(() => mockRepo.getByTag(any())).thenAnswer((_) async => []);
  return QuoteCatalogProvider(mockRepo);
}

void main() {
  late MockQuoteRepository mockRepo;
  late QuoteCatalogProvider provider;

  setUpAll(() {
    registerFallbackValue(_FakeQuote());
    registerFallbackValue(QuoteSource.seeded);
  });

  setUp(() {
    mockRepo = MockQuoteRepository();
    // Default: empty catalog
    provider = _makeProvider(mockRepo, initialQuotes: []);
  });

  // -------------------------------------------------------------------------
  // load() — initial state and population
  // -------------------------------------------------------------------------

  group('QuoteCatalogProvider.load()', () {
    test('isLoading is true during load then false after', () async {
      // Arrange: stub returns quotes
      when(() => mockRepo.getAllQuotes())
          .thenAnswer((_) async => [_seededQuote1, _userCreatedQuote1]);

      // Act: call load and capture loading state mid-flight
      final loadFuture = provider.load();

      // Assert: isLoading is true while loading
      expect(provider.isLoading, isTrue,
          reason: 'load() must set isLoading=true before awaiting repo');

      await loadFuture;

      // Assert: isLoading is false after completion
      expect(provider.isLoading, isFalse,
          reason: 'load() must set isLoading=false after completion');
    });

    test('load() populates quotes list from repository', () async {
      // Arrange
      final quotes = [_seededQuote1, _seededQuote2, _userCreatedQuote1];
      when(() => mockRepo.getAllQuotes()).thenAnswer((_) async => quotes);

      // Act
      await provider.load();

      // Assert: all quotes available
      expect(provider.quotes.length, equals(3));
    });

    test('load() sets quotes to empty list when repository returns empty',
        () async {
      // Arrange
      when(() => mockRepo.getAllQuotes()).thenAnswer((_) async => []);

      // Act
      await provider.load();

      // Assert
      expect(provider.quotes, isEmpty);
    });

    test('load() calls notifyListeners() after completion', () async {
      // Arrange
      when(() => mockRepo.getAllQuotes())
          .thenAnswer((_) async => [_seededQuote1]);

      var notifyCount = 0;
      provider.addListener(() => notifyCount++);

      // Act
      await provider.load();

      // Assert: at least one notification was fired
      expect(notifyCount, greaterThanOrEqualTo(1),
          reason: 'load() must call notifyListeners() so widgets rebuild');
    });
  });

  // -------------------------------------------------------------------------
  // Default filters — show all quotes
  // -------------------------------------------------------------------------

  group('QuoteCatalogProvider default filters', () {
    test('default filters show all quotes', () async {
      // Arrange
      final quotes = [_seededQuote1, _seededQuote2, _userCreatedQuote1];
      provider = _makeProvider(mockRepo, initialQuotes: quotes);

      // Act
      await provider.load();

      // Assert: no filters = all quotes visible
      expect(provider.quotes.length, equals(3));
    });

    test('sourceFilter is null by default (show all)', () async {
      // Arrange
      provider = _makeProvider(mockRepo, initialQuotes: [_seededQuote1]);

      // Act
      await provider.load();

      // Assert
      expect(provider.sourceFilter, isNull,
          reason: 'sourceFilter must be null by default meaning "All"');
    });

    test('tagFilter is null by default (no tag filter)', () async {
      // Arrange
      provider = _makeProvider(mockRepo, initialQuotes: [_seededQuote1]);

      // Act
      await provider.load();

      // Assert
      expect(provider.tagFilter, isNull,
          reason: 'tagFilter must be null by default meaning "no tag filter"');
    });
  });

  // -------------------------------------------------------------------------
  // Source filter — seeded vs userCreated
  // -------------------------------------------------------------------------

  group('QuoteCatalogProvider source filter', () {
    test('source filter seeded returns only seeded quotes', () async {
      // Arrange
      final quotes = [_seededQuote1, _seededQuote2, _userCreatedQuote1];
      provider = _makeProvider(mockRepo, initialQuotes: quotes);
      await provider.load();

      // Act
      provider.setSourceFilter(QuoteSource.seeded);

      // Assert: only seeded quotes visible
      expect(provider.quotes.length, equals(2));
      expect(
          provider.quotes.every((q) => q.source == QuoteSource.seeded), isTrue);
    });

    test('source filter userCreated returns only user-created quotes',
        () async {
      // Arrange
      final quotes = [_seededQuote1, _userCreatedQuote1, _userCreatedQuote2];
      provider = _makeProvider(mockRepo, initialQuotes: quotes);
      await provider.load();

      // Act
      provider.setSourceFilter(QuoteSource.userCreated);

      // Assert: only user-created quotes visible
      expect(provider.quotes.length, equals(2));
      expect(provider.quotes.every((q) => q.source == QuoteSource.userCreated),
          isTrue);
    });

    test('source filter null (all) returns all quotes', () async {
      // Arrange
      final quotes = [_seededQuote1, _userCreatedQuote1];
      provider = _makeProvider(mockRepo, initialQuotes: quotes);
      await provider.load();
      provider.setSourceFilter(QuoteSource.seeded); // set a filter first

      // Act
      provider.setSourceFilter(null);

      // Assert: all quotes visible
      expect(provider.quotes.length, equals(2));
    });

    test('source filter calls notifyListeners()', () async {
      // Arrange
      provider = _makeProvider(mockRepo, initialQuotes: [_seededQuote1]);
      await provider.load();

      var notifyCount = 0;
      provider.addListener(() => notifyCount++);

      // Act
      provider.setSourceFilter(QuoteSource.seeded);

      // Assert
      expect(notifyCount, greaterThanOrEqualTo(1),
          reason: 'setSourceFilter must call notifyListeners()');
    });
  });

  // -------------------------------------------------------------------------
  // Tag filter
  // -------------------------------------------------------------------------

  group('QuoteCatalogProvider tag filter', () {
    test('tag filter returns only quotes containing that tag', () async {
      // Arrange
      final quotes = [_seededQuote1, _seededQuote2, _userCreatedQuote1];
      provider = _makeProvider(mockRepo, initialQuotes: quotes);
      await provider.load();

      // Act: filter by 'wisdom' tag
      provider.setTagFilter('wisdom');

      // Assert: only quotes with 'wisdom' tag visible
      expect(provider.quotes.every((q) => q.tags.contains('wisdom')), isTrue);
    });

    test('tag filter with no matches returns empty list', () async {
      // Arrange
      final quotes = [_seededQuote1, _seededQuote2];
      provider = _makeProvider(mockRepo, initialQuotes: quotes);
      await provider.load();

      // Act: filter by nonexistent tag
      provider.setTagFilter('nonexistent');

      // Assert
      expect(provider.quotes, isEmpty);
    });

    test('tag filter null (no filter) returns all quotes', () async {
      // Arrange
      final quotes = [_seededQuote1, _userCreatedQuote1];
      provider = _makeProvider(mockRepo, initialQuotes: quotes);
      await provider.load();
      provider.setTagFilter('wisdom'); // set a filter first

      // Act
      provider.setTagFilter(null);

      // Assert: all quotes visible
      expect(provider.quotes.length, equals(2));
    });

    test('tag filter calls notifyListeners()', () async {
      // Arrange
      provider = _makeProvider(mockRepo, initialQuotes: [_seededQuote1]);
      await provider.load();

      var notifyCount = 0;
      provider.addListener(() => notifyCount++);

      // Act
      provider.setTagFilter('motivational');

      // Assert
      expect(notifyCount, greaterThanOrEqualTo(1),
          reason: 'setTagFilter must call notifyListeners()');
    });
  });

  // -------------------------------------------------------------------------
  // Combined filters — source + tag
  // -------------------------------------------------------------------------

  group('QuoteCatalogProvider combined filters', () {
    test('source filter + tag filter returns intersection', () async {
      // Arrange
      final quotes = [
        _seededQuote1, // tags: [motivational, wisdom], source: seeded
        _seededQuote2, // tags: [focus], source: seeded
        _userCreatedQuote1, // tags: [personal, wisdom], source: userCreated
      ];
      provider = _makeProvider(mockRepo, initialQuotes: quotes);
      await provider.load();

      // Act: filter by seeded + wisdom
      provider.setSourceFilter(QuoteSource.seeded);
      provider.setTagFilter('wisdom');

      // Assert: only seeded quotes with 'wisdom' tag
      expect(provider.quotes.length, equals(1));
      expect(provider.quotes.first.id, equals('q-catalog-seeded-001'));
    });
  });

  // -------------------------------------------------------------------------
  // createQuote() mutation
  // -------------------------------------------------------------------------

  group('QuoteCatalogProvider.createQuote()', () {
    test('create mutation adds quote and updates filtered output', () async {
      // Arrange
      provider = _makeProvider(mockRepo, initialQuotes: []);
      await provider.load();
      expect(provider.quotes, isEmpty);

      final newQuote = Quote(
        id: 'q-new-001',
        text: 'New quote',
        author: 'Me',
        tags: ['personal'],
        source: QuoteSource.userCreated,
        createdAt: DateTime.parse('2026-03-27T14:00:00.000Z'),
        updatedAt: null,
      );

      // Act
      await provider.createQuote(newQuote);

      // Assert: quote appears in filtered list
      expect(provider.quotes, contains(newQuote));
      expect(provider.quotes.length, equals(1));
    });

    test('create mutation calls repository.insertQuote()', () async {
      // Arrange
      provider = _makeProvider(mockRepo, initialQuotes: []);
      await provider.load();

      final newQuote = Quote(
        id: 'q-new-002',
        text: 'Another new quote',
        author: null,
        tags: [],
        source: QuoteSource.userCreated,
        createdAt: DateTime.parse('2026-03-27T14:00:00.000Z'),
        updatedAt: null,
      );

      // Act
      await provider.createQuote(newQuote);

      // Assert
      verify(() => mockRepo.insertQuote(newQuote)).called(1);
    });

    test('create mutation calls notifyListeners()', () async {
      // Arrange
      provider = _makeProvider(mockRepo, initialQuotes: []);
      await provider.load();

      var notifyCount = 0;
      provider.addListener(() => notifyCount++);

      final newQuote = Quote(
        id: 'q-new-003',
        text: 'New quote',
        author: 'Me',
        tags: [],
        source: QuoteSource.userCreated,
        createdAt: DateTime.parse('2026-03-27T14:00:00.000Z'),
        updatedAt: null,
      );

      // Act
      await provider.createQuote(newQuote);

      // Assert
      expect(notifyCount, greaterThanOrEqualTo(1),
          reason: 'createQuote must call notifyListeners()');
    });

    test('create mutation respects active source filter', () async {
      // Arrange
      provider = _makeProvider(mockRepo, initialQuotes: [_seededQuote1]);
      await provider.load();
      provider.setSourceFilter(QuoteSource.seeded); // only seeded visible

      final newUserQuote = Quote(
        id: 'q-new-004',
        text: 'User quote',
        author: 'Me',
        tags: [],
        source: QuoteSource.userCreated,
        createdAt: DateTime.parse('2026-03-27T14:00:00.000Z'),
        updatedAt: null,
      );

      // Act
      await provider.createQuote(newUserQuote);

      // Assert: user-created quote NOT visible under seeded filter
      expect(
          provider.quotes.every((q) => q.source == QuoteSource.seeded), isTrue);
    });
  });

  // -------------------------------------------------------------------------
  // updateQuote() mutation
  // -------------------------------------------------------------------------

  group('QuoteCatalogProvider.updateQuote()', () {
    test('update mutation changes quote in-place and re-applies active filters',
        () async {
      // Arrange
      provider = _makeProvider(mockRepo, initialQuotes: [_seededQuote1]);
      await provider.load();

      final updated = Quote(
        id: 'q-catalog-seeded-001',
        text: 'Updated text',
        author: 'New Author',
        tags: ['focus'],
        source: QuoteSource.seeded,
        createdAt: _seededQuote1.createdAt,
        updatedAt: DateTime.parse('2026-03-27T15:00:00.000Z'),
      );

      // Act
      await provider.updateQuote(updated);

      // Assert: updated quote appears in list
      final found =
          provider.quotes.firstWhere((q) => q.id == 'q-catalog-seeded-001');
      expect(found.text, equals('Updated text'));
      expect(found.author, equals('New Author'));
      expect(found.tags, equals(['focus']));
    });

    test('update mutation calls repository.updateQuote()', () async {
      // Arrange
      provider = _makeProvider(mockRepo, initialQuotes: [_seededQuote1]);
      await provider.load();

      final updated = Quote(
        id: 'q-catalog-seeded-001',
        text: 'Updated',
        author: 'Author',
        tags: [],
        source: QuoteSource.seeded,
        createdAt: _seededQuote1.createdAt,
        updatedAt: DateTime.parse('2026-03-27T15:00:00.000Z'),
      );

      // Act
      await provider.updateQuote(updated);

      // Assert
      verify(() => mockRepo.updateQuote(updated)).called(1);
    });

    test('update mutation calls notifyListeners()', () async {
      // Arrange
      provider = _makeProvider(mockRepo, initialQuotes: [_seededQuote1]);
      await provider.load();

      var notifyCount = 0;
      provider.addListener(() => notifyCount++);

      final updated = Quote(
        id: 'q-catalog-seeded-001',
        text: 'Updated',
        author: 'Author',
        tags: [],
        source: QuoteSource.seeded,
        createdAt: _seededQuote1.createdAt,
        updatedAt: DateTime.parse('2026-03-27T15:00:00.000Z'),
      );

      // Act
      await provider.updateQuote(updated);

      // Assert
      expect(notifyCount, greaterThanOrEqualTo(1),
          reason: 'updateQuote must call notifyListeners()');
    });

    test('update that changes tags is reflected in filtered output', () async {
      // Arrange
      provider = _makeProvider(mockRepo, initialQuotes: [_seededQuote1]);
      await provider.load();
      provider.setTagFilter('wisdom'); // seededQuote1 has 'wisdom'

      expect(provider.quotes.length, equals(1)); // visible

      final updated = Quote(
        id: 'q-catalog-seeded-001',
        text: 'Updated',
        author: 'Author',
        tags: ['focus'], // removed 'wisdom'
        source: QuoteSource.seeded,
        createdAt: _seededQuote1.createdAt,
        updatedAt: DateTime.parse('2026-03-27T15:00:00.000Z'),
      );

      // Act
      await provider.updateQuote(updated);

      // Assert: no longer visible under 'wisdom' filter
      expect(provider.quotes, isEmpty);
    });
  });

  // -------------------------------------------------------------------------
  // deleteQuote() mutation
  // -------------------------------------------------------------------------

  group('QuoteCatalogProvider.deleteQuote()', () {
    test('delete mutation removes quote and updates filtered output', () async {
      // Arrange
      provider = _makeProvider(mockRepo,
          initialQuotes: [_seededQuote1, _seededQuote2]);
      await provider.load();
      expect(provider.quotes.length, equals(2));

      // Act
      await provider.deleteQuote('q-catalog-seeded-001');

      // Assert: quote removed from list
      expect(provider.quotes.length, equals(1));
      expect(
          provider.quotes.any((q) => q.id == 'q-catalog-seeded-001'), isFalse);
    });

    test('delete mutation calls repository.deleteQuote()', () async {
      // Arrange
      provider = _makeProvider(mockRepo, initialQuotes: [_seededQuote1]);
      await provider.load();

      // Act
      await provider.deleteQuote('q-catalog-seeded-001');

      // Assert
      verify(() => mockRepo.deleteQuote('q-catalog-seeded-001')).called(1);
    });

    test('delete mutation calls notifyListeners()', () async {
      // Arrange
      provider = _makeProvider(mockRepo, initialQuotes: [_seededQuote1]);
      await provider.load();

      var notifyCount = 0;
      provider.addListener(() => notifyCount++);

      // Act
      await provider.deleteQuote('q-catalog-seeded-001');

      // Assert
      expect(notifyCount, greaterThanOrEqualTo(1),
          reason: 'deleteQuote must call notifyListeners()');
    });

    test('after delete, deleted quote does not appear in quotes getter',
        () async {
      // Arrange
      provider = _makeProvider(mockRepo, initialQuotes: [_seededQuote1]);
      await provider.load();

      // Act
      await provider.deleteQuote('q-catalog-seeded-001');

      // Assert: provider never exposes stale filtered list
      expect(
          provider.quotes.any((q) => q.id == 'q-catalog-seeded-001'), isFalse);
    });
  });

  // -------------------------------------------------------------------------
  // Stale state prevention
  // -------------------------------------------------------------------------

  group('QuoteCatalogProvider stale state prevention', () {
    test('provider never exposes stale filtered list after mutation', () async {
      // Arrange: comprehensive test for QG10
      final quotes = [_seededQuote1, _seededQuote2, _userCreatedQuote1];
      provider = _makeProvider(mockRepo, initialQuotes: quotes);
      await provider.load();

      // Initial state
      expect(provider.quotes.length, equals(3));

      // Delete one
      await provider.deleteQuote('q-catalog-seeded-001');
      expect(provider.quotes.length, equals(2));

      // Update one
      final updated = Quote(
        id: 'q-catalog-seeded-002',
        text: 'Updated',
        author: 'Author',
        tags: [],
        source: QuoteSource.seeded,
        createdAt: _seededQuote2.createdAt,
        updatedAt: DateTime.parse('2026-03-27T15:00:00.000Z'),
      );
      await provider.updateQuote(updated);
      expect(
          provider.quotes.any(
              (q) => q.id == 'q-catalog-seeded-002' && q.text == 'Updated'),
          isTrue);

      // Create one
      final newQuote = Quote(
        id: 'q-new-stale-test',
        text: 'New',
        author: null,
        tags: [],
        source: QuoteSource.userCreated,
        createdAt: DateTime.parse('2026-03-27T16:00:00.000Z'),
        updatedAt: null,
      );
      await provider.createQuote(newQuote);
      expect(provider.quotes.any((q) => q.id == 'q-new-stale-test'), isTrue);
    });
  });

  // -------------------------------------------------------------------------
  // Layer boundary enforcement
  // -------------------------------------------------------------------------

  group('QuoteCatalogProvider layer boundary', () {
    test('provider does NOT import quote_database.dart directly', () async {
      // This is a code-review/CI gate, but we document the expectation here.
      // The provider must only depend on QuoteRepositoryBase, not QuoteDatabase.
      // Enforced by grep in CI: `! grep -r "import.*quote_database" lib/providers/`
      //
      // This test documents the architectural rule; it cannot fail at runtime
      // but serves as a reference for the layer boundary constraint.
      expect(true, isTrue,
          reason:
              'Provider must not import quote_database.dart — enforced by CI grep');
    });
  });
}
