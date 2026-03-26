---
id: "02.02"
title: "Persist favorite quotes and prevent duplicates"
type: feat
priority: high
complexity: M
difficulty: moderate
sprint: 5
depends_on: ["02.01", "04.01", "04.02"]
blocks: ["02.03", "03.04"]
parent: "02"
branch: "feat/task-02-favorites-experience"
assignee: dev
enriched: true
---

# Task 02.02: Persist Favorite Quotes And Prevent Duplicates

## Business Requirements

<!-- Updated: 2026-03-26 -- database-first quote pivot before favorites persistence -->

### Problem
Saving a quote only matters if the app remembers it later, does not create confusing duplicates, and stays reliable even as the quote catalog storage changes underneath it. This task makes favorites trustworthy by turning the save action into durable local behavior tied to each quote's stable identity.

### User Story
As a user, I want my saved quotes to remain available after I close the app so that favorites feel dependable.

### Acceptance Criteria
- [ ] Saving the currently displayed quote stores it locally and keeps it available after app restart.
- [ ] Saving the same quote multiple times results in exactly one saved copy.
- [ ] If a quote is already saved, the app can recognize that state without requiring internet access.
- [ ] Restarting the app preserves the saved favorites set with no manual restore action by the user.
- [ ] A saved favorite remains associated with the same quote identity even after the quote catalog runtime storage moves to the local database.

### Business Rules
- Favorites are uniquely identified by quote ID.
- Duplicate saves are not allowed.
- Favorites persistence must remain local to the device only.
- Favorite membership is user-owned data and must not be cleared by future quote catalog refresh behavior.

### Out of Scope
- Rendering the final favorites list UI.
- Deleting favorites from the favorites list.
- Exporting or syncing saved quotes.
- Implementing quote catalog refresh behavior.

---
<!-- TECHNICAL GUIDANCE - written by Tech Lead below this line -->
<!-- Do not modify Business Requirements when enriching -->

## Architecture Notes

**Primary axis:** the state read/write boundary between `HomeScreen` and `FavoritesProvider`.

`HomeScreen` currently consumes only `QuoteProvider`. This task adds a second Provider dependency — `FavoritesProvider` — solely for the save/unsave button. The wiring must follow the §2 (Provider) rules from the flutter-standards skill:

- **Read path (icon state):** `context.watch<FavoritesProvider>().isFavorite(quote)` inside `build()`. This triggers a widget rebuild when `FavoritesProvider` calls `notifyListeners()` after a toggle, which is what drives the filled/outline heart icon switch. Using `context.read` here would produce a stale icon on first tap.

- **Write path (button press):** `context.read<FavoritesProvider>().toggleFavorite(quote)` inside the `onPressed` callback. Using `context.watch` inside a callback subscribes unnecessarily on every call; `read` is correct for fire-and-forget imperative actions.

- **Nullable guard:** `QuoteProvider.currentQuote` is `Quote?` — it is `null` during initialization and briefly after a `refreshQuote()` call. The save button must be disabled (`onPressed: null`) or absent when `currentQuote == null`. Never force-unwrap with `!` directly on the Provider getter in the button handler.

- **Duplicate prevention:** `FavoritesProvider.addFavorite()` already applies an in-memory guard (`_favorites.any((q) => q.id == quote.id) → return`), and `FavoritesService.addFavorite()` applies a SharedPreferences-level guard (`ids.contains(quote.id) → return`). Both layers exist; no changes are needed to either class.

- **Async load on startup:** `FavoritesProvider` calls `_loadFavorites()` as fire-and-forget from its constructor, which sets `isLoading = true`, awaits SharedPreferences, then sets `isLoading = false` and calls `notifyListeners()`. This is already implemented correctly. The coder must not add a second load call or a duplicate `initState` trigger in any screen.

- **`isFavorite` is synchronous:** `FavoritesProvider.isFavorite(Quote)` checks `_favorites` in memory — no async, no `await`. The async gap only happens during the initial `_loadFavorites()`. After that the in-memory list is the source of truth for the icon check.

- **No service changes:** `FavoritesService` already handles SharedPreferences persistence correctly. No changes to `favorites_service.dart` are needed for this task.

## Affected Areas

| File | Change type | Description |
|------|------------|-------------|
| `lib/screens/home_screen.dart` | **modify** | Add `FavoritesProvider` wiring: import, `context.watch` for icon state, `context.read` for toggle in `onPressed`. Add save/unsave `IconButton` (heart icon) to `AppBar.actions` or inline next to the quote card — placement is implementation choice, but must be visible on the home screen. Guard with `currentQuote != null`. |
| `test/screens/home_screen_test.dart` | **new** | Widget tests: heart icon renders as outline when not favorited, renders as filled when favorited, tapping toggles icon, button is disabled/absent when `currentQuote` is null. |
| `test/providers/favorites_provider_test.dart` | **new** | Unit tests: `addFavorite` grows list by 1, duplicate `addFavorite` leaves list at size 1, `removeFavorite` shrinks list, `isFavorite` returns correct value, `toggleFavorite` round-trips. |
| `test/services/favorites_service_test.dart` | **new** | Unit tests: `addFavorite` idempotency (second call no-ops), `removeFavorite` clears entry, `loadFavorites` hydrates from SharedPreferences, stale ID (no matching repo entry) is silently skipped. |

No changes to: `favorites_provider.dart`, `favorites_service.dart`, `favorites_screen.dart`, `quote_provider.dart`, `quote_service.dart`, or any data/repository layer file.

## Quality Gates

All of the following must pass before this task is reported complete:

1. **In-memory check is immediate:** `provider.isFavorite(quote)` returns `true` immediately after `provider.addFavorite(quote)` completes — no additional `await` required.
2. **Toggle updates icon:** In widget test, after `tester.tap(find.byIcon(Icons.favorite_outline))` + `pumpAndSettle`, `find.byIcon(Icons.favorite)` (filled) resolves to one widget.
3. **Re-tap removes favorite:** After a second tap + `pumpAndSettle`, the outline icon reappears and `provider.isFavorite(quote)` returns `false`.
4. **List cardinality:** `favorites_provider_test.dart` asserts `provider.favorites.length == 1` after two calls to `addFavorite` with the same quote.
5. **SharedPreferences persistence:** `favorites_service_test.dart` uses `SharedPreferences.setMockInitialValues({})`, calls `addFavorite`, constructs a fresh `FavoritesService` instance, calls `loadFavorites`, and asserts the quote is present — simulating a cold restart without clearing storage.
6. **Stale ID skip:** `loadFavorites` with a stored ID that returns `null` from `_repository.getById()` produces an empty list with no exception thrown.
7. **`flutter analyze` exits 0** — zero issues, including strict-mode inference warnings.
8. **`flutter test` exits 0** — all existing tests continue to pass; no regressions.

## Gotchas

**1. `context.watch` vs `context.read` for the favorite icon**
Risk: Using `context.read<FavoritesProvider>().isFavorite(quote)` inside `build()` reads the state once and never rebuilds when `toggleFavorite` calls `notifyListeners()`. The heart icon stays stale after the first tap.
Correct pattern: `context.watch<FavoritesProvider>().isFavorite(quote)` inside `build()` — the `watch` subscription ensures the widget rebuilds on every `notifyListeners()` from `FavoritesProvider`.

**2. `currentQuote` nullable guard before calling `toggleFavorite`**
Risk: `QuoteProvider.currentQuote` is `Quote?`. During initialization (before `_initialize()` resolves) and briefly during `refreshQuote()`, it is `null`. If the save button's `onPressed` passes `currentQuote!` directly, a `Null check operator used on a null value` exception is thrown in production on slow devices or aggressive test setups.
Correct pattern: Obtain `final quote = context.watch<QuoteProvider>().currentQuote;` in `build()`, then set `onPressed: quote == null ? null : () => context.read<FavoritesProvider>().toggleFavorite(quote)`. A `null` `onPressed` disables the button automatically.

**3. SharedPreferences async load is already wired — do not duplicate it**
Risk: Adding a `_loadFavorites()` call from a screen's `initState` (or a second constructor call) triggers a redundant SharedPreferences read and a race with the provider's in-flight load. The first `notifyListeners()` mid-load would overwrite `_favorites` with an empty list, clearing what had already loaded.
Correct pattern: `FavoritesProvider` already fires `_loadFavorites()` from its constructor body. Screens must only read `provider.isLoading` to gate their UI — never trigger a reload themselves.
