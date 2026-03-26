---
id: "02.03"
title: "Implement favorites list and delete flow"
type: feat
priority: high
complexity: M
difficulty: routine
sprint: 5
depends_on: ["02.01", "02.02"]
blocks: ["03.04"]
parent: "02"
branch: "feat/task-02-favorites-experience"
assignee: dev
enriched: true
---

# Task 02.03: Implement Favorites List And Delete Flow

## Business Requirements

### Problem
Saved content is only useful if users can review and manage it later. This task turns the favorites destination into a complete user flow with visible saved items, a clear empty state, and item removal.

### User Story
As a user, I want to see and remove my saved quotes so that I can manage the quotes I care about.

### Acceptance Criteria
- [ ] Opening favorites with saved items shows each saved quote in a scrollable list.
- [ ] Opening favorites with no saved items shows a friendly empty-state message.
- [ ] Each saved item exposes a remove action.
- [ ] Removing a saved quote updates the favorites destination immediately and the removed quote does not return after app restart unless saved again.

### Business Rules
- The empty-state message must make it clear that no favorites have been saved yet.
- Delete behavior removes only the selected quote.
- The favorites destination must support at least 50 saved items without hiding access to the remove action.

### Out of Scope
- Bulk delete.
- Search, sort, or filter controls.
- Sharing favorites externally.

---
<!-- TECHNICAL GUIDANCE - written by Tech Lead below this line -->
<!-- Do not modify Business Requirements when enriching -->

## Architecture Notes

**Current state:** `FavoritesScreen` is already fully scaffolded and functionally correct as of task 02.01. The screen uses `Consumer<FavoritesProvider>`, a `ListView.builder`, a `ListTile`-based row with a delete `IconButton`, a null-guarded subtitle, and an empty-state `Text`. The coder's job is verification and polish — not a build from scratch.

**Rebuild scope — `Consumer<FavoritesProvider>` is sufficient:**
The entire `body` is wrapped in a single `Consumer<FavoritesProvider>`. On any `notifyListeners()` call (add, remove, load), the full list rebuilds. At the 50-item scale specified in Business Rules, this is acceptable — the rebuild cost is negligible and a `Selector` would add complexity without a measurable gain. Do not introduce `Selector` here.

**`ListView.builder` is correct (flutter-standards §9):**
`ListView.builder` is lazy — it only constructs widgets for visible items. For 50+ favorites this is the correct choice over `ListView(children: [...])`, which eagerly builds all items on mount. The current implementation already uses `ListView.builder`; verify it stays that way.

**`ListTile` over `QuoteCard` — decision rationale:**
`QuoteCard` (`lib/widgets/quote_card.dart`) is a full-screen hero widget: `Card` with `32px` padding on all sides, `fontSize: 20`, centered text, and `mainAxisSize: MainAxisSize.min` for single-item display. Placing it inside `ListView.builder` would produce a list of large cards with enormous vertical spacing — wrong density for a management list. `ListTile` with `maxLines: 2, overflow: TextOverflow.ellipsis` on the title and a conditional `subtitle` is the correct density for a scannable, scrollable list. This is not a compromise — it is the right widget for the context. `QuoteCard` remains correct for its home-screen hero role.

**Delete callback — `context.read` is correct:**
The `onPressed` callback currently calls `favProvider.removeFavorite(quote)` directly on the `Consumer`-supplied instance. This is equivalent to `context.read<FavoritesProvider>().removeFavorite(quote)` and is correct — callbacks must not use `context.watch` (flutter-standards §2). The removal is synchronous in-memory (`_favorites` is immediately replaced via `.where()`) followed by an async `SharedPreferences` write inside the provider. The UI updates on the `notifyListeners()` call that fires after the in-memory mutation — before persistence completes — which is the correct pattern for perceived instant response.

**`removeFavorite` implementation is index-safe:**
The provider filters by `quote.id` (`_favorites.where((q) => q.id != quote.id).toList()`) and replaces the entire list reference. The `ListView.builder` receives a new `itemCount` on the next build, so no stale index can reference a removed element. This is the correct deletion pattern — never splice by index.

**No `Tests` section yet:** QA has not committed failing tests for this task. Coder must run `flutter test` to confirm the existing test suite is green before and after any changes.

---

## Affected Areas

| File | Change type | Detail |
|------|-------------|--------|
| `lib/screens/favorites_screen.dart` | Verify / minor polish | Screen is functionally complete. Coder verifies: `ListView.builder` used, empty-state text matches AC ("No favorites yet. Start saving quotes you love!" or equivalent friendly message), `ListTile.subtitle` is null-guarded, delete callback does not use `context.watch`. Add `const` where the analyzer flags it. |
| `lib/providers/favorites_provider.dart` | Read-only / verify | `removeFavorite` filters by `quote.id` — correct. `favorites` getter returns `List.unmodifiable` — correct. No changes expected unless a test exposes a gap. |
| `lib/widgets/quote_card.dart` | No change | `QuoteCard` is **not** used in `FavoritesScreen` by design (see Architecture Notes). No modification needed. |
| `lib/models/quote.dart` | No change | `Quote.author` is `String?` — null safety already handled in `ListTile.subtitle` construction. |

**Files that must NOT be touched:** `lib/services/favorites_service.dart`, `lib/data/`, `lib/repositories/`, `main.dart`, `android/`.

---

## Quality Gates

All gates must pass before the task is reported complete (flutter-standards §6 checklist):

- [ ] `flutter analyze` exits 0 — zero lint issues
- [ ] `flutter test` exits 0 — all existing tests pass, no regressions
- [ ] `dart format lib/ test/` — no format diff
- [ ] `git log --oneline -1` — commit exists

**Behavior assertions (verified by reading code + widget tests if present):**

- `favorites.isEmpty` → the empty-state `Text` widget is the only body child (no `ListView`)
- `favorites.isNotEmpty` → `ListView.builder` is the body child (not `ListView(children:)`)
- `ListView.builder.itemCount` equals `favorites.length` at the time of build
- `ListTile.subtitle` is `null` when `quote.author == null` — no null crash, no "— null" text
- After `removeFavorite(quote)` is called, `notifyListeners()` fires synchronously (before the async `_favoritesService.removeFavorite` completes), causing the list to rebuild immediately with `itemCount` decremented by 1
- The removed quote does not reappear after hot-restart (persistence handled by `FavoritesService` + SharedPreferences)
- The list renders correctly with 50+ items (manual inspection or widget test with 50-item provider stub)

---

## Gotchas

1. **`ListTile.subtitle` null safety — must pass `null`, not a `Text('— null')`.** The current implementation guards correctly: `subtitle: quote.author != null ? Text('— ${quote.author}') : null`. If this guard is ever removed or refactored, the `ListView` will render "— null" for anonymous quotes. The analyzer's `strict-casts: true` will not catch this — it is a logic error, not a type error. Verify the guard is intact.

2. **Index stability after deletion — never delete by index.** `ListView.builder` calls `itemBuilder` with indices `0..itemCount-1`. If a deletion were implemented as `_favorites.removeAt(index)` using the `index` captured in the closure, it would be prone to stale-closure bugs when multiple deletions occur in quick succession (the `index` in the closure becomes stale after the first removal shifts the list). The current implementation avoids this entirely by filtering on `quote.id` and replacing the list reference — the `index` in `itemBuilder` is only used to retrieve the `Quote` object, which is then passed by value to `removeFavorite`. This pattern is correct and must not be changed to an index-based splice.

3. **`Consumer` rebuilds the full list on every favorites change.** When a quote is added from the home screen while `FavoritesScreen` is in the back-stack, the `Consumer` will rebuild on the next `notifyListeners()`. This is correct behavior (list stays fresh) and has no visual artifact since the screen is not visible. At 50-item scale the rebuild cost is ~microseconds. Do not optimize with `Selector` — the added complexity is not warranted and would require splitting the widget tree in a way that complicates the empty-state/list switch logic.
