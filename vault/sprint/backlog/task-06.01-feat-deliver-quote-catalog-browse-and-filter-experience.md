---
id: "06.01"
title: "Deliver quote catalog browse and filter experience"
type: feat
priority: high
complexity: M
difficulty: moderate
sprint: 3
depends_on: ["05.02"]
blocks: ["07.01", "08.02"]
parent: "06"
branch: "feat/task-06-quote-catalog-browse"
assignee: dev
enriched: true
---

# Task 06.01: Deliver Quote Catalog Browse And Filter Experience

## Business Requirements

### Problem
Sprint 1 lets the user see only one random quote at a time, which does not satisfy the new browse and read requirements. KindWords needs a dedicated catalog view so the user can inspect the full local collection and choose where to create, edit, or delete quotes.

### User Story
As a user, I want a Quotes screen that shows my full local collection with filters so that I can browse and manage quotes intentionally instead of only through random refreshes.

### Acceptance Criteria
- [ ] The app provides a Quote Catalog screen that lists all quotes currently stored in the local database.
- [ ] Each visible catalog item shows the quote text, author or anonymous fallback, source indicator, and visible tags when tags exist.
- [ ] The catalog supports source filtering with All, Seeded, and Mine options and tag filtering by one predefined tag at a time while keeping any active source filter.
- [ ] When no quotes match the active filters, the catalog shows a clear empty-filter state with a way to clear the active filters.
- [ ] The catalog visibly exposes create, edit, and delete entry points from the screen even if later tasks complete the form behaviors.

### Business Rules
- The catalog shows both `seeded` and `userCreated` quotes in one collection.
- Empty-filter feedback must be distinct from the unlikely no-quotes-at-all state.
- Tag display uses only predefined tags already supported by the quote record.
- Browse behavior must remain fully local and offline.

### Out of Scope
- Saving a new quote.
- Updating or deleting a quote from the form.
- Favorites screen CRUD entry points.

---

## Technical Guidance

### Architecture Notes

**Axis:** UI state management with reactive filter composition.

**Pattern:** Provider-first reactive UI. `QuoteCatalogScreen` consumes `QuoteCatalogProvider` only — no direct repository access. The provider already exposes a computed `quotes` getter that applies `sourceFilter` and `tagFilter` on each access. Screen uses `Consumer<QuoteCatalogProvider>` to rebuild when filters change.

**Provider lifecycle:** The screen triggers `provider.load()` exactly once via `initState` + `addPostFrameCallback` guard pattern. The provider's `isLoading` state drives a centered `CircularProgressIndicator` during load. Never call `load()` inside `build()` — this causes infinite rebuild loops.

**Filter composition:** Source filter (`All` / `Seeded` / `Mine`) and tag filter (single tag or none) compose independently. Setting a source filter does NOT clear the tag filter, and vice versa. Both filters may be active simultaneously. The provider's `quotes` getter handles composition — UI only calls `setSourceFilter()` and `setTagFilter()`.

**List scalability:** Use `ListView.builder` with `itemCount: quotes.length`. Do NOT use `Column` + `map()` or `ListView(children: [...])` — these build all items eagerly. The quote catalog may contain 100+ quotes after seeding.

**Row density:** Use `ListTile` for each quote row — consistent with `FavoritesScreen` and the UI spec. Do NOT use `QuoteCard` (designed for hero display on HomeScreen). Each tile shows:
- `leading`: `Icons.menu_book_outlined` (seeded) or `Icons.edit_note` (userCreated)
- `title`: quote text, `maxLines: 2`, `overflow: TextOverflow.ellipsis`
- `subtitle`: author line + tag chips (max 2 visible, `+N` overflow if 3)
- `trailing`: `Row` of two `IconButton`s — edit and delete

**Edit/delete entry points:** Wire `IconButton(onPressed: ...)` for edit and delete icons. For this task, the callbacks may be no-ops or placeholder `Navigator.pushNamed` to a non-existent route. The critical requirement is visible UI affordances. Actual form/delete confirmation behavior belongs to Wave 3 (task 07.01+).

**Reusable widgets:** If `QuoteListTile` and `TagFilterChips` reduce duplication, extract to `lib/widgets/`. Keep blast radius low — do not refactor existing screens. The decision is at coder's discretion based on complexity.

**Empty states:** Distinguish two cases:
1. Empty-filter state: `_allQuotes` is non-empty but `quotes` (filtered) is empty → show "No quotes match this filter" with clear-filter button.
2. No-quotes-at-all state: `_allQuotes` is empty → show "Your quote collection is empty" with FAB prompt (unlikely in practice but handled).

**Filter bar UI:** Horizontal `SingleChildScrollView` of `FilterChip` widgets below AppBar, above list. Height 48dp. Source chips (All/Mine/Seeded) and tag chips (#motivational, #wisdom, etc.) are visually grouped but behave independently. Active chip uses `colorScheme.primaryContainer` fill.

**Route registration:** Add `/quotes` route to `MaterialApp.routes` in `app_bootstrap.dart`. The route maps to `QuoteCatalogScreen`. Bottom navigation expansion to 4 tabs is task 08.02 — this task only registers the route.

**Provider registration:** `QuoteCatalogProvider` must be registered in `app_bootstrap.dart` `MultiProvider`. It takes `LocalQuoteRepository` as constructor argument (same repo instance used by `QuoteService` and `FavoritesService`).

### Affected Areas

- `lib/screens/quote_catalog_screen.dart` — new screen (primary)
- `lib/widgets/quote_list_tile.dart` — optional reusable list tile
- `lib/widgets/tag_filter_chips.dart` — optional reusable filter bar
- `lib/bootstrap/app_bootstrap.dart` — route `/quotes` + provider registration
- `test/screens/quote_catalog_screen_test.dart` — widget tests
- `CHANGELOG.md` — entry under `## [Unreleased]`

### Quality Gates

- `flutter analyze` exits 0
- `flutter test` exits 0
- `/quotes` route resolves to `QuoteCatalogScreen` without crash
- Screen displays all quotes from provider after load completes
- Source filter chips (All/Mine/Seeded) update visible list correctly when tapped
- Tag filter chips update visible list correctly when tapped
- Source + tag filters compose (both active shows intersection)
- Empty-filter state appears when no quotes match active filters
- "Clear filters" button resets both source and tag filters
- List uses `ListView.builder`, not `ListView(children: [...])` or `Column`
- Each row displays edit icon button and delete icon button
- `CHANGELOG.md` has entry under `## [Unreleased]`

### Gotchas

1. **Provider load in build loop:** Calling `provider.load()` inside `build()` triggers infinite rebuild. Use `initState` + flag guard or `FutureBuilder` pattern. Provider already sets `isLoading` state.

2. **Using QuoteCard instead of ListTile:** `QuoteCard` is designed for hero display. Catalog density requires `ListTile`. Using `QuoteCard` violates UI spec and causes visual inconsistency with Favorites screen.

3. **Filter state desync:** Chip visual selection (`selected` property) must reflect `provider.sourceFilter` and `provider.tagFilter`. If chip shows selected but filter is null (or vice versa), user sees stale UI.

4. **Filters overwriting each other:** Calling `setSourceFilter()` must NOT clear `tagFilter`, and vice versa. The provider handles composition — UI must not manually reset the other filter.

5. **Eager list building:** Using `ListView(children: quotes.map(...).toList())` builds all 100+ widgets upfront. Must use `ListView.builder(itemBuilder: ...)` for lazy construction.

---

## Affected Areas

- `lib/screens/quote_catalog_screen.dart` — new
- `lib/widgets/quote_list_tile.dart` — optional
- `lib/widgets/tag_filter_chips.dart` — optional
- `lib/bootstrap/app_bootstrap.dart` — route + provider
- `test/screens/quote_catalog_screen_test.dart` — new
- `CHANGELOG.md`
