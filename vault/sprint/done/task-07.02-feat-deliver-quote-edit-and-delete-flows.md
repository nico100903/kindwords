---
id: "07.02"
title: "Deliver quote edit and delete flows"
type: feat
priority: high
complexity: M
difficulty: moderate
sprint: 5
depends_on: ["07.01"]
blocks: ["08.01", "08.03"]
parent: "07"
branch: "feat/task-07-quote-form-flows"
assignee: dev
enriched: true
---

# Task 07.02: Deliver Quote Edit And Delete Flows

## Business Requirements

### Problem
The quote CRUD update is incomplete unless the user can revise or remove any local quote after it exists. KindWords needs edit and delete flows that work for both seeded and user-created quotes while preserving quote identity, confirmation safety, and local-only mutation rules.

### User Story
As a user, I want to edit or delete any quote in my local collection so that the app reflects the collection I actually want to keep on my device.

### Acceptance Criteria
- [ ] The Quote Form supports edit mode with pre-populated values for the selected quote.
- [ ] The user can update quote text, optional author, and tags for both seeded and user-created quotes.
- [ ] Updating a quote preserves the original `id`, preserves the original `createdAt`, and sets `updatedAt` to the local edit time.
- [ ] The user can start quote deletion from both the Quote Catalog and the Quote Form in edit mode.
- [ ] Any quote deletion requires confirmation before the quote is removed from the local database.
- [ ] Editing or deleting a seeded quote changes only the local database representation and does not imply bundled-catalog mutation or any remote propagation.

### Business Rules
- Edit access applies equally to seeded and user-created quotes in this release.
- Delete behavior removes the selected quote from the device-local collection only.
- Destructive actions must remain explicitly confirmed before completion.
- After save or delete, the quote collection should no longer show stale data for the affected quote.

### Out of Scope
- Favorites screen-specific edit and delete entry points.
- Bottom navigation changes.
- Bulk edit or bulk delete behavior.

---

## Technical Guidance

### Architecture Notes

**Axis:** State lifecycle — managing quote identity through edit/delete transitions with proper continuity and confirmation guards.

**Pattern:** Single form screen with mode determined by optional parameter. The `QuoteFormScreen` now accepts an optional `Quote? quote` argument. When `quote` is null, the screen operates in create mode (current behavior). When `quote` is non-null, the screen operates in edit mode with pre-populated values.

**Mode determination:**
- `quote == null` → Create mode: AppBar shows `✕` close, trailing action is "Save", no delete button
- `quote != null` → Edit mode: AppBar shows `←` back, trailing action is "Update", delete button visible at bottom

**Update identity preservation:**
- `id` must remain unchanged — this is the quote's immutable identity
- `createdAt` must remain unchanged — original creation timestamp is immutable
- `updatedAt` must be set to `DateTime.now()` on every successful update
- The `source` field is read-only in the UI but preserved on update

**Delete flow:**
- Delete button appears only in edit mode, positioned below a `Divider` at the bottom of the scrollable form content
- Tap triggers `AlertDialog` confirmation (not bottom sheet — more serious action per UI spec)
- On confirm: call `QuoteCatalogProvider.deleteQuote(quote.id)`, then `Navigator.pop(context, true)`
- Delete is local-only: no remote propagation implication exists in this architecture

**Navigation contract:**
- After successful save (create) or update (edit): `Navigator.pop(context, true)`
- After successful delete: `Navigator.pop(context, true)`
- The `true` result signals the caller (`QuoteCatalogScreen`) to reload the catalog via `provider.load()`
- This pattern already exists in `_navigateToCreate()` — extend it to edit/delete flows

**Continuity hooks (provider-level only, no UI wiring in this task):**
- `QuoteProvider.refreshCurrentIfStale(id)` exists — caller may invoke after update/delete if the home screen needs to reflect changes
- `FavoritesProvider.reload()` exists — caller may invoke after update/delete if favorites need fresh data
- For 07.02, the catalog refresh after `Navigator.pop` is the primary continuity mechanism; cross-screen hooks are optional

**Unsaved changes guard (edit mode):**
- If implementing safely within wave: on back press with dirty form, show discard dialog per UI spec
- If time/risk constrained: defer to follow-up — a missing guard is not a blocker for core edit/delete functionality

### Affected Areas

| File | Change |
|------|--------|
| `lib/screens/quote_form_screen.dart` | Add optional `Quote? quote` parameter; pre-populate controllers in edit mode; add delete button + confirmation; call `updateQuote` on save; preserve `id`/`createdAt` |
| `lib/screens/quote_catalog_screen.dart` | Wire `_QuoteListTile` edit/delete button `onPressed` handlers to navigate to form (edit) or show confirmation bottom sheet (delete from catalog) |
| `lib/providers/quote_catalog_provider.dart` | No changes expected — `updateQuote` and `deleteQuote` methods already exist |
| `lib/providers/quote_provider.dart` | No changes expected — `refreshCurrentIfStale` already exists; caller decides when to invoke |
| `lib/providers/favorites_provider.dart` | No changes expected — `reload()` already exists; caller decides when to invoke |
| `test/screens/quote_form_screen_test.dart` | Add tests for edit mode pre-population, update persistence, delete visibility, confirmation flow |
| `test/screens/quote_catalog_screen_test.dart` | Add tests for edit/delete button wiring, catalog refresh after mutations |
| `CHANGELOG.md` | Add entry under `## [Unreleased]` for edit/delete flows |

### Quality Gates

- [ ] Edit mode shows pre-populated quote text, author (or empty if null), and selected tags matching the quote being edited
- [ ] Update action persists changed values while preserving original `id` and `createdAt`, and sets `updatedAt` to current time
- [ ] Delete action button is visible only in edit mode, never in create mode
- [ ] Delete requires confirmation via `AlertDialog` before the quote is removed from the database
- [ ] After delete confirmation, the quote no longer appears in the catalog after navigation returns
- [ ] After update, the catalog reflects the updated text/author/tags immediately
- [ ] Updating a quote whose `source` or `tags` change causes it to correctly appear/disappear based on active filters
- [ ] Seeded quotes can be edited and deleted locally — no special-case restrictions
- [ ] `flutter analyze` exits with code 0
- [ ] `flutter test` exits with code 0
- [ ] `CHANGELOG.md` updated under `## [Unreleased]` with user-visible edit/delete entry

### Gotchas

1. **Resetting `createdAt` on edit** — The `Quote` constructor in `_onSave()` must explicitly copy `widget.quote.createdAt` when in edit mode. Creating a new `Quote` with a fresh timestamp is a common bug.

2. **Delete button visible in create mode** — Must conditionally render the delete section based on `_isEditMode`. A simple boolean derived from `widget.quote != null` guards this.

3. **Deleting without confirmation** — The delete button's `onPressed` must show the confirmation dialog first; it must NOT call `deleteQuote` directly.

4. **Stale filtered catalog after update/delete** — The caller (`QuoteCatalogScreen`) must call `provider.load()` when `Navigator.pop` returns `true`. The `_navigateToCreate` pattern already demonstrates this; ensure edit/delete flows follow the same contract.

5. **Over-implementing favorites integration** — Do not wire `FavoritesProvider.reload()` or add edit/delete buttons to the Favorites screen. That is task 08.01. This task only ensures the continuity hooks exist at the provider level.

---

## Affected Areas

- Quote form edit mode behavior
- Quote deletion confirmation flow
- Local-only seeded quote mutation rules

---

## Changes

- Files modified: `lib/screens/quote_form_screen.dart`, `lib/screens/quote_catalog_screen.dart`, `CHANGELOG.md`, `test/screens/quote_form_screen_test.dart`, `test/screens/quote_catalog_screen_test.dart`
- Tests: `flutter test` — 317 passed, 0 failed (23 skipped, pre-existing platform-channel skips)
- Analyze: `flutter analyze` — 0 issues
- Changelog: entry added under `## [Unreleased]` — "Quote edit and delete flows"
- Deviations from Technical Guidance: none
