---
id: "08.01"
title: "Extend favorites for quote edit and delete continuity"
type: feat
priority: high
complexity: M
difficulty: moderate
sprint: 6
depends_on: ["02.03", "07.02"]
blocks: ["08.03"]
parent: "08"
branch: "feat/task-08-quote-integration"
assignee: dev
enriched: true
---

# Task 08.01: Extend Favorites For Quote Edit And Delete Continuity

## Business Requirements

### Problem
Favorites will feel broken if the user can manage quotes in the catalog but not from the saved list, or if edited and deleted favorites stay stale. KindWords needs favorites continuity so quote CRUD works wherever the user encounters a saved quote.

### User Story
As a user, I want to edit or delete favorited quotes from Favorites and see the results immediately so that my saved list always matches my current local quote collection.

### Acceptance Criteria
- [ ] The Favorites screen continues to display the user's favorited quotes after the quote CRUD update.
- [ ] Each favorited quote exposes an edit action that opens the Quote Form in edit mode for that quote.
- [ ] Each favorited quote exposes a delete action that removes the quote locally only after confirmation.
- [ ] If a favorited quote is edited, the Favorites screen reflects the updated local quote content.
- [ ] If a favorited quote is deleted, the Favorites screen no longer shows that quote and does not leave a stale favorite entry behind.

### Business Rules
- Favorites persistence remains tied to local quote identity rather than a separate duplicate quote copy.
- Favorites continuity must survive the quote schema migration and later quote edits.
- Quote deletion from Favorites remains a local-only action and must never imply remote mutation.
- Favorites integration must not regress the existing ability to view a saved-quote list offline.

### Out of Scope
- Changes to random quote generation.
- Bottom navigation structure.
- Notification scheduling changes.

---

## Technical Guidance

### Architecture Notes

**Decisive axis:** cross-provider coordination — `FavoritesScreen` must push `QuoteFormScreen` in a route context where `QuoteCatalogProvider` is accessible (required by `QuoteFormScreen._onSave` and `QuoteFormScreen._onDelete`), and then surface the post-mutation state back to `FavoritesProvider` on return.

**Pattern selected: push with `.value` re-share + explicit reload on return**

The `QuoteFormScreen` (already implemented) reads and writes `QuoteCatalogProvider` exclusively — it calls `context.read<QuoteCatalogProvider>().updateQuote(quote)` and `context.read<QuoteCatalogProvider>().deleteQuote(id)`. `FavoritesScreen` is a standalone bottom-nav destination that sits outside the `QuoteCatalogProvider` scope established by the catalog route.

```
Option A: ChangeNotifierProvider.value re-share (inject existing QuoteCatalogProvider)
  Pro: minimal — no new providers, no new scope; QuoteFormScreen works unchanged
  Con: requires reading the provider from a higher ancestor; .value constructor is
       appropriate here because the existing ancestor ChangeNotifierProvider owns the lifecycle

Option B: Duplicate CRUD logic in FavoritesScreen (bypass QuoteFormScreen)
  Pro: no provider cross-wiring
  Con: duplicates all form/validation/confirmation logic, violates DRY, diverges
       from the catalog edit path — rejected
```

**Chosen: Option A.** `FavoritesScreen` uses `context.read<QuoteCatalogProvider>()` inside the navigation callback to obtain the live provider instance, then passes it into the pushed route via `ChangeNotifierProvider.value`. This is the correct use of `.value`: re-sharing an *existing, ancestor-owned* instance, not creating a fresh one. The ancestor `ChangeNotifierProvider` retains disposal ownership.

After `QuoteFormScreen` pops with `result == true` (save or delete), `FavoritesScreen` calls `context.read<FavoritesProvider>().reload()` to re-fetch IDs from `SharedPreferences` and re-resolve them through the repository. This gives fresh `Quote` objects and silently drops any ID whose record was deleted — the exactly-correct stale-entry cleanup described in the business rules.

**Constraint created:** `FavoritesScreen` must be a `StatefulWidget` (or use a nested `StatefulWidget` for the navigation callback) because `async` navigation handlers require `mounted` checks after the `await`. The current `FavoritesScreen` is a `StatelessWidget`; this task must convert it to `StatefulWidget`.

**Constraint created for downstream tasks:** `FavoritesProvider.reload()` already exists (added in task 05.02 as an anticipatory hook). The coder must not add a second `reload` implementation — use the existing one.

#### Decision Documentation

```
Decision: FavoritesScreen → QuoteFormScreen provider wiring
Context: QuoteFormScreen depends on QuoteCatalogProvider; FavoritesScreen is
         not in its scope.
Options:
  A. ChangeNotifierProvider.value — re-share existing catalog provider instance
  B. Duplicate CRUD path in FavoritesScreen — avoid wiring, accept duplication
Chosen: A
Rationale: QuoteFormScreen's CRUD code is already validated, tested, and complete.
           Re-wiring via .value costs one read + one navigator.push — well within
           scope. Duplication cost would be high and creates divergence risk on
           future form evolution.
Constraints created: FavoritesScreen must become StatefulWidget; mounted check
                     required after all async navigation await points.
Escape hatch: If QuoteCatalogProvider is ever unavailable from FavoritesScreen's
              ancestor tree, extract a shared QuoteWriteService that both screens
              can read from a common provider scope.
```

---

### Affected Areas

| File | Change type | Notes |
|------|-------------|-------|
| `lib/screens/favorites_screen.dart` | **modify** | Convert `StatelessWidget` → `StatefulWidget`; add edit `IconButton` to trailing row; implement `_navigateToEdit(Quote)` that pushes `QuoteFormScreen` via `ChangeNotifierProvider.value`, then calls `FavoritesProvider.reload()` on `result == true`; add `mounted` check after each `await`. |
| `test/screens/favorites_screen_test.dart` | **extend** | QA adds failing tests for: (a) edit `IconButton` present on each row, (b) correct icon (`Icons.edit_outlined`), (c) edit tap pushes `QuoteFormScreen`, (d) after edit-then-pop with `result=true` the updated quote text is shown, (e) after delete-then-pop with `result=true` the deleted quote is absent from the list. |
| `CHANGELOG.md` | **extend** | One bullet under `## [Unreleased] → ### Changed` for user-visible favorites edit/delete entry points. |

Files **not** changed by this task:
- `lib/providers/favorites_provider.dart` — `reload()` already exists; no changes needed.
- `lib/providers/quote_catalog_provider.dart` — no changes needed.
- `lib/screens/quote_form_screen.dart` — already complete; no changes needed.
- `lib/services/favorites_service.dart` — no changes needed.
- Any data or repository layer file — no changes needed.

---

### Quality Gates

1. **`flutter analyze` exits 0** — zero issues including `prefer_const_constructors`, `always_declare_return_types`, and `avoid_print` rules.
2. **`flutter test` exits 0** — all existing tests continue to pass; all new QA-written tests for 08.01 pass.
3. **Mounted check verified:** every `async` method in `_FavoritesScreenState` that calls `context.read<...>()` or `setState()` after an `await` must have `if (!mounted) return;` immediately after the `await`.
4. **Edit icon present:** `Icons.edit_outlined` appears exactly once per favorited quote row (test-verified by QA).
5. **Delete icon unchanged:** `Icons.delete_outline` still appears once per row and its existing behavior is unaffected — existing test 6 and test 7 in `favorites_screen_test.dart` must remain green.
6. **Stale-entry cleanup:** after a favorite is deleted via the form, the ID is no longer present in `SharedPreferences`; `FavoritesProvider.reload()` silently drops it (no orphan entry) — verified by widget test.
7. **Edit propagation:** after a favorite is edited via the form and the screen returns, the tile shows updated quote text — verified by widget test.
8. **`CHANGELOG.md`** gains exactly one entry under `## [Unreleased]` describing the user-visible change (edit/delete from Favorites).

---

### Gotchas

1. **`ChangeNotifierProvider.value` is correct here — but only because lifecycle is already owned.** The catalog's `ChangeNotifierProvider(create: ...)` in the ancestor tree owns the instance. Re-sharing via `.value` into the pushed route is safe. If the instance were created inside the `.value` call (e.g., `ChangeNotifierProvider.value(value: QuoteCatalogProvider(repo), ...)`), it would leak because no one calls `dispose()`. The correct call reads the provider first: `final p = context.read<QuoteCatalogProvider>(); ... ChangeNotifierProvider.value(value: p, child: ...)`.

2. **`FavoritesProvider.reload()` skips the `isLoading` flag by design.** The existing `reload()` implementation sets `_favorites` and calls `notifyListeners()` without toggling `_isLoading`. This is intentional — a background sync-on-return should not flash a spinner. Do not modify `reload()` to add loading state; the UI will respond correctly to the `notifyListeners()` call alone.

3. **Delete from Favorites calls `QuoteCatalogProvider.deleteQuote()` via `QuoteFormScreen`, not `FavoritesProvider.removeFavorite()`.** This means the `SharedPreferences` favorite ID is *not* explicitly cleaned up by the CRUD delete path — it is silently dropped on the next `reload()` because `FavoritesService.loadFavorites()` resolves IDs through `_repository.getById(id)` and returns `null` for missing records, which are then skipped. No explicit ID removal call is needed; the reload is the cleanup mechanism.

4. **`FavoritesScreen` trailing row width budget.** Adding a second `IconButton` to the trailing slot means the trailing `Row` contains two 48dp-minimum tap targets. Use `mainAxisSize: MainAxisSize.min` on the `Row` and `const` constructors on both `IconButton`s. Verify on a small-screen device or emulator that the trailing row does not overflow the tile width when quote text is long — the existing `maxLines: 2` title constraint already protects against text overflow, but trailing widget overflow can still occur if the row is not min-sized.
