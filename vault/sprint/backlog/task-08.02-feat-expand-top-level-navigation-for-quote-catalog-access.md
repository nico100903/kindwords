---
id: "08.02"
title: "Expand top-level navigation for quote catalog access"
type: feat
priority: high
complexity: S
difficulty: routine
sprint: 6
depends_on: ["06.01"]
blocks: ["08.03"]
parent: "08"
branch: "feat/task-08-quote-integration"
assignee: dev
enriched: true
---

# Task 08.02: Expand Top-Level Navigation For Quote Catalog Access

## Business Requirements

### Problem
The Quote Catalog cannot become a real top-level product feature unless the user can reach it from the same navigation surface as Home, Favorites, and Settings. KindWords needs a navigation update that exposes the Quotes destination without weakening the existing app shell.

### User Story
As a user, I want Quotes to appear in primary navigation so that I can move directly between the main app areas without hidden entry points.

### Acceptance Criteria
- [ ] The app's bottom navigation shows four top-level tabs: Home, Quotes, Favorites, and Settings.
- [ ] Selecting the Quotes tab opens the Quote Catalog screen.
- [ ] The existing Home, Favorites, and Settings destinations remain reachable after the navigation update.
- [ ] The navigation update does not regress the current random quote journey or settings access.

### Business Rules
- Quotes is a top-level destination, not a secondary overflow action.
- Navigation labels should clearly match the app areas they open.
- Navigation changes stay within the existing offline app shell.

### Out of Scope
- Quote catalog screen content changes.
- Quote form behavior.
- Favorites edit and delete behavior.

---

## Technical Guidance

### Architecture Notes

**Decisive axis:** Navigation shell restructuring — inserting a tab into an existing push-based `BottomNavigationBar` while preserving the current push-and-reset idiom used for all non-Home tabs.

**Current shell pattern (must be understood before touching anything):**
`HomeScreen._onNavItemTapped` dispatches with `Navigator.pushNamed` for cases 1 and 2, then immediately resets `_selectedIndex = 0`. This means every non-Home tab is a pushed modal-style route that returns to Home on back-press. The `BottomNavigationBar` does not maintain persistent tab state — it is a visual affordance layered over route pushes.

**Change required:**
- `BottomNavigationBar` expands from 3 to 4 `BottomNavigationBarItem` entries in the fixed order: `Home (0)`, `Quotes (1)`, `Favorites (2)`, `Settings (3)`.
- `_onNavItemTapped` gains a `case 1:` for `/quotes`, shifting the existing Favorites and Settings to `case 2:` and `case 3:` respectively.
- No change to the push-and-reset pattern itself — the same mechanics used for `/favorites` and `/settings` apply identically to `/quotes`.

**Option comparison:**
- Option A: Push-based tab (same pattern as Favorites/Settings) — new case pushes `/quotes`, resets index to 0. Zero architecture change; consistent with existing idiom.
- Option B: Persistent tab host (`IndexedStack` / `Navigator` per tab) — eliminates back-button weirdness but requires extracting `HomeScreen` body logic from its current `Scaffold`, wiring a shared `Scaffold` around four subtrees, and verifying that `QuoteCatalogProvider.load()` still fires correctly. Significant scope expansion.

**Chosen: Option A.** The push-and-reset idiom is already established and working for two tabs. Introducing a third push destination is one `case` in a `switch`. Accepting the constraint that the bottom bar tab highlight immediately snaps back to Home after navigation — this is the existing behavior and regression-free. Option B would be the right refactor in a larger project or if index persistence were an explicit acceptance criterion, but neither is true here.

**Constraint created for downstream tasks:** `08.03` regression verification must explicitly test that the tab index returns to 0 after navigating to Quotes and pressing back — this is expected behavior, not a bug.

**Icon specification (from `sprint-crud-quotes-ui.md` §Updated Bottom Navigation):**
- Tab 1 Quotes: `Icons.format_quote_outlined` (inactive), `Icons.format_quote` (active)
- Tab 2 Favorites: `Icons.favorite_outline` (inactive), `Icons.favorite` (active) — no change from current index 1
- Tab 3 Settings: `Icons.settings_outlined` (inactive), `Icons.settings` (active) — no change from current index 2

The `/quotes` route is already registered in `KindWordsApp.routes` in `app_bootstrap.dart` (line 82). No route registration work is needed.

---

### Affected Areas

| File | Change type | Notes |
|------|------------|-------|
| `lib/screens/home_screen.dart` | modify | Add `BottomNavigationBarItem` for Quotes at index 1; insert `case 1:` in `_onNavItemTapped` to push `/quotes`; shift Favorites to `case 2:` and Settings to `case 3:` |
| `CHANGELOG.md` | modify | Add one entry under `## [Unreleased]` for this user-visible navigation change |

No other files require modification. `app_bootstrap.dart` already registers `/quotes`. `QuoteCatalogScreen` already exists. `QuoteCatalogProvider` is already in the `MultiProvider` tree.

---

### Quality Gates

1. `flutter analyze` exits 0 — zero issues (required before task is done).
2. `flutter test` exits 0 — zero failures (required before task is done).
3. `CHANGELOG.md` has exactly one new entry under `## [Unreleased]` describing the navigation addition.
4. **Behavioral assertion — tab count:** the rendered `BottomNavigationBar` has exactly 4 items with labels `Home`, `Quotes`, `Favorites`, `Settings` in that order.
5. **Behavioral assertion — Quotes reachable:** tapping the Quotes tab navigates to `QuoteCatalogScreen` (verifiable via widget test: `expect(find.byType(QuoteCatalogScreen), findsOneWidget)` after tap).
6. **Behavioral assertion — existing tabs unregressed:** tapping Favorites still navigates to `FavoritesScreen`; tapping Settings still navigates to `SettingsScreen`.
7. **Behavioral assertion — index reset:** after navigation to any non-Home tab, `_selectedIndex` resets to 0 (Home highlighted) — this is the established behavior and must be preserved, not fixed.
8. `dart format lib/ test/` produces no diff.

---

### Gotchas

1. **Index shift breaks existing Favorites and Settings cases.** The current switch has `case 1: /favorites` and `case 2: /settings`. After inserting Quotes at index 1, these become `case 2:` and `case 3:` respectively. Failing to update them causes tapping Favorites to navigate to `/quotes` and tapping Settings to navigate to `/favorites` — a silent misbehavior with no analyzer warning.

2. **`_selectedIndex` reset is load-bearing, not a bug.** The current nav resets to 0 after every push because `HomeScreen` is always the live route in the navigator stack — the pushed route is on top of it. Any test that asserts the Quotes tab stays highlighted after navigation will falsely fail if it misunderstands this idiom. Preserve `setState(() { _selectedIndex = 0; })` in every non-Home case.

3. **`QuoteCatalogProvider.load()` fires on `initState` via `addPostFrameCallback`.** Because `/quotes` is a pushed route that is re-built on every fresh push, `load()` is called each time the Quotes tab is tapped. This is safe (the provider handles the call idempotently via `_loadTriggered`), but the coder must not try to "fix" this by moving `load()` to the bootstrap — catalog freshness depends on the per-visit trigger.
