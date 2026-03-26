// ignore_for_file: require_trailing_commas
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:kindwords/models/quote.dart';
import 'package:kindwords/providers/quote_provider.dart';
import 'package:kindwords/services/quote_service.dart';

// ---------------------------------------------------------------------------
// Test doubles
// ---------------------------------------------------------------------------

/// Minimal mock of [QuoteService] — mocks the *new async interface* that R5
/// will introduce. No [QuoteRepositoryBase] import needed here; we mock at
/// the service boundary.
///
/// The current [QuoteService] has no constructor that accepts a repository, so
/// this class references the post-migration interface. This causes a compile
/// error (or behavioural failure) until R5 is implemented.
class MockQuoteService extends Mock implements QuoteService {}

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

const _quoteA = Quote(id: 'qa', text: 'Quote A', author: 'Author A');
const _quoteB = Quote(id: 'qb', text: 'Quote B', author: null);

void main() {
  late MockQuoteService mockService;

  setUp(() {
    mockService = MockQuoteService();
    // Default stub: _initialize() fires in the constructor and calls
    // getRandomQuote(); stub a sensible default so the provider doesn't throw
    // during construction in tests that only care about refreshQuote().
    when(() => mockService.getRandomQuote(currentId: any(named: 'currentId')))
        .thenAnswer((_) async => _quoteA);
    when(() => mockService.getRandomQuote())
        .thenAnswer((_) async => _quoteA);
  });

  // -------------------------------------------------------------------------
  // Initial state
  // -------------------------------------------------------------------------

  group('QuoteProvider — initial state', () {
    test('isLoading starts as false synchronously after construction', () {
      // The constructor fires async _initialize() as fire-and-forget.
      // isLoading must NOT be set to true synchronously in the constructor body
      // because that would cause a spurious loading flash on the first frame.
      //
      // New contract: QuoteProvider(QuoteService service).
      // This line fails to compile until the coder adds QuoteService injection
      // to QuoteProvider (R5).
      final provider = QuoteProvider(mockService);

      // Assert: synchronously false immediately after construction
      expect(provider.isLoading, isFalse,
          reason:
              'isLoading must be false synchronously — constructor must not '
              'set isLoading=true before the async _initialize() completes');
    });

    test('currentQuote is null before async initialization completes', () {
      // Do NOT await any futures here — we are inspecting the synchronous
      // snapshot right after construction.
      final provider = QuoteProvider(mockService);

      // In the new contract currentQuote is nullable (Quote?).
      // Before _initialize() completes, currentQuote is null.
      expect(provider.currentQuote, isNull,
          reason:
              'currentQuote must be null until the async _initialize() resolves '
              'so that the UI can show a loading state instead of stale data');
    });
  });

  // -------------------------------------------------------------------------
  // refreshQuote()
  // -------------------------------------------------------------------------

  group('QuoteProvider.refreshQuote()', () {
    test('isLoading is true during refresh then false after', () async {
      // Arrange: use a Completer to pause the service call mid-flight so we
      // can observe isLoading = true before the future resolves.
      final completer = Completer<Quote>();
      when(() => mockService.getRandomQuote(currentId: any(named: 'currentId')))
          .thenAnswer((_) => completer.future);
      when(() => mockService.getRandomQuote())
          .thenAnswer((_) => completer.future);

      // Let constructor's _initialize() settle with the default stub
      // (it will hang on completer — that's fine; we reset below)
      final provider = QuoteProvider(mockService);

      // Re-stub to use a new completer for the refreshQuote() call
      final refreshCompleter = Completer<Quote>();
      when(() => mockService.getRandomQuote(currentId: any(named: 'currentId')))
          .thenAnswer((_) => refreshCompleter.future);
      when(() => mockService.getRandomQuote())
          .thenAnswer((_) => refreshCompleter.future);

      // Collect isLoading state changes via listener
      final loadingStates = <bool>[];
      provider.addListener(() => loadingStates.add(provider.isLoading));

      // Act: start refresh but don't complete the future yet
      final refreshFuture = provider.refreshQuote();

      // Mid-flight: isLoading must be true (notifyListeners() called with true)
      expect(loadingStates, contains(true),
          reason:
              'refreshQuote() must set isLoading=true and notifyListeners() '
              'before awaiting the service call');

      // Now complete the service future
      refreshCompleter.complete(_quoteB);
      await refreshFuture;

      // After: isLoading must be false
      expect(provider.isLoading, isFalse,
          reason: 'isLoading must be false after refreshQuote() completes');
    });

    test('refreshQuote() updates currentQuote to the value returned by service',
        () async {
      // Arrange: let constructor initialize
      final provider = QuoteProvider(mockService);
      await Future<void>.microtask(() {}); // let _initialize() settle

      // Stub refresh to return _quoteB
      when(() => mockService.getRandomQuote(currentId: any(named: 'currentId')))
          .thenAnswer((_) async => _quoteB);
      when(() => mockService.getRandomQuote())
          .thenAnswer((_) async => _quoteB);

      // Act
      await provider.refreshQuote();

      // Assert
      expect(provider.currentQuote, equals(_quoteB),
          reason:
              'currentQuote must be updated to the Quote returned by service '
              'after refreshQuote() completes');
    });

    test('refreshQuote() calls notifyListeners() after completion', () async {
      // Arrange
      final provider = QuoteProvider(mockService);
      await Future<void>.microtask(() {});

      when(() => mockService.getRandomQuote(currentId: any(named: 'currentId')))
          .thenAnswer((_) async => _quoteB);
      when(() => mockService.getRandomQuote())
          .thenAnswer((_) async => _quoteB);

      var notifyCount = 0;
      provider.addListener(() => notifyCount++);

      // Act
      await provider.refreshQuote();

      // Assert: at minimum one notification was fired (for isLoading=false /
      // currentQuote update at the end of refreshQuote)
      expect(notifyCount, greaterThanOrEqualTo(1),
          reason:
              'refreshQuote() must call notifyListeners() so widgets rebuild '
              'after the new quote is available');
    });
  });
}
