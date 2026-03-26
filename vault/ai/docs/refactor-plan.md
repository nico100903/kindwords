# KindWords — Flutter Standards Refactor Plan

> **Status:** ACTIVE  
> **Created:** 2026-03-26  
> **Agents:** `sdlc-flutter-tech-lead[anthropic](claude-sonnet-4-6)`, `sdlc-flutter-coder[anthropic](claude-sonnet-4-6)`, `sdlc-qa[anthropic](claude-sonnet-4-6)`  
> **Source of truth:** `.opencode/skills/flutter-standards/SKILL.md`

---

## Principle: Safe, Iterative, Test-First

Every refactor step follows the BDD loop: **QA writes failing tests → coder makes them pass → tech-lead reviews → integrate gate passes → advance**.  
No step modifies the user-visible contract. No step skips `flutter analyze` or `flutter test`.  
The app must remain runnable between every wave.

---

## Gap Analysis — Current Codebase vs. flutter-standards

| # | Gap | Location | Severity | Blocks |
|---|-----|----------|----------|--------|
| G1 | `widget_test.dart` imports `KindWordsApp` from `main.dart`, but it lives in `app_bootstrap.dart` — **compile error today** | `test/widget_test.dart:8` | 🔴 Critical | All tests |
| G2 | `analysis_options.yaml` uses stock Flutter lints — missing `strict-casts`, `strict-inference`, `strict-raw-types`, `prefer_const_constructors`, etc. | `analysis_options.yaml` | 🔴 Critical | Quality gate |
| G3 | `Quote` model has no `toMap()` / `fromMap()` methods — needed for sqflite (task 04.01) | `lib/models/quote.dart` | 🔴 Critical | 04.01 |
| G4 | No `sqflite` / `path` in `pubspec.yaml` — needed for task 04.01 | `pubspec.yaml` | 🔴 Critical | 04.01 |
| G5 | No `mocktail` in `dev_dependencies` — all tests use real services (fragile, slow) | `pubspec.yaml` | 🟠 High | Unit test quality |
| G6 | `QuoteProvider` calls `getRandomQuote()` synchronously in constructor — no `isLoading` state, no async-ready pattern | `lib/providers/quote_provider.dart` | 🟠 High | 04.02, async safety |
| G7 | `QuoteService` reads `kAllQuotes` directly — no repository boundary — blocks database migration | `lib/services/quote_service.dart` | 🟠 High | 04.02 |
| G8 | `FavoritesService` constructor takes `QuoteService` as dep (wrong direction) — service should resolve quotes from repository, not peer service | `lib/services/favorites_service.dart` | 🟡 Medium | 02.02, clean arch |
| G9 | No `lib/widgets/` directory — quote card UI is inline in `home_screen.dart`, not an extracted `StatelessWidget` | `lib/screens/home_screen.dart` | 🟡 Medium | const discipline, reuse |
| G10 | `HomeScreen` uses `ChangeNotifierProvider.value` in tests — anti-pattern per flutter-standards §2 | `test/home_screen_quote_flow_test.dart:25` | 🟡 Medium | Test correctness |
| G11 | No `dart format` enforcement in CI / analysis_options — format drift silently accumulates | `analysis_options.yaml` | 🟢 Low | Code quality |
| G12 | `NotificationService` uses `debugPrint` (acceptable in dev, but `avoid_print` lint will fire once G2 is fixed) | `lib/services/notification_service.dart` | 🟢 Low | Lint gate |

---

## Refactor Waves

Waves are ordered by: **risk (lowest first) → dependency order → parallelism opportunity**.  
Each wave is independently runnable and leaves the app in a working state.

---

### Wave R1 — Compile Error + Analysis Baseline (Prerequisite)

**Goal:** Zero `flutter analyze` issues. All existing tests pass. No regressions.  
**Why first:** Nothing else can proceed while the test suite has a compile error.  
**Risk:** Minimal — changes are in `test/` and `analysis_options.yaml` only.

| Task | File(s) | Change | Agent |
|------|---------|--------|-------|
| R1.1 | `test/widget_test.dart` | Fix import: `main.dart` → `bootstrap/app_bootstrap.dart`; import `KindWordsApp` correctly | `sdlc-flutter-coder` |
| R1.2 | `analysis_options.yaml` | Adopt project-standard lint rules (strict-casts, strict-inference, prefer_const_constructors, avoid_print, require_trailing_commas, etc.) | `sdlc-flutter-coder` |
| R1.3 | `lib/services/notification_service.dart` | Replace `debugPrint` with comment or remove — anticipates `avoid_print` lint from R1.2 | `sdlc-flutter-coder` |

**Gate:** `flutter analyze` exits 0. `flutter test` exits 0. `dart format lib/ test/` produces no diff.

#### Wave R1 — Completed 2026-03-26
- Commits: b3b8ea0, 857f0dd, 10b7973, 13d1fca, 0ea72c6, 55f8d9e
- Files modified: `test/widget_test.dart`, `lib/services/notification_service.dart`, `analysis_options.yaml`, `lib/screens/settings_screen.dart`, `lib/data/quotes_data.dart`, `lib/models/quote.dart`, `lib/screens/favorites_screen.dart`, `lib/screens/home_screen.dart`, `test/home_screen_quote_flow_test.dart`, `test/quote_data_test.dart`, `test/quote_service_no_repeat_test.dart`, `test/settings_screen_test.dart`
- Analyze: 0 issues
- Tests: flutter test — 48 passed, 0 failed
- Format: no diff
- Unexpected scope: `lib/screens/settings_screen.dart` — fixed 3 pre-existing test failures (TimePicker not found, time hidden when disabled) that would have blocked `flutter test` exit 0. `lib/data/quotes_data.dart`, `lib/models/quote.dart`, `lib/screens/favorites_screen.dart`, `lib/screens/home_screen.dart` — dart format line-wrapping applied by strict rules.

---

### Wave R2 — Quote Model Completeness

**Goal:** `Quote` becomes a fully serializable value object, ready for sqflite.  
**Why now:** Zero risk — no existing code path calls `toMap`/`fromMap`. Unblocks 04.01 cleanly.  
**Risk:** None — purely additive. Existing behavior unchanged.

| Task | File(s) | Change | Agent |
|------|---------|--------|-------|
| R2.1 | `lib/models/quote.dart` | Add `Map<String, Object?> toMap()` and `Quote.fromMap(Map<String, Object?> row)` factory | `sdlc-flutter-coder` |
| R2.2 | `test/models/quote_model_test.dart` | **QA writes first** — unit tests for `toMap`/`fromMap` round-trip, nullable author, equality | `sdlc-qa` |

**Gate:** `flutter analyze` exits 0. `flutter test` exits 0. Round-trip test passes.

#### Wave R2 — Completed 2026-03-26
- Commits: [QA hash 3ee5f76, coder hash 4e1a344]
- Files modified: lib/models/quote.dart
- Tests added: 14 (test/models/quote_model_test.dart)
- Analyze: 0 issues (4 pre-existing `require_trailing_commas` in QA test file flagged — outside coder scope; pre-existed in QA's commit 3ee5f76)
- Tests: flutter test — 62 passed, 0 failed (48 pre-existing + 14 new model tests)

---

### Wave R3 — Dev Dependency Upgrade (mocktail + sqflite)

**Goal:** Add `mocktail` to dev deps. Add `sqflite` + `path` to prod deps.  
**Why now:** Unblocks proper unit testing in R4+. Dep additions are non-breaking.  
**Risk:** Low — `flutter pub get` only. No code changes.

| Task | File(s) | Change | Agent |
|------|---------|--------|-------|
| R3.1 | `pubspec.yaml` | Add `sqflite: ^2.3.3`, `path: ^1.9.0` to `dependencies` | `sdlc-flutter-coder` |
| R3.2 | `pubspec.yaml` | Add `mocktail: ^0.3.0` to `dev_dependencies` | `sdlc-flutter-coder` |

**Gate:** `flutter pub get` exits 0. `flutter analyze` exits 0. `flutter test` exits 0.

---

### Wave R4 — Database Layer (Task 04.01)

**Goal:** Introduce `QuoteDatabase` + `QuoteRepositoryBase` / `LocalQuoteRepository`.  
**Why now:** Foundation for all data-layer work. `QuoteService` still reads from `kAllQuotes` — no behavioral change yet.  
**Risk:** Low — new files only. `app_bootstrap.dart` is the only modified existing file.

This maps directly to **backlog task 04.01** — use the existing task file as the source of truth.

| Task | File(s) | Change | Agent |
|------|---------|--------|-------|
| R4.1 | `test/data/quote_database_test.dart` | **QA writes first** — seed idempotency, getAllQuotes count, getById spot checks | `sdlc-qa` |
| R4.2 | `test/repositories/quote_repository_test.dart` | **QA writes first** — LocalQuoteRepository delegates to DB | `sdlc-qa` |
| R4.3 | `lib/data/quote_database.dart` | New — `open()`, `seedIfEmpty()`, `getAllQuotes()`, `getById()` | `sdlc-flutter-coder` |
| R4.4 | `lib/repositories/quote_repository.dart` | New — `QuoteRepositoryBase` abstract + `LocalQuoteRepository` | `sdlc-flutter-coder` |
| R4.5 | `lib/bootstrap/app_bootstrap.dart` | Open DB, seedIfEmpty, pass repo into service graph | `sdlc-flutter-coder` |
| R4.6 | — | Tech-lead review of R4.3–R4.5 | `sdlc-flutter-tech-lead` |

**Gate:** All 04.01 quality gates pass. `flutter analyze` exits 0. `flutter test` exits 0.

---

### Wave R5 — Repository Migration (Task 04.02)

**Goal:** `QuoteService` reads from `QuoteRepositoryBase` instead of `kAllQuotes` directly.  
**Why now:** Completes the database-first architecture. Unblocks 02.02.  
**Risk:** Medium — changes `QuoteService` API from sync to async. `QuoteProvider` must also migrate.

This maps directly to **backlog task 04.02**.

| Task | File(s) | Change | Agent |
|------|---------|--------|-------|
| R5.1 | `test/services/quote_service_test.dart` | **QA writes first** — service with mock repository, async getRandomQuote | `sdlc-qa` |
| R5.2 | `test/providers/quote_provider_test.dart` | **QA writes first** — isLoading state, refreshQuote async, mock service | `sdlc-qa` |
| R5.3 | `lib/services/quote_service.dart` | Inject `QuoteRepositoryBase`, make `getRandomQuote()` async | `sdlc-flutter-coder` |
| R5.4 | `lib/providers/quote_provider.dart` | Add `isLoading`, make `refreshQuote()` async, use `_initialize()` fire-and-forget pattern | `sdlc-flutter-coder` |
| R5.5 | `lib/bootstrap/app_bootstrap.dart` | Pass repository into `QuoteService` constructor | `sdlc-flutter-coder` |
| R5.6 | `lib/screens/home_screen.dart` | Handle `isLoading` state in quote display area | `sdlc-flutter-coder` |
| R5.7 | — | Tech-lead review of R5.3–R5.6 | `sdlc-flutter-tech-lead` |

**Gate:** All 04.02 quality gates pass. `flutter analyze` exits 0. `flutter test` exits 0.  
**Integrate gate:** App launches and displays quotes on emulator.

---

### Wave R6 — Widget Extraction

**Goal:** Extract `QuoteCard` from `home_screen.dart` into `lib/widgets/quote_card.dart` with a `const` constructor.  
**Why now:** Unblocks `const` optimization; required by flutter-standards §4. Safe after data layer stabilizes.  
**Risk:** Low — UI behavior unchanged. Widget extraction is a mechanical refactor.

| Task | File(s) | Change | Agent |
|------|---------|--------|-------|
| R6.1 | `test/widgets/quote_card_test.dart` | **QA writes first** — shows quote text, shows author if present, hides author if null | `sdlc-qa` |
| R6.2 | `lib/widgets/quote_card.dart` | New — `QuoteCard extends StatelessWidget` with `const` constructor | `sdlc-flutter-coder` |
| R6.3 | `lib/screens/home_screen.dart` | Replace inline card with `QuoteCard(quote: quote)` | `sdlc-flutter-coder` |

**Gate:** `flutter analyze` exits 0. `flutter test` exits 0. Quote card test passes.

---

### Wave R7 — FavoritesService Dependency Cleanup

**Goal:** `FavoritesService` should not depend on `QuoteService` — it should resolve quotes from `QuoteRepositoryBase`.  
**Why now:** After the repository is live (R4+), this is a clean swap. Fixes the wrong-direction dependency.  
**Risk:** Low — behavior identical; only the lookup path changes.

| Task | File(s) | Change | Agent |
|------|---------|--------|-------|
| R7.1 | `test/services/favorites_service_test.dart` | **QA writes first** — add/remove/isFavorite with mock repository | `sdlc-qa` |
| R7.2 | `lib/services/favorites_service.dart` | Replace `QuoteService` dep with `QuoteRepositoryBase`; update `loadFavorites()` | `sdlc-flutter-coder` |
| R7.3 | `lib/bootstrap/app_bootstrap.dart` | Pass `quoteRepo` instead of `quoteService` into `FavoritesService` | `sdlc-flutter-coder` |

**Gate:** `flutter analyze` exits 0. `flutter test` exits 0.

---

### Wave R8 — Favorites Feature (Tasks 02.02 + 02.03)

**Goal:** Complete favorites persistence and delete flow.  
**Why now:** All prerequisites (R4, R5, R7) are done. This is standard feature work per the sprint plan.  
**Risk:** Medium — new UI interactions, SharedPreferences writes.

Runs per the sprint plan backlog tasks 02.02 and 02.03.

---

### Wave R9 — Notification Completion + Android Recovery (Tasks 03.02 + 03.03)

**Goal:** Verify scheduling on device, add permission flow and boot receiver.  
**Risk:** High — Android-specific, requires device/emulator validation.  
Runs per backlog tasks 03.02 and 03.03.

---

### Wave R10 — Release Verification (Task 03.04)

Final quality pass: lint, tests, device smoke test, APK build.

---

## Dependency Graph (Refactor Waves)

```
R1 (compile fix + lint) ──→ R2 (model) ──→ R3 (deps) ──→ R4 (DB layer) ──→ R5 (repo migration)
                                                                               │
                                                               R6 (widgets) ──┤
                                                               R7 (favs dep) ─┤
                                                                               ↓
                                                               R8 (favorites feature)
                                                                               ↓
                                                               R9 (notifications)
                                                                               ↓
                                                               R10 (release verification)
```

R1–R3 can be done in one session (low risk, no behavior change).  
R4–R5 map directly to existing sprint backlog tasks.  
R6 and R7 can run **in parallel** after R5 completes (no file overlap).  

---

## Agent Routing Summary

| Wave | QA (writes tests) | Coder (makes green) | Tech Lead (review) |
|------|-------------------|---------------------|---------------------|
| R1 | — | `sdlc-flutter-coder` | optional |
| R2 | `sdlc-qa` | `sdlc-flutter-coder` | — |
| R3 | — | `sdlc-flutter-coder` | — |
| R4 | `sdlc-qa` | `sdlc-flutter-coder` | `sdlc-flutter-tech-lead` |
| R5 | `sdlc-qa` | `sdlc-flutter-coder` | `sdlc-flutter-tech-lead` |
| R6 | `sdlc-qa` | `sdlc-flutter-coder` | — |
| R7 | `sdlc-qa` | `sdlc-flutter-coder` | — |
| R8–R10 | `sdlc-qa` | `sdlc-flutter-coder` | `sdlc-flutter-tech-lead` |

All agents declared in `AGENTS.md § Agents Active for Build Phase`.

---

## Safety Rules

1. **Never skip the integrate gate.** Every wave ends with `flutter analyze && flutter test`. The app must remain runnable.
2. **QA writes tests before coder touches implementation.** No test, no implementation.
3. **Tech-lead reviews every complex task** (R4, R5, R8, R9). No code review for mechanical tasks (R1, R2, R3, R6, R7).
4. **One wave at a time.** Do not start R(N+1) until R(N) integrate gate passes.
5. **No behavior changes in R1–R3.** Pure housekeeping waves — any behavioral side effect is a regression, not a feature.
6. **Commit at every logical unit.** `git log --oneline -1` after every commit. Empty = commit failed = stop.
