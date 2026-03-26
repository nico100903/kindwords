# Sprint Discovery — Quote CRUD
**Status:** DISCOVERY COMPLETE  
**Date:** 2026-03-27  
**Requested by:** Academic requirement (prof needs to see CRUD)  
**Scope confirmed:** Full CRUD on a personal single-user app

---

## 1. Scope Summary

The user is the sole owner of all quotes. There is no admin/user split.  
Two categories of quotes will coexist in the database:

| Category | Created by | Can be edited? | Can be deleted? |
|----------|-----------|----------------|-----------------|
| **Seeded** | Embedded `kAllQuotes` catalog at first run | ✅ User can edit text, author, tags | ✅ User can delete (local DB only — does not touch catalog constant) |
| **User-created** | User writing their own quotes in the app | ✅ Full edit | ✅ Full delete |

**Online pool note:** When Firebase is implemented (v1.1 roadmap), user deletions of seeded quotes MUST NOT propagate to the remote pool — deletion is a local-DB operation only. This constraint must be enforced by design in this sprint (no network call in delete path).

---

## 2. Data Model Changes

### 2a. `Quote` model — new fields

| Field | Type | Notes |
|-------|------|-------|
| `id` | `String` | Unchanged — stable UUID or `q001` prefix for seeded |
| `text` | `String` | Unchanged |
| `author` | `String?` | Unchanged — user can now fill in missing authors |
| `tags` | `List<String>` | NEW — comma-separated in SQLite; deserialized on read |
| `source` | `QuoteSource` | NEW — `seeded` or `userCreated` (enum) |
| `createdAt` | `DateTime` | NEW — ISO-8601 string in SQLite |
| `updatedAt` | `DateTime?` | NEW — null until first edit |

### 2b. `QuoteSource` enum

```dart
enum QuoteSource { seeded, userCreated }
```

Used to:
- badge user-created quotes visually (e.g. a pen icon)
- filter the quotes list by source
- prevent remote-delete logic from triggering (future Firebase sprint)

### 2c. Predefined tags (initial set)

| Tag | Purpose |
|-----|---------|
| `personal` | Auto-applied to all user-created quotes |
| `motivational` | General motivation |
| `wisdom` | Philosophical/life lessons |
| `humor` | Light-hearted quotes |
| `love` | Relationship/kindness |
| `focus` | Productivity/goals |

User can select 0–3 tags when creating/editing a quote. Tags are stored as a JSON array string in SQLite: `'["personal","wisdom"]'`.

---

## 3. Database Changes

### 3a. Schema migration (DB version 1 → 2)

```sql
ALTER TABLE quotes ADD COLUMN tags TEXT NOT NULL DEFAULT '[]';
ALTER TABLE quotes ADD COLUMN source TEXT NOT NULL DEFAULT 'seeded';
ALTER TABLE quotes ADD COLUMN created_at TEXT NOT NULL DEFAULT '';
ALTER TABLE quotes ADD COLUMN updated_at TEXT;
```

`QuoteDatabase.open()` must be updated to:
- bump `version` to `2`
- add `onUpgrade` handler that runs the four `ALTER TABLE` statements
- update `onCreate` to include all columns from the start (for fresh installs)

### 3b. New DAL methods on `QuoteDatabase`

| Method | Signature | Notes |
|--------|-----------|-------|
| `insert` | `Future<void> insert(Quote quote)` | New user-created quote |
| `update` | `Future<void> update(Quote quote)` | Edit any quote (seeded or user) |
| `delete` | `Future<void> delete(String id)` | Remove from local DB |
| `getBySource` | `Future<List<Quote>> getBySource(QuoteSource source)` | Filter by seeded/user |
| `getByTag` | `Future<List<Quote>> getByTag(String tag)` | Filter by single tag |
| `getAllQuotes` | (existing) | Unchanged — returns all |

### 3c. Seed migration

On first DB upgrade from v1 → v2, existing seeded rows get:
- `tags = '[]'`
- `source = 'seeded'`
- `created_at = '2026-03-27T00:00:00.000Z'` (migration timestamp)

This is handled by the `onUpgrade` callback — no data loss.

---

## 4. Repository Changes

### 4a. `QuoteRepositoryBase` — new methods to add

```dart
abstract class QuoteRepositoryBase {
  // Existing
  Future<List<Quote>> getAllQuotes();
  Future<Quote?> getById(String id);
  // New
  Future<void> insertQuote(Quote quote);
  Future<void> updateQuote(Quote quote);
  Future<void> deleteQuote(String id);
  Future<List<Quote>> getBySource(QuoteSource source);
  Future<List<Quote>> getByTag(String tag);
}
```

`LocalQuoteRepository` implements all new methods by delegating to `QuoteDatabase`.

---

## 5. New Screen — Quote Catalog (`/quotes`)

**Purpose:** Browse all quotes (seeded + user-created). Full CRUD access from this screen.

### Layout

```
AppBar: "All Quotes"  [+ add button (top right)]
FilterBar: [All] [Seeded] [Mine] [#motivational] [#wisdom] ... (horizontal chip scroll)
─────────────────────────────────────────────────
ListView.builder (lazy):
  QuoteListTile:
    leading: source icon (book = seeded, pen = user-created)
    title: quote.text (maxLines: 2, ellipsis)
    subtitle: "— author" | "Anonymous"  +  tag chips (max 2 visible)
    trailing: [edit icon] [delete icon]
─────────────────────────────────────────────────
FAB: + (create new quote) — same as top right add button
```

### Interactions

| Action | Trigger | Behaviour |
|--------|---------|-----------|
| **Create** | Tap FAB or `+` in AppBar | Opens `QuoteFormScreen` (new) in push navigation |
| **Read/Browse** | ListView is the read view | Shows all quotes, filterable |
| **Edit** | Tap edit icon on any tile | Opens `QuoteFormScreen` pre-populated |
| **Delete** | Tap delete icon | Confirmation bottom sheet → deletes from local DB → list updates |

---

## 6. Extended Screen — Favorites (`/favorites`)

**New behaviour added on top of existing list:**

- Each `ListTile` gains an **edit icon** alongside the existing delete icon
- Tapping edit opens `QuoteFormScreen` pre-populated with the favorited quote
- Favorites list reactive to quote updates: if a quote is edited from here, the tile refreshes

---

## 7. New Screen — Quote Form (`QuoteFormScreen`)

**Used for both Create and Edit.** Pushed via `Navigator.push` from catalog or favorites.

### Fields

| Field | Widget | Validation |
|-------|--------|------------|
| Quote text | `TextField` (multiline, min 3 lines) | Required, min 10 chars |
| Author | `TextField` | Optional |
| Tags | Horizontal `FilterChip` row (predefined tags) | 0–3 selectable |

### Mode detection

- **Create mode:** `QuoteFormScreen()` — empty form, no `quote` argument
- **Edit mode:** `QuoteFormScreen(quote: existingQuote)` — pre-populated

### AppBar

- Create mode: title `"New Quote"`, action button `"Save"`
- Edit mode: title `"Edit Quote"`, action button `"Update"`

### Save/Update logic

- **Create:** generates a `uuid`-based ID, sets `source: QuoteSource.userCreated`, `createdAt: DateTime.now()`, calls `repository.insertQuote()`
- **Update:** copies the quote with updated fields + `updatedAt: DateTime.now()`, calls `repository.updateQuote()`
- On success: `Navigator.pop(context, true)` (returns `true` so caller can refresh)
- On validation failure: inline field error messages (no snackbar)

### Delete from form (Edit mode only)

- A `Delete` text button at the bottom of the form (destructive red)
- Tapping: shows confirmation dialog → calls `repository.deleteQuote(id)` → `Navigator.pop(context, true)`

---

## 8. Navigation Changes

`app_bootstrap.dart` must add:
```dart
'/quotes': (context) => const QuoteCatalogScreen(),
```

Bottom nav in `HomeScreen` gains a **third tab**:

| Index | Icon | Label | Route |
|-------|------|-------|-------|
| 0 | `home` | Home | `/` |
| 1 | `format_quote` | Quotes | `/quotes` |
| 2 | `favorite` | Favorites | `/favorites` |
| 3 | `settings` | Settings | `/settings` |

---

## 9. Provider Changes

### New: `QuoteCatalogProvider`

```dart
class QuoteCatalogProvider extends ChangeNotifier {
  List<Quote> _allQuotes = [];
  QuoteSource? _sourceFilter;       // null = show all
  String? _tagFilter;               // null = no tag filter
  bool _isLoading = false;

  List<Quote> get quotes;           // filtered + sorted view
  bool get isLoading;
  QuoteSource? get sourceFilter;
  String? get tagFilter;

  Future<void> load();
  Future<void> createQuote(Quote quote);
  Future<void> updateQuote(Quote quote);
  Future<void> deleteQuote(String id);
  void setSourceFilter(QuoteSource? source);
  void setTagFilter(String? tag);
}
```

### `QuoteProvider` — minor update

After `updateQuote()` is called from the catalog, `QuoteProvider.currentQuote` may be stale if the currently displayed quote was the edited one. Add `refreshCurrentIfStale(String id)` method.

### `FavoritesProvider` — minor update

After `updateQuote()`, the favorites list must reflect the new quote text/author/tags. `FavoritesProvider` calls `reload()` after any external edit notification.

---

## 10. Affected Areas (full file list)

| File | Change type | Notes |
|------|-------------|-------|
| `lib/models/quote.dart` | Extend | Add `tags`, `source`, `createdAt`, `updatedAt`; update `toMap`/`fromMap` |
| `lib/data/quote_database.dart` | Extend | Version bump 1→2, migration, new DAL methods |
| `lib/repositories/quote_repository.dart` | Extend | New methods on base + implementation |
| `lib/providers/quote_catalog_provider.dart` | **NEW** | Full CRUD provider |
| `lib/screens/quote_catalog_screen.dart` | **NEW** | Browse + CRUD list screen |
| `lib/screens/quote_form_screen.dart` | **NEW** | Create / edit form |
| `lib/screens/favorites_screen.dart` | Modify | Add edit icon + form navigation |
| `lib/screens/home_screen.dart` | Modify | 4-tab bottom nav |
| `lib/bootstrap/app_bootstrap.dart` | Modify | Register new route + provider |
| `lib/providers/quote_provider.dart` | Modify | `refreshCurrentIfStale()` |
| `lib/providers/favorites_provider.dart` | Modify | `reload()` after external edits |
| `lib/services/favorites_service.dart` | Modify | handle updated quote metadata |

---

## 11. UI / Widget Inventory

| Widget | Type | New / Existing | Notes |
|--------|------|---------------|-------|
| `QuoteCatalogScreen` | `StatelessWidget` | NEW | Uses `QuoteCatalogProvider` via Consumer |
| `QuoteFormScreen` | `StatefulWidget` | NEW | StatefulWidget — owns form field controllers |
| `QuoteListTile` | `StatelessWidget` | NEW | Reusable — used in catalog AND potentially favorites |
| `TagFilterChips` | `StatelessWidget` | NEW | Horizontal chip scroll row, reusable |
| `QuoteTagChip` | `StatelessWidget` | NEW | Single tag display chip (read-only) |
| `QuoteCard` | existing | No change | Home screen card unchanged |
| `FavoritesScreen` | existing | Modify | Add edit icon |

---

## 12. Quality Gates (per flutter-standards)

- `flutter analyze` — 0 issues
- `flutter test` — 0 failures (new tests for all 4 CRUD operations + filter, migration, form validation)
- Schema migration: existing seeded rows survive v1 → v2 upgrade without data loss
- `Quote.fromMap` handles missing new columns gracefully (for rows from v1 schema with no tags/source)
- `QuoteSource.userCreated` quotes are never sent to any network endpoint
- Delete of a seeded quote removes it from local DB only — `kAllQuotes` constant is unmodified
- Form validation: submit with empty text shows inline error, does not call repository
- Edit from favorites: favorites list tile updates immediately after save without full reload

---

## 13. Out of Scope (this sprint)

- Cloud sync of user-created quotes (Firebase sprint, v1.1)
- Quote sharing (screenshot / clipboard) — deferred to v2.0 UI revamp
- Quote search (full-text) — deferred; filter by source/tag covers the academic CRUD requirement
- Import / export of user quotes — deferred
- Multiple tag filter combination (AND/OR) — deferred; single-tag filter sufficient for v1

---

## 14. Open Questions (resolved)

| # | Question | Decision |
|---|----------|----------|
| 1 | Can seeded quotes be deleted? | Yes — local DB only |
| 2 | Can seeded quotes be edited? | Yes — text, author, tags all editable |
| 3 | Do edits to seeded quotes affect `kAllQuotes`? | No — constant is never modified; only the DB row changes |
| 4 | How many tags per quote? | 0–3 |
| 5 | User-created quotes seeded too? | No — only appear via the Create form |
| 6 | UUID format for user-created quote IDs? | `user_<uuid_v4>` prefix to distinguish from `q001` seeded IDs |
