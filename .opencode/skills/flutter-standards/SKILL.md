# Skill: flutter-standards[sdlc-flutter-coder,sdlc-flutter-tech-lead]

> Project-local Flutter skill for KindWords.
> Loaded by `sdlc-flutter-coder` and `sdlc-flutter-tech-lead` agents at session start.
> Source of truth for all Flutter/Dart architectural and implementation decisions on this project.

---

## Stack Snapshot

| Layer | Package | Version | Notes |
|-------|---------|---------|-------|
| UI | Flutter (Dart) | 3.x | Material 3 |
| State | provider | ^6.1.2 | ChangeNotifier pattern |
| Local DB | sqflite | ^2.3.x | SQLite via DAL + Repository |
| DB path | path | ^1.9.x | `getDatabasesPath()` + `join()` |
| Notifications | flutter_local_notifications | ^17.0.0 | Exact alarm, daily repeat |
| Timezone | timezone | ^0.9.4 | Required by notifications |
| Preferences | shared_preferences | ^2.3.2 | Favorites IDs + settings |

**Runtime target:** Android API 31+ (Android 12+). Min SDK: API 21.

---

## 1. Project Structure

**Rule:** Use a hybrid layer-first structure matched to the current app scale. The `lib/` layout is:

```
lib/
  main.dart                     # Entry: bootstrapApp(), runApp()
  bootstrap/
    app_bootstrap.dart          # Async init: DB open → seed → service graph → MultiProvider
  models/
    quote.dart                  # Immutable data model; no business logic
  data/
    quotes_data.dart            # Seed-only constant list (kAllQuotes) — NOT runtime source
    quote_database.dart         # SQLite DAL: open, onCreate, seedIfEmpty, getAllQuotes
  repositories/
    quote_repository.dart       # QuoteRepositoryBase (abstract) + LocalQuoteRepository
  services/
    quote_service.dart          # Random selection logic; depends on QuoteRepositoryBase
    favorites_service.dart      # shared_preferences CRUD for favorite IDs
    notification_service.dart   # flutter_local_notifications scheduling
  providers/
    quote_provider.dart         # ChangeNotifier: currentQuote, isLoading, refreshQuote()
    favorites_provider.dart     # ChangeNotifier: favorites list, add/remove
  screens/
    home_screen.dart
    favorites_screen.dart
    settings_screen.dart
  widgets/                      # Shared extracted widgets
```

**Do:** Keep screens thin — no business logic, only UI wiring to providers.
**Avoid:** Importing `quote_database.dart` directly from providers or screens — it must go through the repository.
**Avoid:** Layer-first explosion (`lib/models/`, `lib/views/`, `lib/controllers/` sprawl) — for a 3-feature app this is fine; the current structure is intentional and correct.

---

## 2. State Management (Provider)

### ChangeNotifier Rules

**Do:** Use `ChangeNotifierProvider(create: (_) => MyNotifier(), ...)` — Provider manages lifecycle and calls `dispose()`.
**Avoid:** `ChangeNotifierProvider.value(value: MyNotifier(), ...)` with a freshly created instance — it leaks because nobody disposes it.

```dart
// ✅ Provider manages lifecycle
MultiProvider(
  providers: [
    ChangeNotifierProvider(create: (_) => QuoteProvider(quoteService)),
    ChangeNotifierProvider(create: (_) => FavoritesProvider(favoritesService)),
  ],
  child: MyApp(),
)
```

### Reading Context

| Pattern | Where to use | Why |
|---------|-------------|-----|
| `context.watch<T>()` | Inside `build()` | Rebuilds widget on change |
| `context.read<T>()` | Inside callbacks, `initState`, button handlers | No rebuild, one-time read |
| `Consumer<T>` / `Selector<T,R>` | When only subtree needs rebuild | Minimizes rebuild scope |

**Do:** Use `context.read<T>()` inside `onPressed` and `initState`.
**Avoid:** Calling `context.watch<T>()` inside callbacks — it subscribes unnecessarily and causes spurious rebuilds.

### Loading State Pattern

`QuoteProvider` must expose `isLoading` when using async repository. Pattern:

```dart
class QuoteProvider extends ChangeNotifier {
  Quote? _currentQuote;
  bool _isLoading = false;

  Quote? get currentQuote => _currentQuote;
  bool get isLoading => _isLoading;

  Future<void> refreshQuote() async {
    _isLoading = true;
    notifyListeners();
    _currentQuote = await _quoteService.getRandomQuote();
    _isLoading = false;
    notifyListeners();
  }
}
```

**Do:** Initialize `isLoading = false` and call `notifyListeners()` twice: once to show loading, once to hide it.
**Avoid:** Calling async operations in the ChangeNotifier constructor — use `_initialize()` as a fire-and-forget from the constructor body and call `notifyListeners()` on completion.

---

## 3. Data Layer / Repository Pattern

### Repository Interface

```dart
// lib/repositories/quote_repository.dart
abstract class QuoteRepositoryBase {
  Future<List<Quote>> getAllQuotes();
  Future<Quote?> getById(String id);
}

class LocalQuoteRepository implements QuoteRepositoryBase {
  final QuoteDatabase _db;
  LocalQuoteRepository(this._db);

  @override
  Future<List<Quote>> getAllQuotes() => _db.getAllQuotes();

  @override
  Future<Quote?> getById(String id) => _db.getById(id);
}
```

**Do:** Keep `QuoteRepositoryBase` lean — only `getAllQuotes()` and `getById()`. Random selection belongs in `QuoteService`, not the repository.
**Avoid:** Adding `getRandomQuote()` to the repository base — random selection is presentation/domain behavior, not a persistence contract. Adding it blocks the future `RemoteQuoteRepository` from implementing an interface it cannot fulfill correctly.
**Avoid:** `IQuoteRepository` naming (Java-ism) — Dart convention is `QuoteRepositoryBase` or `QuoteRepository` (abstract).

### sqflite DAL Rules

```dart
// lib/data/quote_database.dart
class QuoteDatabase {
  Database? _db;

  Future<void> open() async {
    final path = join(await getDatabasesPath(), 'kindwords.db');
    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE quotes (
            id TEXT PRIMARY KEY,
            text TEXT NOT NULL,
            author TEXT
          )
        ''');
      },
    );
  }

  Future<void> seedIfEmpty(List<Quote> quotes) async {
    final count = Sqflite.firstIntValue(
      await _db!.rawQuery('SELECT COUNT(*) FROM quotes')
    ) ?? 0;
    if (count > 0) return; // idempotent guard

    final batch = _db!.batch();
    for (final q in quotes) {
      batch.insert('quotes', q.toMap(),
          conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    await batch.commit(noResult: true);
  }
}
```

**Do:** Use `ConflictAlgorithm.ignore` in the seed batch — idempotent, never overwrites.
**Avoid:** `ConflictAlgorithm.replace` in seeds — silently replaces existing rows, defeats idempotency guarantee.
**Do:** Use `batch.commit(noResult: true)` — skips allocating 100+ result objects.
**Avoid:** Looping individual `db.insert()` calls — measurably slower; single batch transaction is correct.

**Do:** Use `getDatabasesPath()` (sqflite) + `path.join()` for path resolution.
**Avoid:** `getApplicationDocumentsDirectory()` from `path_provider` — wrong backup location and unnecessary dependency.

### Nullable author column

```dart
// ✅ Correct cast
author: row['author'] as String?,

// ❌ Crashes on anonymous quotes
author: row['author'] as String,
```

### Bootstrap Ordering (non-negotiable)

```dart
// lib/bootstrap/app_bootstrap.dart
Future<void> bootstrapApp() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 1. Open database
  final db = QuoteDatabase();
  await db.open();
  // 2. Seed quotes — must complete before any service reads
  await db.seedIfEmpty(kAllQuotes);
  // 3. Construct repository + services
  final quoteRepo = LocalQuoteRepository(db);
  final quoteService = QuoteService(quoteRepo);
  // 4. Other services...
  runApp(MyApp(quoteService: quoteService, ...));
}
```

**Do:** `open()` and `seedIfEmpty()` must complete before any provider or service construction.
**Avoid:** Lazy DB init in a provider constructor or `initState` — creates a race condition with first-frame rendering where `getRandomQuote()` fires before seed completes.

---

## 4. Widget Architecture

### Widget vs Helper Method

**Do:** Extract reusable UI into a `StatelessWidget` with a `const` constructor.
**Avoid:** Widget-returning helper methods (`Widget _buildCard(...)`) — they break Flutter's const optimization and tree diffing.

```dart
// ✅ Extractable, const-eligible, diffable
class QuoteCard extends StatelessWidget {
  final Quote quote;
  const QuoteCard({super.key, required this.quote});

  @override
  Widget build(BuildContext context) => Card(child: Text(quote.text));
}

// ❌ Anti-pattern
Widget _buildQuoteCard(Quote quote) => Card(child: Text(quote.text));
```

### When to Use StatefulWidget

Use `StatefulWidget` when the widget owns local mutable state:
- Text field controllers (`TextEditingController`)
- Animation controllers
- Local UI toggle state (expanded/collapsed, not shared)

**Do NOT use** `StatefulWidget` just to call an async method — use `FutureBuilder` or move logic to the provider.

### Key Usage

**Do:** Pass `key: UniqueKey()` when forcing widget identity to reset (e.g., re-animating a card).
**Avoid:** `UniqueKey()` on every build — it forces full rebuild on every frame.

---

## 5. Async Handling

### Never Create Futures Inside `build()`

```dart
// ✅ Future stored once in initState
late final Future<List<Quote>> _quotesFuture;

@override
void initState() {
  super.initState();
  _quotesFuture = _repo.getAllQuotes();
}

@override
Widget build(BuildContext context) {
  return FutureBuilder(future: _quotesFuture, builder: ...);
}

// ❌ New Future on every rebuild
FutureBuilder(future: _repo.getAllQuotes(), ...)
```

### `initState` is Synchronous

```dart
// ✅ Correct async pattern for initState
@override
void initState() {
  super.initState();
  _initialize(); // fire-and-forget
}

Future<void> _initialize() async {
  final data = await _repo.getAllQuotes();
  if (!mounted) return; // ALWAYS check mounted after async gap
  setState(() => _data = data);
}
```

**Do:** Always check `if (!mounted) return;` after every `await` that will call `setState`.
**Avoid:** `async initState()` — it compiles but violates Flutter's lifecycle contract and silently swallows exceptions.

### FutureBuilder State Handling

Always handle all three states:
```dart
FutureBuilder<Quote>(
  future: _quoteFuture,
  builder: (context, snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const CircularProgressIndicator();
    }
    if (snapshot.hasError) {
      return Text('Error: ${snapshot.error}');
    }
    if (!snapshot.hasData) {
      return const Text('No quote available');
    }
    return QuoteCard(quote: snapshot.data!);
  },
)
```

---

## 6. Testing

### Test Structure

Mirror `lib/` inside `test/`:
```
test/
  data/
    quote_database_test.dart
  repositories/
    quote_repository_test.dart
  services/
    quote_service_test.dart
    favorites_service_test.dart
  providers/
    quote_provider_test.dart
  widgets/
    quote_card_test.dart
```

### Unit Test Pattern (mocktail preferred — no code-gen)

```dart
class MockQuoteRepository extends Mock implements QuoteRepositoryBase {}

void main() {
  late MockQuoteRepository mockRepo;
  late QuoteService service;

  setUp(() {
    mockRepo = MockQuoteRepository();
    service = QuoteService(mockRepo);
  });

  test('getRandomQuote returns a quote from repo', () async {
    when(() => mockRepo.getAllQuotes())
        .thenAnswer((_) async => [Quote(id: 'q001', text: 'Test', author: null)]);

    final result = await service.getRandomQuote();

    expect(result, isNotNull);
    verify(() => mockRepo.getAllQuotes()).called(1);
  });
}
```

**Do:** Use `mocktail` — no `@GenerateMocks` annotation, no `build_runner`.
**Avoid:** `mockito` for this project — it requires code generation which adds `build_runner` complexity.

### Widget Test Pattern

```dart
testWidgets('QuoteCard shows quote text', (tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: QuoteCard(quote: Quote(id: 'q001', text: 'Test quote', author: null)),
    ),
  );

  expect(find.text('Test quote'), findsOneWidget);
});
```

**Do:** Use `pumpWidget` with `MaterialApp` wrapper — most Flutter widgets require MaterialApp ancestor.
**Do:** Test user-visible behavior, not internal state.
**Avoid:** Accessing `notifier.privateField` in widget tests — tests implementation details that can change.

### Test Runner

```bash
flutter test                   # All tests
flutter test test/services/    # Scoped to directory
flutter analyze                # Lint — must pass before any task is "done"
dart format lib/ test/         # Format check
```

**Gate:** `flutter analyze` must exit 0. `flutter test` must exit 0. Both are required before reporting a task complete.

---

## 7. Android-Specific

### Permission Setup (AndroidManifest.xml)

```xml
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM"
    android:maxSdkVersion="32"/>
<uses-permission android:name="android.permission.USE_EXACT_ALARM"/>
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
```

**Do:** Include `android:maxSdkVersion="32"` on `SCHEDULE_EXACT_ALARM` — it is superseded by `USE_EXACT_ALARM` on API 33+.
**Avoid:** Only requesting `POST_NOTIFICATIONS` and forgetting exact alarm permissions — notifications will fail silently on API 31+.

### Exact Alarm Runtime Check (API 31+)

```dart
final androidPlugin = flutterLocalNotificationsPlugin
    .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

final canSchedule = await androidPlugin?.canScheduleExactNotifications() ?? false;
if (!canSchedule) {
  await androidPlugin?.requestExactAlarmsPermission();
}
```

**Do:** Check `canScheduleExactNotifications()` before calling `zonedSchedule` with exact mode.
**Avoid:** Assuming permission is granted — crashes on Android 14 without the check.

### Notification Scheduling Pattern

```dart
await flutterLocalNotificationsPlugin.zonedSchedule(
  notificationId,        // Fixed ID (e.g., 1001) — enables cancel-before-reschedule
  title,
  body,
  nextScheduledTime,
  notificationDetails,
  androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
  uiLocalNotificationDateInterpretation:
      UILocalNotificationDateInterpretation.absoluteTime,
  matchDateTimeComponents: DateTimeComponents.time, // Daily repeat
);
```

**Do:** Use a fixed notification ID — cancel-before-reschedule works correctly only when same ID is targeted.
**Avoid:** Generating a new ID on every schedule call — accumulates stale notifications that cannot be cancelled.

### OEM Battery Optimization

Xiaomi, Samsung, Oppo, and Huawei devices may suppress exact alarms in battery-save mode. This is not a code bug; document the behavior. `exactAllowWhileIdle` is the best achievable API guarantee — OEM restrictions are outside the app's control.

---

## 8. Code Quality

### analysis_options.yaml (project standard)

```yaml
include: package:flutter_lints/flutter.yaml

analyzer:
  language:
    strict-casts: true
    strict-inference: true
    strict-raw-types: true

linter:
  rules:
    - always_declare_return_types
    - avoid_print
    - prefer_const_constructors
    - prefer_const_declarations
    - prefer_final_fields
    - prefer_final_locals
    - require_trailing_commas
    - sort_child_properties_last
```

**Do:** Run `flutter analyze` after every logical change. Zero issues = minimum bar.
**Avoid:** `print()` in production code — use a logger or remove entirely.

---

## 9. Performance

### const — Use Everywhere Possible

```dart
const Text('KindWords')          // ✅ Never rebuilt
const SizedBox(height: 16)       // ✅ Reused widget instance
const EdgeInsets.all(16)         // ✅ Compile-time constant
```

**Do:** Add `const` to every widget constructor call where the widget's configuration never changes at runtime.
**Avoid:** Skipping `const` out of habit — the Dart analyzer will warn, but unaddressed warnings accumulate.

### ListView.builder Over ListView with Children

```dart
// ✅ Lazy — only builds visible items
ListView.builder(
  itemCount: quotes.length,
  itemBuilder: (context, index) => QuoteListItem(quote: quotes[index]),
)

// ❌ Eager — builds all items upfront (fine for <10 items, bad for 100+)
ListView(children: quotes.map((q) => QuoteListItem(q)).toList())
```

### Avoid Heavy Work in `build()`

```dart
// ✅ Pre-computed in initState or provider
final _displayText = quote.text.toUpperCase();

// ❌ Computed on every rebuild
Text(quote.text.toUpperCase())
```

---

## 10. Naming Conventions (Effective Dart)

| Artifact | Convention | Example |
|----------|-----------|---------|
| File | `snake_case.dart` | `quote_service.dart` |
| Class | `PascalCase` | `QuoteService` |
| Variable / field | `camelCase` | `currentQuote` |
| Private field | `_camelCase` | `_repository` |
| Constant | `camelCase` | `kAllQuotes` (or `maxRetries`) |
| Abstract base | `TypeBase` | `QuoteRepositoryBase` |

**Import Order (enforced by analyzer):**
1. `dart:` SDK imports
2. `package:flutter/` imports
3. Third-party `package:` imports
4. Internal `package:kindwords/` imports (prefer absolute over relative for cross-directory)
5. Relative imports (same directory or parent)

**Do:** Use `package:kindwords/...` absolute imports for cross-directory references — relative paths break when files move.
**Avoid:** Abbreviations (`svc`, `mgr`, `util`) in class/file names — clarity wins.

---

## Quick Reference — Quality Gate Checklist

Before marking any task done:

```
[ ] flutter analyze          — zero issues
[ ] flutter test             — zero failures
[ ] dart format lib/ test/   — no format diff
[ ] git log --oneline -1     — commit exists
[ ] git diff HEAD~1 --stat   — only expected files changed
```

Base directory for this skill: .opencode/skills/flutter-standards/
