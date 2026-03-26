---
id: "02.01"
title: "Create favorites provider and screen shell"
type: feat
priority: high
complexity: M
difficulty: routine
sprint: 2
depends_on: ["01.01"]
blocks: ["02.02", "02.03"]
parent: "02"
branch: "feat/task-02-favorites-experience"
assignee: dev
enriched: true
---

# Task 02.01: Create Favorites Provider And Screen Shell

## Business Requirements

### Problem
Users need a destination for saved content before favorites behavior can feel complete. The app also needs a single source of state for favorites so later save, load, and delete actions behave consistently.

### User Story
As a user, I want a dedicated favorites destination so that I know where my saved quotes will appear.

### Acceptance Criteria
- [ ] The app exposes a favorites destination reachable from the main experience.
- [ ] Opening the favorites destination shows a valid screen instead of a placeholder crash or dead route.
- [ ] Favorites state is available to screens that need to display or react to saved items.
- [ ] The favorites destination reserves space for both a saved-items list state and an empty state.

### Business Rules
- Favorites must remain part of the main app navigation, not a hidden debug-only route.
- The favorites destination must support both zero-item and many-item states.
- Favorites state must be shareable across the home and favorites experiences.

### Out of Scope
- Persisting favorites to storage.
- Duplicate-prevention logic.
- Delete behavior from the list.

---
<!-- TECHNICAL GUIDANCE - written by Tech Lead below this line -->
<!-- Do not modify Business Requirements when enriching -->

## Architecture Notes

**Axis:** State exposure + navigation integration. This task ensures favorites state is reachable and consumable across screens, not the persistence or CRUD behavior.

**Current State (pre-enriched):** The codebase already has:
- `FavoritesProvider` with `favorites`, `isLoading`, `isFavorite()`, `toggleFavorite()` exposed
- `FavoritesScreen` with empty-state and list layout regions
- Provider registered in `main.dart` MultiProvider tree
- `/favorites` route wired

**Pattern:** Provider-as-single-source-of-truth. `FavoritesProvider` owns the favorites list; screens consume via `Consumer<FavoritesProvider>` or `context.watch<FavoritesProvider>()`. No direct `FavoritesService` calls from UI.

**DO:** Verify the provider is accessible from both `HomeScreen` and `FavoritesScreen` via the widget tree. The provider must be reachable for later save/toggle behavior.

**AVOID:** Adding save-to-favorites button on `HomeScreen` — that's task 02.02/02.03 scope. This task only ensures the state is *exposed*, not that it's *mutated* from home.

**Boundary Clarification:** `FavoritesScreen` currently has list/delete UI code present. For 02.01 acceptance, focus on:
1. Empty state renders correctly when `favorites.isEmpty`
2. List region exists and is reachable (even if list items are placeholder)
3. Provider `isLoading` state is handled in UI

The full list/delete behavior verification belongs to task 02.03 acceptance.

## Affected Areas

- `lib/providers/favorites_provider.dart` — verify state exposure (already implemented)
- `lib/screens/favorites_screen.dart` — verify shell renders, both states reserved
- `lib/main.dart` — verify provider registration and route (already implemented)
- `lib/screens/home_screen.dart` — verify navigation to `/favorites` works (already implemented)

## Quality Gates

1. **Navigation gate:** Tap favorites nav item → `FavoritesScreen` renders without crash
2. **Empty state gate:** With zero favorites → screen shows "No favorites yet" message
3. **Loading state gate:** On cold start → `CircularProgressIndicator` shows while `isLoading == true`
4. **Provider accessibility gate:** `FavoritesProvider` is non-null when accessed via `Provider.of<FavoritesProvider>(context, listen: false)` from `HomeScreen` build context
5. **Lint gate:** `flutter analyze` passes with zero errors

## Gotchas

1. **Async load timing:** `FavoritesProvider` loads favorites asynchronously in constructor. UI must handle `isLoading == true` on first frame — if you remove the loading check, the list may flash empty before data arrives.

2. **Scope creep in screen file:** The current `FavoritesScreen` has delete button code. Don't add more list/delete features during 02.01 — that's 02.03. If you find bugs in the existing list/delete code, note them but don't expand scope to fix unless they block the shell acceptance.

3. **Provider not accessible from HomeScreen:** If `HomeScreen` can't reach `FavoritesProvider` via `Consumer` or `context.watch`, check that `HomeScreen` is a descendant of `MultiProvider` in the widget tree. It is (via `MaterialApp` → `routes` → `HomeScreen`), but nested navigators or route generators can break this.

4. **Don't add persistence logic here:** `FavoritesService` already handles `shared_preferences`. Task 02.02 owns the "save from home screen" wiring. This task just ensures the provider exposes state correctly.
