---
id: "08.03"
title: "Run quote CRUD regression verification"
type: test
priority: high
complexity: M
difficulty: moderate
sprint: 7
depends_on: ["08.01", "08.02"]
blocks: []
parent: "08"
branch: "feat/task-08-quote-integration"
assignee: qa
enriched: true
---

# Task 08.03: Run Quote CRUD Regression Verification

## Business Requirements

### Problem
Sprint 2 is not complete until the quote CRUD update is proven without breaking the finished offline app. KindWords needs one verification pass that confirms the new CRUD behavior, migration safety, and compatibility with the existing favorites and notification flows.

### User Story
As a reviewer, I want clear verification evidence for quote CRUD and non-regression so that I can trust Sprint 2 for demo and evaluation.

### Acceptance Criteria
- [ ] Verification confirms the local quote schema upgrades from version 1 to version 2 without losing previously stored quote records.
- [ ] Verification confirms create, edit, and delete behavior for local quotes, including seeded-quote local-only mutation rules and delete confirmation behavior.
- [ ] Verification confirms Quote Catalog filtering by source and predefined tags, including empty-filter behavior.
- [ ] Verification confirms Quote Form validation rejects blank text and text shorter than 10 characters with visible field-level feedback.
- [ ] Verification confirms Favorites reflects edited and deleted quotes correctly.
- [ ] Verification confirms the random quote journey, favorites persistence, and daily notification behavior do not regress after the quote CRUD update.

### Business Rules
- Verification must cover both automated checks and user-visible journey behavior.
- Sprint 2 closes only when both new CRUD behavior and Sprint 1 compatibility constraints are verified.
- Any discovered regression should be recorded against the affected task lane before Sprint 2 is considered complete.

### Out of Scope
- New feature implementation.
- APK release debugging unrelated to quote CRUD behavior.
- Future sync, search, or sharing behavior.

---

## Affected Areas

- Migration and CRUD verification coverage
- Quote catalog filter and form validation verification
- Favorites, random quote, and notification non-regression evidence

---

## Technical Guidance

### Architecture Notes

**Decisive axis:** This is a coverage-closure and evidence task, not a feature task. The axis is *test completeness* — auditing the automated suite against each acceptance criterion, identifying any coverage gap, filling it with targeted tests, and producing a verification report that closes Sprint 2.

**What "verification" means for 08.03:**

| Layer | Verification approach |
|---|---|
| Migration (v1→v2) | 23 skipped integration tests in `test/data/quote_database_test.dart` (Groups 2, 4, 6) require a connected device/emulator to exercise `sqflite` platform channel. The automated suite already has API-surface contract coverage for the migration path via mock stubs. The gap to fill is an explicit device-run evidence entry in the verification report. |
| CRUD operations | Fully covered by `test/data/quote_database_test.dart` (Groups 5, 6), `test/providers/quote_catalog_provider_test.dart`, `test/screens/quote_catalog_screen_test.dart`, and `test/screens/quote_form_screen_test.dart`. No new unit tests are expected here. |
| Filter behavior | Fully covered: source filter (All/Seeded/Mine), tag filter, and combined intersection behavior all pass in `quote_catalog_screen_test.dart` and `quote_catalog_provider_test.dart`. Empty-filter state (no matches) is covered. |
| Form validation | Covered: blank text, sub-10-char text, exactly-10-char boundary, and optional-author path all pass in `quote_form_screen_test.dart`. |
| Favorites continuity | Covered: edit icon presence, edit navigation, reload-on-pop(true), no-reload-on-pop(false), stale-entry cleanup after delete via form — all in `test/screens/favorites_screen_test.dart` (Tests 10–14). |
| Non-regression (random quote, notifications, navigation) | Covered by `test/home_screen_quote_flow_test.dart`, `test/screens/home_screen_navigation_test.dart`, `test/services/notification_service_test.dart`, `test/settings_screen_test.dart`. |

**Pattern choice — verification report over new test structure:** QA's primary output for 08.03 is a `vault/ai/docs/sprint2-verification-report.md` (or equivalent) that maps each acceptance criterion to evidence. This is the artifact that closes Sprint 2. The automation gate (`flutter test` passing) is a prerequisite, not the deliverable.

### Verification Approach (Step-by-Step)

**Step 1 — Run the full automated suite and confirm baseline:**
```bash
fvm flutter analyze          # Must exit 0
fvm flutter test --no-pub    # Must report 337+ passing, 23 skipped, 0 failing
```
The 23 skipped tests are `sqflite` platform-channel integration tests (Groups 2, 4, 6 in `quote_database_test.dart`). They are correctly skipped in the Dart VM environment; they are not coverage gaps for this task.

**Step 2 — Map each acceptance criterion to existing test evidence:**

| AC | Covered by | File |
|---|---|---|
| Schema migration v1→v2 without data loss | API-surface mocks (Groups 3, 5 pass) + device evidence note | `test/data/quote_database_test.dart` |
| Create behavior: source=userCreated, id, createdAt | `Save action` group | `test/screens/quote_form_screen_test.dart` |
| Edit behavior: id/createdAt preserved, updatedAt set | `Update identity preservation` group | `test/screens/quote_form_screen_test.dart` |
| Seeded quote local-only mutation rules | `Seeded quote local mutation` group | `test/screens/quote_form_screen_test.dart` |
| Delete confirmation (AlertDialog + Cancel/Delete) | `Delete confirmation flow` group | `test/screens/quote_form_screen_test.dart` |
| Catalog source filter (All/Seeded/Mine) | `Source filter: Seeded`, `Mine` groups | `test/screens/quote_catalog_screen_test.dart` |
| Catalog tag filter + empty-filter state | `Tag filter`, `Empty-filter state` groups | `test/screens/quote_catalog_screen_test.dart` |
| Filter composition (source + tag intersection) | `Filter composition` group | `test/screens/quote_catalog_screen_test.dart` |
| Form validation: blank text, < 10 chars, boundary | `Quote text field validation` group | `test/screens/quote_form_screen_test.dart` |
| Favorites: edit icon present | Tests 10–11 (08.01) | `test/screens/favorites_screen_test.dart` |
| Favorites: reload after edit returns true | Test 12 | `test/screens/favorites_screen_test.dart` |
| Favorites: stale cleanup after delete via form | Test 13 | `test/screens/favorites_screen_test.dart` |
| Favorites: cancel does not reload | Tests 12, 13 (cancel paths) | `test/screens/favorites_screen_test.dart` |
| Random quote journey non-regression | `home_screen_quote_flow_test.dart` | — |
| Notification non-regression | `notification_service_test.dart` | — |
| 4-tab navigation non-regression | `home_screen_navigation_test.dart` | — |

**Step 3 — Identify and fill coverage gaps:**

The following areas have partial or weak coverage that QA should assess:

1. **`QuoteProvider.refreshCurrentIfStale()` behavior** — discovery doc (Section 9) calls for a method to handle the case where the currently displayed home-screen quote was the one that just got edited. Check `test/providers/quote_provider_test.dart`: if `refreshCurrentIfStale` is not tested, add a unit test that verifies: (a) calling it with the matching ID causes the provider to reload, (b) calling it with a non-matching ID is a no-op.

2. **`FavoritesProvider.reload()` after external edit** — `favorites_screen_test.dart` tests this via the widget layer. If there is no unit test in `test/providers/favorites_provider_test.dart` that directly asserts `reload()` is called after `updateQuote/deleteQuote`, add one. It is a narrow provider-level assertion.

3. **Migration onUpgrade path** — The 23 skipped integration tests cover this at the device level. The automated suite has no test that exercises the `onUpgrade` callback in isolation. This is acceptable for 08.03; note it in the report as device-verified only.

4. **`kAllQuotes` constant unmodified after local seeded-quote delete** — no automated test currently asserts that deleting a seeded quote from the DB does not mutate `kAllQuotes`. Since `kAllQuotes` is a compile-time constant this cannot regress silently, but document it in the report as a design invariant verified by inspection.

**Step 4 — Commit the verification report:**

Create `vault/ai/docs/sprint2-verification-report.md` with:
- Suite run output (`flutter test` summary)
- AC-to-evidence mapping table (from Step 2)
- Gap findings (from Step 3) and disposition (filled / device-only / invariant)
- Manual device evidence note for the 23 skipped migration/CRUD integration tests

### Affected Areas

| File | Action |
|---|---|
| `test/providers/quote_provider_test.dart` | Audit: add test for `refreshCurrentIfStale()` if absent |
| `test/providers/favorites_provider_test.dart` | Audit: add unit test for `reload()` behavior if absent |
| `vault/ai/docs/sprint2-verification-report.md` | **New** — verification report artifact (required to close Sprint 2) |

### Quality Gates

- `fvm flutter analyze` exits 0 — zero analyzer issues.
- `fvm flutter test --no-pub` exits 0 — 337+ passing, 23 skipped (sqflite platform-channel), 0 failing. The skipped count must not increase.
- Every acceptance criterion in Business Requirements is mapped to a test group or a documented device-verification note in `sprint2-verification-report.md`.
- `sprint2-verification-report.md` exists and is committed before this task is marked done.
- New tests (if any gap fills are needed) must use `mocktail`, not `mockito`. Mock the repository boundary (`QuoteRepositoryBase`), not `QuoteDatabase`.
- No new test may call `flutter_test` async patterns that introduce unchecked `mounted` gaps — any widget test that navigates must use `pumpAndSettle()` before asserting.

### Gotchas

1. **The 23 skipped tests are not failures — do not attempt to un-skip them in this task.** They require a live `sqflite` platform channel. Un-skipping them without `sqflite_common_ffi` in `dev_dependencies` will cause the Dart VM runner to hang waiting for a platform channel that never responds. They are properly documented as device-only integration tests.

2. **`refreshCurrentIfStale` may or may not exist as a named method.** The discovery doc describes the intent; the coder may have implemented it differently (e.g., re-loading via `QuoteProvider.refreshQuote()`). Audit the actual `quote_provider.dart` before writing the test — assert the behavior (stale quote is refreshed), not the method name.

3. **`FavoritesProvider.reload()` coordination is tested through the widget layer in `favorites_screen_test.dart`.** If the unit test gap fill requires spying on `reload()` calls, use a `ChangeNotifier` listener count rather than mocking the provider itself — providers must not be mocked via mocktail in this project (they are not interfaces).
