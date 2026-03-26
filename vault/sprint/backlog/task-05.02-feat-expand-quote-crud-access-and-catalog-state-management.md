---
id: "05.02"
title: "Expand quote CRUD access and catalog state management"
type: feat
priority: high
complexity: M
difficulty: moderate
sprint: 2
depends_on: ["05.01"]
blocks: ["06.01", "07.01", "08.03"]
parent: "05"
branch: "feat/task-05-quote-crud-foundation"
assignee: dev
enriched: true
---

# Task 05.02: Expand Quote CRUD Access And Catalog State Management

## Business Requirements

### Problem
Even with a richer quote schema, Sprint 2 cannot deliver browse or form flows until the app exposes local CRUD behavior through reusable quote access and catalog state. KindWords needs one local quote management lane that can load, filter, create, update, and delete quotes consistently across the new CRUD experience.

### User Story
As a user, I want the app's quote collection to respond consistently to local quote changes so that catalog browsing and form actions stay in sync across the app.

### Acceptance Criteria
- [ ] The local quote access layer supports create, read, update, and delete behavior for both seeded and user-created quotes.
- [ ] The quote catalog state layer can load all locally stored quotes and apply an optional source filter plus an optional single-tag filter at the same time.
- [ ] After a local quote update or delete, the app can refresh or replace any currently displayed affected quote instead of leaving stale quote content visible.
- [ ] Local quote access remains fully offline and does not introduce any remote mutation path for seeded or user-created quotes.

### Business Rules
- Source filtering supports exactly three browse options: All, Seeded, and Mine.
- Tag filtering supports one predefined tag at a time while still allowing an optional source filter.
- CRUD state must stay compatible with Sprint 1 random quote behavior and existing favorites identity rules.
- Local quote creation, update, and deletion behavior must operate against the same local quote collection used for browse flows.

### Out of Scope
- Quote catalog screen presentation.
- Quote form create, edit, and delete screen behavior.
- Favorites screen edit/delete integration.

---

## Technical Guidance

### Architecture Notes

**Axis:** State management across data-access boundaries — ensuring provider-level state stays consistent with database mutations while maintaining clean layer separation.

**Pattern:** Provider owns full list in-memory; filters are computed getters over that list. This trades memory for UI responsiveness and simpler state coherence after mutations. Alternative (DB-level filtering on each filter change) rejected because: (1) creates async latency on every filter toggle, (2) requires more complex cache invalidation, (3) current quote count (~100-200) makes in-memory filtering trivial.

**Layer contract:**
- `QuoteCatalogProvider` is the sole owner of catalog state — it loads via repository, holds `_allQuotes`, and exposes `quotes` as a filtered getter.
- `QuoteRepositoryBase` remains the only abstraction consumed by providers. **Providers must not import `QuoteDatabase` directly** — this preserves the existing clean-architecture boundary established in Sprint 1.
- `QuoteDatabase` provides DAL methods; `LocalQuoteRepository` wraps them with no additional logic.

**Filter implementation:**
- `sourceFilter`: `QuoteSource?` — `null` means "All", otherwise `seeded` or `userCreated`.
- `tagFilter`: `String?` — `null` means no tag filter; non-null matches against `quote.tags.contains(tagFilter)`.
- The `quotes` getter computes: `_allQuotes.where(source matches).where(tag matches).toList()`.
- Filters are reactive: changing either filter calls `notifyListeners()`; UI sees updated `quotes` immediately.

**Mutation coherence:**
- `createQuote(quote)`: insert via repository → append to `_allQuotes` → `notifyListeners()`.
- `updateQuote(quote)`: update via repository → find/replace in `_allQuotes` by id → `notifyListeners()`.
- `deleteQuote(id)`: delete via repository → remove from `_allQuotes` → `notifyListeners()`.
- Because `quotes` is computed from `_allQuotes`, filtered output updates automatically after any mutation.

**QuoteProvider compatibility boundary:**
- Task 05.02 documents but does not implement UI wiring for stale-current-quote handling.
- If `QuoteProvider.currentQuote.id` matches a deleted/updated quote, the provider cannot know this without a coordination mechanism.
- **Boundary decision:** Add `refreshCurrentIfStale(String id)` method to `QuoteProvider` in this task, but do not wire it to any UI callback. Document that `QuoteCatalogProvider.deleteQuote()` should call this when UI integration happens in a later task. This keeps the hook minimal and testable without coupling to screens.

**FavoritesProvider boundary:**
- `FavoritesProvider` stores full `Quote` objects. After an update, those objects are stale.
- Add a public `reload()` method to `FavoritesProvider` that re-fetches from `FavoritesService`.
- Do not auto-call it from `QuoteCatalogProvider` — cross-provider coordination is a UI concern for later tasks.

### Affected Areas

| File | Change Type | Notes |
|------|-------------|-------|
| `lib/data/quote_database.dart` | Extend | Add `insert`, `update`, `delete`, `getBySource`, `getByTag` methods |
| `lib/repositories/quote_repository.dart` | Extend | Add abstract methods + impl on `LocalQuoteRepository` |
| `lib/providers/quote_catalog_provider.dart` | **NEW** | Full CRUD provider with filter state |
| `lib/providers/quote_provider.dart` | Modify | Add `refreshCurrentIfStale(String id)` method |
| `lib/providers/favorites_provider.dart` | Modify | Add `reload()` method |
| `test/data/quote_database_test.dart` | Extend | Tests for new DAL methods |
| `test/repositories/quote_repository_test.dart` | Extend | Tests for new repository methods |
| `test/providers/quote_catalog_provider_test.dart` | **NEW** | Full provider behavior tests |
| `test/providers/quote_provider_test.dart` | Extend | Test `refreshCurrentIfStale` |
| `test/providers/favorites_provider_test.dart` | Extend | Test `reload()` |
| `CHANGELOG.md` | Modify | Add entry under `## [Unreleased]` |

### Quality Gates

- [ ] `flutter analyze` exits 0
- [ ] `flutter test` exits 0
- [ ] Repository exposes `insertQuote`, `updateQuote`, `deleteQuote`, `getBySource`, `getByTag` methods
- [ ] `QuoteCatalogProvider.load()` populates `_allQuotes` and sets `isLoading = false`
- [ ] `QuoteCatalogProvider.quotes` returns filtered list respecting both `sourceFilter` and `tagFilter`
- [ ] `createQuote()` adds to `_allQuotes` and calls `notifyListeners()`
- [ ] `updateQuote()` replaces quote in `_allQuotes` by id and calls `notifyListeners()`
- [ ] `deleteQuote()` removes from `_allQuotes` and calls `notifyListeners()`
- [ ] After delete, the deleted quote does not appear in `quotes` getter even if it previously matched filters
- [ ] After update that changes tags/source, `quotes` getter reflects the change immediately
- [ ] No `import '../data/quote_database.dart'` in any provider file
- [ ] `QuoteProvider.refreshCurrentIfStale(id)` fetches fresh quote from service if `currentQuote.id == id`
- [ ] `FavoritesProvider.reload()` re-fetches favorites from service and notifies listeners
- [ ] CHANGELOG updated with entry under `## [Unreleased]`

### Gotchas

1. **Stale filtered list if getter is cached:** If `quotes` is a cached `List<Quote>` field instead of a computed getter, mutations won't update it. Must be a getter that recomputes on each access.

2. **Tag filtering on raw JSON string:** DB stores tags as `'["personal","wisdom"]'` (JSON string). Filtering at DB level must use `LIKE '%tag%'` or JSON functions. At provider level, filter against `quote.tags` (already parsed `List<String>`). Do not filter against the raw JSON column.

3. **Provider importing database directly:** Enforce layer boundary via code review. If a provider file contains `import '../data/quote_database.dart'`, it violates architecture.

4. **Mutation without notifyListeners:** `updateQuote` and `deleteQuote` are async; the internal list mutation + `notifyListeners()` must happen after repository call completes, not before. Pattern: `await _repo.updateQuote(quote); _allQuotes = _allQuotes.map(...).toList(); notifyListeners();`

5. **Cross-provider coordination scope creep:** This task adds the *hooks* (`refreshCurrentIfStale`, `reload`) but does not wire them to `QuoteCatalogProvider` mutations. Wiring is a UI-layer concern for tasks 06.xx and 07.xx. Do not add `QuoteCatalogProvider → QuoteProvider` dependencies in this task.
