---
id: "04.01"
title: "Introduce local quote database and repository"
type: feat
priority: high
complexity: M
difficulty: complex
sprint: 3
depends_on: ["01.03"]
blocks: ["04.02", "02.02"]
parent: "04"
branch: "feat/task-04-quote-data-foundation"
assignee: dev
enriched: true
---

# Task 04.01: Introduce Local Quote Database And Repository

## Business Requirements

### Problem
The app currently depends on bundled quote content as its runtime source, which makes future catalog changes harder to manage safely. KindWords needs a durable local quote foundation that can initialize from the existing bundled catalog without changing the offline user promise.

### User Story
As a user, I want the app's quote library to initialize locally and remain available offline so that future catalog changes do not break my core quote experience.

### Acceptance Criteria
- [ ] On first app run, the local quote catalog is prepared automatically from the existing bundled quote dataset with no internet access required.
- [ ] After initial preparation, reopening the app reuses the existing local quote catalog instead of creating duplicate quote entries.
- [ ] The prepared local quote catalog contains at least 100 quotes with the same stable quote IDs already defined for the release catalog.
- [ ] If the local quote catalog already exists, app startup still succeeds without requiring the user to reset data.

### Business Rules
- Local quote preparation runs only when the app does not already have its quote catalog available.
- The quote catalog remains fully offline and bundled with the app at release.
- Stable quote IDs from the current release catalog must be preserved during the transition.

### Out of Scope
- Switching the home, favorites, or notification flows to the new runtime quote source.
- Remote quote sync or refresh behavior.
- Any user-facing favorites persistence changes.

---
<!-- TECHNICAL GUIDANCE - written by Tech Lead below this line -->
<!-- Do not modify Business Requirements when enriching -->

## Architecture Notes

### 1. Add `sqflite` (and `path`) to `pubspec.yaml` — do not use `path_provider`

Add `sqflite: ^2.3.3` and `path: ^1.9.0` to `dependencies` in `pubspec.yaml`. Use `getDatabasesPath()` from `sqflite` together with `path.join()` to resolve the DB path; avoid `path_provider` as it is not needed and would add an unrequired dependency.

```
# pubspec.yaml additions
sqflite: ^2.3.3
path: ^1.9.0
```

Run `flutter pub get` immediately after to lock the dependency before any code is written.

### 2. `QuoteDatabase` — thin SQLite adapter, one responsibility only

Create `lib/data/quote_database.dart`. This class owns:
- Opening and versioning the database (`openDatabase`, `version: 1`, `onCreate`)
- One table: `quotes(id TEXT PRIMARY KEY, text TEXT NOT NULL, author TEXT)`
- One public method: `seedIfEmpty(List<Quote> quotes)` — inserts all rows in a single transaction (`batch`) when the table is empty; does nothing on subsequent runs (idempotent)
- One public method: `getAllQuotes() → Future<List<Quote>>`

Do NOT put query logic, random selection, or repository business rules here. `QuoteDatabase` is a data-access object, not a service.

**Do** use a single `batch()` for the initial seed insert — 100+ individual `insert()` calls in a loop are measurably slower and waste write transactions.
**Avoid** using `conflictAlgorithm: ConflictAlgorithm.replace` on seed — it silently overwrites existing rows and defeats the "seed only once" guarantee. Use `INSERT OR IGNORE` semantics via `conflictAlgorithm: ConflictAlgorithm.ignore`.

### 3. `QuoteRepository` — provider-agnostic abstraction boundary

Create `lib/repositories/quote_repository.dart` containing:
- An **abstract class** `QuoteRepositoryBase` with methods: `Future<List<Quote>> getAllQuotes()` and `Future<Quote?> getById(String id)`
- A concrete `LocalQuoteRepository implements QuoteRepositoryBase` that delegates to `QuoteDatabase`

**Why the abstract class matters now:** `04.02` will wire `QuoteRepository` into `QuoteService`. If the interface is concrete-only, the migration in `04.02` either directly couples to sqflite or requires a breaking change. The abstract class costs nothing here and prevents a painful seam refactor later. Do NOT define a `getRandomQuote()` on the repository — random selection stays in `QuoteService` (it is presentation behavior, not persistence).

**Avoid** naming the abstract base `IQuoteRepository` (Java-ism) or `QuoteRepositoryInterface` — use the Dart convention of `QuoteRepositoryBase`.

### 4. Seed call belongs in `app_bootstrap.dart`, before provider construction

The seed must complete before the app presents a quote to the user. The correct hook is `bootstrapApp()` in `lib/bootstrap/app_bootstrap.dart`, after `WidgetsFlutterBinding.ensureInitialized()` is confirmed (it is already called in `main.dart`) and before the `MultiProvider` tree is built.

Sequence in `bootstrapApp()`:
1. Open `QuoteDatabase`
2. Call `seedIfEmpty(kAllQuotes)` — passes the existing bundled list from `lib/data/quotes_data.dart`
3. Construct `LocalQuoteRepository` with the now-seeded database instance
4. Continue constructing existing services (`QuoteService`, etc.)

**Do not** make the seed call from `QuoteProvider`, `QuoteService`, or any lazy/lazy-init path — these are called after the widget tree is built and the race between first-frame and seed completion will cause a blank or fallback quote state.

**Avoid** storing the `QuoteDatabase` singleton in a global variable. Pass it through the constructor chain (`QuoteDatabase → LocalQuoteRepository`) and expose only the repository to the rest of the app.

### 5. `quotes_data.dart` remains unchanged — it is the seed source, not the runtime source

`kAllQuotes` in `lib/data/quotes_data.dart` is used **once** at seed time. It must not be removed or altered in this task. `04.02` will redirect `QuoteService` to read from the repository at runtime. In this task, `QuoteService` still reads from `kAllQuotes` — that is intentional and correct for this scope boundary.

### 6. Favorites layer: zero changes

`FavoritesService` stores quote IDs as strings in `shared_preferences`. Quote IDs are already stable (`q001`–`q100+` scheme). No favorites migration is needed now or in `04.02`. The only future risk is if a DB-sourced quote ever loses an ID — the existing `getById` null-safe lookup in `FavoritesService.loadFavorites()` already handles that gracefully with a `whereType<Quote>()` filter.

### 7. Remote-refresh facade: declare the interface, implement nothing

Per the architecture decision, leave a stub hook in `QuoteRepositoryBase` for future remote expansion. The cleanest approach is to keep `QuoteRepositoryBase` as-is (no `refresh()` method) and note in a code comment that a `RemoteQuoteRepository` will implement the same interface. Do NOT add a `refresh()` or `syncFromRemote()` method to the base class in this task — it has no acceptance criterion here and forces `LocalQuoteRepository` to stub out a method it cannot implement correctly.

---

## Affected Areas

| File | Change |
|------|--------|
| `pubspec.yaml` | Add `sqflite: ^2.3.3` and `path: ^1.9.0` |
| `lib/data/quote_database.dart` | **New** — SQLite adapter, seed, getAllQuotes |
| `lib/repositories/quote_repository.dart` | **New** — `QuoteRepositoryBase` abstract class + `LocalQuoteRepository` concrete |
| `lib/bootstrap/app_bootstrap.dart` | Modify — open DB, call seedIfEmpty, pass `LocalQuoteRepository` into service graph |
| `pubspec.lock` | Auto-updated by `flutter pub get` |

**No changes to:**
- `lib/data/quotes_data.dart` (seed-source catalog — read-only for this task)
- `lib/models/quote.dart` (Quote model is already correct)
- `lib/services/quote_service.dart` (still reads from `kAllQuotes` — migration deferred to `04.02`)
- `lib/services/favorites_service.dart` (ID-based storage is already correct)
- All providers and screens

---

## Quality Gates

1. **`flutter analyze` reports zero issues** on the new and modified files before the task is considered done.
2. **`flutter test` passes** with no regressions on existing tests.
3. **Seed idempotency:** call `seedIfEmpty` twice in a unit test with a non-empty DB; assert row count does not double. A `getAllQuotes()` call after two seed attempts must return exactly the same count as after one.
4. **Seed completeness:** after seeding, `getAllQuotes()` returns a list with the same length as `kAllQuotes.length` (currently 100+). Assert `>=100`.
5. **Stable IDs preserved:** spot-check that `getById('q001')` and `getById('q100')` both return non-null quotes after seeding.
6. **Cold-start safety:** app must reach the home screen with a valid quote displayed when no pre-existing database file exists (simulates first install). Verify by wiping app data on an emulator and running `flutter run`.
7. **No duplicate startup cost:** second cold-start (DB exists) must not re-insert rows. Confirm via a log message or test assertion in `seedIfEmpty`.
8. **Bootstrap ordering:** `QuoteDatabase.open()` and `seedIfEmpty()` must complete before `runApp()`. The `bootstrapApp()` function is already `async`-awaited in `main.dart` — do not break that contract.

---

## Gotchas

**G1 — `sqflite` database path on Android**
`getDatabasesPath()` returns an Android-specific path (`/data/data/<package>/databases/`). Do not hard-code a path string. Do not use `getApplicationDocumentsDirectory()` (from `path_provider`) — it places the file in a different location that is backed up by default and can cause restore-on-reinstall confusion.

**G2 — `Quote.author` is nullable; the DB column must be nullable too**
The `author TEXT` column must allow NULL. When reading rows back with `Map<String, Object?>`, cast `author` as `row['author'] as String?` — not `as String`. A non-null cast will throw at runtime for anonymous quotes.

**G3 — `batch()` must be committed with `await batch.commit(noResult: true)`**
Forgetting `await` on `batch.commit()` silently drops all inserts. Use `noResult: true` for the seed batch — it avoids allocating a list of 100+ result objects and is measurably faster.

**G4 — Database version and migration**
Use `version: 1` now. When a future migration is needed, `onUpgrade` will need to handle the delta. Do not skip the `version` parameter — omitting it defaults to 1 but makes the intent invisible and confuses future coder on `04.02`.

**G5 — `bootstrapApp` is async but `QuoteProvider` synchronously requires a quote**
`QuoteProvider` currently calls `_quoteService.getRandomQuote()` synchronously in its constructor (it reads `kAllQuotes` directly). That contract is unchanged in this task. The seed is a one-time async operation that completes before the widget tree is built — no loading state is required in this task. `04.02` will introduce async quote loading; do not jump ahead.

**G6 — Do not create `lib/repositories/` inside `lib/services/`**
The repository is an architectural abstraction between data and service layers. Place it at `lib/repositories/`, not nested under `lib/services/`. Putting it under services blurs the dependency direction (services should depend on repositories, not the other way around).

**G7 — `kAllQuotes` is a `const List` — do not mutate it**
Pass `kAllQuotes` (or a copy via `.toList()`) into `seedIfEmpty`. Do not try to sort or transform it in-place.
