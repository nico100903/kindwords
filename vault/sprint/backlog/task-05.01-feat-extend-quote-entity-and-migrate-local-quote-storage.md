---
id: "05.01"
title: "Extend quote entity and migrate local quote storage"
type: feat
priority: high
complexity: M
difficulty: moderate
sprint: 1
depends_on: ["04.02"]
blocks: ["05.02"]
parent: "05"
branch: "feat/task-05-quote-crud-foundation"
assignee: dev
enriched: true
---

# Task 05.01: Extend Quote Entity And Migrate Local Quote Storage

## Business Requirements

### Problem
The current quote record is too small to support local CRUD behavior, filtering, and edit history. KindWords needs a safe local migration that enriches stored quotes without breaking existing quote access, favorites continuity, or the app's offline behavior.

### User Story
As a user, I want my existing local quotes to survive the quote CRUD update so that I can gain richer quote management without reinstalling the app or losing current data continuity.

### Acceptance Criteria
- [ ] Upgrading a device from quote database version 1 to version 2 preserves previously stored quote records and their existing stable IDs.
- [ ] After migration, every locally stored quote record includes `id`, `text`, `author`, `tags`, `source`, `createdAt`, and `updatedAt` fields, with `tags` defaulting to an empty list and `source` defaulting to `seeded` for migrated rows.
- [ ] The quote data model supports exactly two sources in this release: `seeded` and `userCreated`.
- [ ] The migrated quote store remains usable by existing favorites references and does not require the user to clear app data or reinstall.

### Business Rules
- Predefined tags for this release are `personal`, `motivational`, `wisdom`, `humor`, `love`, and `focus`.
- A quote may have 0, 1, 2, or 3 tags, but never more than 3.
- Seeded quote edits and deletes remain local-device actions only and must never imply bundled-catalog mutation or remote propagation.
- `createdAt` is required for every stored quote; `updatedAt` may remain empty until a local edit occurs.

### Out of Scope
- Repository CRUD contract expansion.
- Quote catalog browsing and filtering UI.
- Quote form create, edit, or delete screens.

---

## Affected Areas

- Quote entity shape and local persistence contract
- Local quote schema versioning and migration continuity
- Seeded quote compatibility with existing favorites references

---

## Technical Guidance

### Architecture Notes

**Axis:** Data migration with API boundary implications. The decisive concern is schema evolution while preserving backward compatibility with existing rows.

**Pattern:** Non-destructive `ALTER TABLE ADD COLUMN` migration with defensive `fromMap` deserialization.

This is a **data-migration task only** — no UI work, no repository contract changes, no provider modifications. Those belong to downstream tasks (05.02+).

**Constraints:**

1. **`Quote` remains the single value object** across DB/repo/service/UI layers. No DTOs or intermediate shapes.

2. **Tags storage format:** JSON array string (`'["personal","wisdom"]'`), NOT comma-joined string. Rationale: proper list semantics, no delimiter collision risk, future-proof for programmatic manipulation. Use `dart:convert` `jsonEncode`/`jsonDecode`.

3. **Source persistence:** String enum values `'seeded'` and `'userCreated'`. Not integer indices — string values are debuggable and survive enum reordering.

4. **Timestamps:** ISO-8601 strings (`DateTime.toIso8601String()`). `createdAt` is required; `updatedAt` is nullable until first edit.

5. **Backward compatibility:** `Quote.fromMap()` MUST handle rows missing `tags`, `source`, `created_at`, `updated_at` columns (v1 schema rows). Default values:
   - `tags` → `[]`
   - `source` → `QuoteSource.seeded`
   - `createdAt` → migration timestamp (`2026-03-27T00:00:00.000Z` or `DateTime.now()` at upgrade time)
   - `updatedAt` → `null`

6. **Database version:** Bump from `1` to `2`. Implement `onUpgrade` for existing installs; update `onCreate` for fresh installs.

7. **Migration approach:** Four `ALTER TABLE ADD COLUMN` statements with `DEFAULT` values. NEVER drop and recreate the table — existing rows must survive.

### Affected Areas (files)

| File | Change Type | Notes |
|------|-------------|-------|
| `lib/models/quote.dart` | Extend | Add `tags`, `source`, `createdAt`, `updatedAt`; add `QuoteSource` enum; update `toMap`/`fromMap` with backward-compatible deserialization |
| `lib/data/quote_database.dart` | Extend | Version bump to `2`; add `onUpgrade` handler with `ALTER TABLE` statements; update `onCreate` to include all v2 columns |
| `test/models/quote_test.dart` | New | Unit tests for `toMap`/`fromMap` round-trip, backward compatibility with missing columns |
| `test/data/quote_database_test.dart` | New | Integration tests for v1→v2 migration, fresh install v2 schema |
| `CHANGELOG.md` | Update | Document schema migration under `## [Unreleased]` |

**Explicitly NOT in scope:**
- `lib/data/quotes_data.dart` — seeded data constant unchanged; migration populates new columns via `onUpgrade`, not by modifying seed data
- `lib/repositories/quote_repository.dart` — no new methods; CRUD contract expansion is task 05.02
- Any provider, screen, or UI file

### Quality Gates

All gates must be verifiable via `flutter test` and `flutter analyze`:

1. **Backward compatibility:** `Quote.fromMap()` successfully deserializes a v1 row (map with only `id`, `text`, `author` keys) without throwing. Resulting quote has `tags = []`, `source = QuoteSource.seeded`, `createdAt` set to fallback timestamp, `updatedAt = null`.

2. **Round-trip integrity:** For any `Quote` with all fields populated, `Quote.fromMap(quote.toMap())` produces an equal quote.

3. **Fresh install v2 schema:** New database created via `onCreate` includes all seven columns: `id`, `text`, `author`, `tags`, `source`, `created_at`, `updated_at`.

4. **Migration preserves rows:** Upgrading from v1 to v2 via `onUpgrade`:
   - All existing rows survive (count unchanged)
   - Each row has `tags = '[]'`, `source = 'seeded'`, `created_at` populated with migration timestamp
   - Existing `id`, `text`, `author` values unchanged

5. **Static analysis:** `flutter analyze` exits with code 0 (no warnings or errors).

6. **Test suite:** `flutter test` exits with code 0 (all tests pass).

7. **Changelog updated:** `CHANGELOG.md` has entry under `## [Unreleased]` documenting the schema migration.

### Gotchas

1. **Direct cast of missing columns crashes:** `row['tags'] as String` throws when the column doesn't exist (v1 row). Use `row['tags'] as String? ?? '[]'` pattern for all new columns.

2. **Storing Dart list directly in sqflite map fails silently or corrupts:** `{'tags': ['a', 'b']}` does NOT work — sqflite expects primitive types. Must JSON-encode: `{'tags': jsonEncode(['a', 'b'])}`.

3. **Destructive migration (DROP TABLE) loses user data:** NEVER use `DROP TABLE quotes` or `db.execute('DELETE FROM quotes')` in migration. Use `ALTER TABLE ADD COLUMN` only.

4. **Modifying `kAllQuotes` constant instead of migrating DB rows:** Seeded quote edits are local DB operations only. The `quotes_data.dart` constant is immutable; `onUpgrade` handles existing row enrichment.

5. **Nullable vs default confusion in ALTER TABLE:** SQLite `ALTER TABLE ADD COLUMN` requires `DEFAULT` for `NOT NULL` columns. Use:
   ```sql
   ALTER TABLE quotes ADD COLUMN tags TEXT NOT NULL DEFAULT '[]';
   ALTER TABLE quotes ADD COLUMN source TEXT NOT NULL DEFAULT 'seeded';
   ALTER TABLE quotes ADD COLUMN created_at TEXT NOT NULL DEFAULT '';
   ALTER TABLE quotes ADD COLUMN updated_at TEXT;
   ```
   The empty string default for `created_at` will be replaced by `fromMap` fallback — acceptable tradeoff for non-destructive migration.
