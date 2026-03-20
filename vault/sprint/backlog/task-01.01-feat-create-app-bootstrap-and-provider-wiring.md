---
id: "01.01"
title: "Create app bootstrap and provider wiring"
type: feat
priority: high
complexity: M
difficulty: moderate
sprint: 1
depends_on: []
blocks: ["01.03", "02.01", "03.01"]
parent: "01"
branch: "feat/task-01-core-app-shell-and-quote-experience"
assignee: dev
enriched: true
---

# Task 01.01: Create App Bootstrap And Provider Wiring

## Business Requirements

### Problem
The project cannot enter feature implementation until users can open a real app shell and the state needed by future screens is wired at startup. This task establishes the minimum runnable structure that later quote, favorites, and settings work can attach to without rework.

### User Story
As a user, I want the app to launch into a stable shell so that later features appear in a consistent and predictable experience.

### Acceptance Criteria
- [ ] Launching the app opens a branded home destination instead of a placeholder or error state.
- [ ] The app shell exposes navigation paths for the main motivation experience, favorites, and settings.
- [ ] Shared app state for the current quote and saved favorites is available when the app starts.
- [ ] App startup completes without requiring internet access, account setup, or remote configuration.

### Business Rules
- The app must remain fully offline at startup.
- The initial app shell must support exactly three user destinations: home, favorites, and settings.
- Startup setup must be reusable by later feature tasks without changing the user-facing navigation model.

### Out of Scope
- Final home screen polish and quote-change animation.
- Favorites save and delete behavior.
- Notification scheduling logic and Android permission prompts.

---
<!-- TECHNICAL GUIDANCE - written by Tech Lead below this line -->
<!-- Do not modify Business Requirements when enriching -->

## Architecture Notes

- **Provider hierarchy:** Use `MultiProvider` at app root in `main.dart`. Order matters: `QuoteProvider` first (no deps), then `FavoritesProvider` (depends on `FavoritesService` + `QuoteService`).
- **Async initialization:** Both providers need async init. Use `ChangeNotifierProxyProvider` pattern or initialize services in `main()` before `runApp()` and pass to providers.
- **Screen shells only:** This task creates screen scaffolds with AppBar and navigation — NOT full UI. HomeScreen shows placeholder quote text; FavoritesScreen shows empty state; SettingsScreen shows "Coming soon" label.
- **Navigation:** Use named routes (`/`, `/favorites`, `/settings`) with `Navigator.pushNamed`. HomeScreen AppBar includes icons that navigate to favorites and settings.
- **Notification init:** `NotificationService.initialize()` must run in `main()` before `runApp()` to ensure timezone DB and channel are ready.
- **QuoteProvider init:** Provider must call `QuoteService.getRandomQuote()` in constructor or `initState` equivalent — current quote should never be null.

## Affected Areas

- `lib/main.dart` — NEW: App entry, Provider tree, NotificationService init
- `lib/providers/quote_provider.dart` — NEW: Current quote state + refresh method
- `lib/providers/favorites_provider.dart` — NEW: Favorites list + add/remove/toggle
- `lib/screens/home_screen.dart` — NEW: Shell with AppBar, placeholder quote, nav icons
- `lib/screens/favorites_screen.dart` — NEW: Shell with empty state text
- `lib/screens/settings_screen.dart` — NEW: Shell with "Coming soon" placeholder

## Quality Gates

- [ ] `flutter analyze` passes with 0 errors
- [ ] `flutter run` launches app on Android emulator without crash
- [ ] App shows HomeScreen as default route with visible title "KindWords"
- [ ] AppBar favorites icon navigates to `/favorites` screen
- [ ] AppBar settings icon navigates to `/settings` screen
- [ ] Back navigation from favorites/settings returns to home
- [ ] `QuoteProvider` exposes non-null `currentQuote` after app start
- [ ] `FavoritesProvider` exposes empty list by default (no crash on async load)

## Gotchas

- **SharedPreferences async:** `FavoritesService.loadFavorites()` is async. `FavoritesProvider` must handle this — either load in `main()` and await before `runApp()`, or use `FutureProvider` pattern with loading state.
- **Circular deps:** `FavoritesService` constructor requires `QuoteService`. Instantiate services in `main()` in order: `QuoteService` → `FavoritesService` → `NotificationService`.
- **Provider access in screens:** Use `Provider.of<T>(context, listen: false)` for actions, `Consumer<T>` or `context.watch<T>()` for UI rebuilds. Do NOT store provider references in StatefulWidget fields.
- **No network code:** Ensure no http imports or network calls exist anywhere. This app is strictly offline.
