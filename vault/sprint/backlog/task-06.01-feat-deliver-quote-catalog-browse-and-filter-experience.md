---
id: "06.01"
title: "Deliver quote catalog browse and filter experience"
type: feat
priority: high
complexity: M
difficulty: moderate
sprint: 3
depends_on: ["05.02"]
blocks: ["07.01", "08.02"]
parent: "06"
branch: "feat/task-06-quote-catalog-browse"
assignee: dev
enriched: false
---

# Task 06.01: Deliver Quote Catalog Browse And Filter Experience

## Business Requirements

### Problem
Sprint 1 lets the user see only one random quote at a time, which does not satisfy the new browse and read requirements. KindWords needs a dedicated catalog view so the user can inspect the full local collection and choose where to create, edit, or delete quotes.

### User Story
As a user, I want a Quotes screen that shows my full local collection with filters so that I can browse and manage quotes intentionally instead of only through random refreshes.

### Acceptance Criteria
- [ ] The app provides a Quote Catalog screen that lists all quotes currently stored in the local database.
- [ ] Each visible catalog item shows the quote text, author or anonymous fallback, source indicator, and visible tags when tags exist.
- [ ] The catalog supports source filtering with All, Seeded, and Mine options and tag filtering by one predefined tag at a time while keeping any active source filter.
- [ ] When no quotes match the active filters, the catalog shows a clear empty-filter state with a way to clear the active filters.
- [ ] The catalog visibly exposes create, edit, and delete entry points from the screen even if later tasks complete the form behaviors.

### Business Rules
- The catalog shows both `seeded` and `userCreated` quotes in one collection.
- Empty-filter feedback must be distinct from the unlikely no-quotes-at-all state.
- Tag display uses only predefined tags already supported by the quote record.
- Browse behavior must remain fully local and offline.

### Out of Scope
- Saving a new quote.
- Updating or deleting a quote from the form.
- Favorites screen CRUD entry points.

---

## Affected Areas

- Top-level quote browsing experience
- Source and tag filter behavior
- Empty-state and CRUD entry-point visibility
