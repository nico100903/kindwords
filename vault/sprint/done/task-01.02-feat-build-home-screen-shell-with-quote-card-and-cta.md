---
id: "01.02"
title: "Build home screen shell with quote card and CTA"
type: feat
priority: high
complexity: M
difficulty: routine
sprint: 1
depends_on: []
blocks: ["01.04"]
parent: "01"
branch: "feat/task-01-core-app-shell-and-quote-experience"
assignee: dev
enriched: true
---

# Task 01.02: Build Home Screen Shell With Quote Card And CTA

## Business Requirements

### Problem
Users need a clear, focused first screen that immediately communicates the app's purpose. Without a visible quote presentation area and primary motivation action, the product's main value is unclear.

### User Story
As a user, I want a simple home screen with a readable quote area and a clear button so that I instantly understand how to use the app.

### Acceptance Criteria
- [ ] The home screen shows a quote display area immediately when the user lands on it.
- [ ] A primary action labeled for motivation retrieval is prominently visible without scrolling on a typical Android phone.
- [ ] The screen includes visible entry points to favorites and settings.
- [ ] Quote text remains readable with wrapping that avoids horizontal overflow on small and medium phone widths.

### Business Rules
- The primary call to action must be visible on first view.
- The home destination must include one quote display area, one primary motivation action, and two secondary navigation actions.
- Readability must be preserved for quotes up to 220 characters.

### Out of Scope
- Random quote replacement behavior.
- Quote-change animation behavior.
- Saving a quote to favorites.

---
<!-- TECHNICAL GUIDANCE - written by Tech Lead below this line -->
<!-- Do not modify Business Requirements when enriching -->

## Architecture Notes

- **Screen file:** Create `lib/screens/home_screen.dart` as a `StatelessWidget` that displays the quote card and CTA. Provider integration will come from 01.01; until `QuoteProvider` exists, use a static placeholder `Quote` from `kAllQuotes[0]`.
- **Layout structure:** Use `Scaffold` with a `Column` body (not `ListView`) to ensure CTA remains visible without scrolling. Quote card in an `Expanded` area, CTA button fixed at bottom above navigation.
- **Quote card:** Wrap quote text in a `Card` with `Padding`. Use `Text` with `maxLines: null` and `overflow: TextOverflow.visible`. Set `textAlign: TextAlign.center`. The card must flex to fill available vertical space.
- **Navigation pattern:** Use `BottomNavigationBar` with three items (Home, Favorites, Settings). Home is selected by default. Navigation callbacks should route to placeholder widgets for Favorites and Settings screens (these will be built in later tasks).
- **CTA button:** `ElevatedButton` centered horizontally with semantic label. Use Material 3 styling via `Theme.of(context).colorScheme`. Button must be visible on a 360dp-wide device without scrolling.
- **Provider pattern (when available):** Wrap quote display in `Consumer<QuoteProvider>` once 01.01 is merged. Until then, direct access to `QuoteService` or static placeholder is acceptable.

## Affected Areas

- `lib/screens/home_screen.dart` — **NEW FILE** (primary deliverable)
- `lib/screens/favorites_screen.dart` — **NEW FILE** (placeholder stub only)
- `lib/screens/settings_screen.dart` — **NEW FILE** (placeholder stub only)
- `lib/main.dart` — may need navigation route registration if 01.01 not yet merged

## Quality Gates

- `flutter analyze` returns no errors or warnings
- `flutter test` passes (if widget tests exist for this task)
- Home screen renders on Android emulator at 360×640dp with all elements visible (no scrolling required)
- Quote text of 220 characters wraps correctly with no horizontal overflow
- CTA button has minimum tap target of 48×48dp

## Gotchas

- **Parallel task dependency:** 01.01 (provider wiring) runs in parallel. If `QuoteProvider` does not exist when this task runs, use a static placeholder quote from `kAllQuotes[0]`. Do not block on 01.01 completion.
- **Text overflow:** Test with the longest expected quote (220 chars). Use `FittedBox` or dynamic font sizing only if wrapping alone fails on narrow screens — prefer simple wrapping first.
- **Navigation stubs:** Favorites and Settings screens are placeholder containers only. They should be empty `Scaffold` widgets with a title — no business logic.

---
<!-- COMPLETION - appended after verification -->

## Changes
- `lib/screens/home_screen.dart` - modified
- `test/widget_test.dart` - modified
