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
enriched: false
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

## Affected Areas

- Primary navigation structure
- Route access to the Quotes destination
- Compatibility of existing top-level app areas
