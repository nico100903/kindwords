---
id: "01.04"
title: "Connect random quote flow"
type: feat
priority: high
complexity: M
difficulty: routine
sprint: 3
depends_on: ["01.02", "01.03"]
blocks: ["02", "02.02", "03", "03.04"]
parent: "01"
branch: "feat/task-01-core-app-shell-and-quote-experience"
assignee: dev
enriched: true
---

# Task 01.04: Connect Random Quote Flow

## Business Requirements

### Problem
The home screen only becomes valuable when the main action actually changes the quote in a satisfying way. Users must be able to request another motivational message without seeing an immediate repeat or a jarring state change.

### User Story
As a user, I want the motivation button to show a different quote with a lightweight transition so that the interaction feels responsive and intentional.

### Acceptance Criteria
- [ ] Tapping the motivation action replaces the current quote with a different quote whenever more than one quote exists.
- [ ] The newly shown quote appears with a visible fade or slide-style transition.
- [ ] The interaction completes without internet access.
- [ ] Repeating the action 10 times in a row never shows the same quote twice consecutively when the catalog contains more than one entry.

### Business Rules
- Immediate repeats are not allowed when two or more quotes exist.
- The quote transition must be lightweight and complete quickly enough to keep the interaction feeling instant.
- The first shown quote still counts as part of the same browsing experience.

### Out of Scope
- Saving or unsaving favorites.
- Notification content scheduling.
- Category filtering or history view.

---
<!-- TECHNICAL GUIDANCE - written by Tech Lead below this line -->
<!-- Do not modify Business Requirements when enriching -->

## Architecture Notes

**Axis:** UI state lifecycle — making state changes visible through animation without disrupting Flutter's declarative model.

**Pattern:** `AnimatedSwitcher` for quote card transitions. This is the idiomatic Flutter pattern for animating between children that change. It's declarative, built-in, and requires minimal code compared to explicit `AnimationController` setups.

**Rationale:**
- `AnimatedSwitcher` detects child changes via key equality and automatically runs the specified transition.
- The `Quote` model already implements `==` and `hashCode` based on `id`, enabling reliable keying via `ValueKey(quote.id)`.
- `QuoteProvider.refreshQuote()` already exists and calls `notifyListeners()` — no provider changes needed.
- `QuoteService.getRandomQuote(currentId:)` already implements no-immediate-repeat filtering — no service changes needed.

**Implementation Approach:**
1. Wire `ElevatedButton.onPressed` to `context.read<QuoteProvider>().refreshQuote()`.
2. Wrap the quote `Card` widget in `AnimatedSwitcher` with `duration: Duration(milliseconds: 300)` and a `FadeTransition` or `SlideTransition` via the `transitionBuilder`.
3. Add `key: ValueKey(quote.id)` to the inner card so `AnimatedSwitcher` detects the change and triggers the animation.

**Constraints:**
- Animation must complete in ≤300ms to meet "instant" feel requirement.
- No network calls — all data is local and offline-first.

## Affected Areas

- `lib/screens/home_screen.dart` — add animation wrapper, wire button callback.
- `lib/providers/quote_provider.dart` — no changes required (already has `refreshQuote()`).
- `lib/services/quote_service.dart` — no changes required (already handles no-repeat).
- `lib/models/quote.dart` — no changes required (already keyable via `id`).

## Quality Gates

- [ ] Tapping "New Quote" button 10 times produces 10 different quotes (no consecutive repeats).
- [ ] Quote change includes a visible fade or slide transition.
- [ ] Animation completes in ≤300ms (visual inspection or `timeDilation` test at 5x).
- [ ] `flutter analyze` returns no issues.
- [ ] App works in airplane mode (no network dependency).

## Gotchas

- **Consumer placement:** The `Consumer<QuoteProvider>` must wrap the `AnimatedSwitcher`, not just the inner content, so rebuilds trigger the animation. If `Consumer` is inside `AnimatedSwitcher`, the key change won't be detected correctly.
- **Button disabled state:** Current `onPressed: null` makes the button visually disabled (greyed out). Once wired, verify the button uses the theme's primary color (`Colors.deepPurple`) correctly.

---
<!-- COMPLETION - appended after verification -->

## Changes
- `lib/screens/home_screen.dart` - modified
- `test/home_screen_quote_flow_test.dart` - new
- `test/quote_service_no_repeat_test.dart` - new
