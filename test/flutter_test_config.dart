import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:kindwords/models/quote.dart';

/// Shared test configuration for all KindWords test files.
///
/// Flutter test framework scans up the directory hierarchy starting from
/// each test file's location and applies the first [flutter_test_config.dart]
/// it finds. This file covers all tests under `test/`.
///
/// Purpose: register mocktail fallback values for custom types used with
/// [any] or [captureAny] argument matchers. [registerFallbackValue] must
/// be called once per type before any mock uses [any] on that type.
///
/// Types registered here:
/// - [Quote] — used in CRUD method stubs (insertQuote, updateQuote)
/// - [QuoteSource] — used in getBySource stubs

/// Fake implementations required by mocktail for [registerFallbackValue].
/// Fakes use [Fake] (not [Mock]) to avoid recursive mock issues.
class _FakeQuote extends Fake implements Quote {}

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  setUpAll(() {
    registerFallbackValue(_FakeQuote());
    registerFallbackValue(QuoteSource.seeded);
  });

  await testMain();
}
