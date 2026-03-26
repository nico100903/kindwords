---
id: "05.02"
title: "Expand quote CRUD access and catalog state management"
type: feat
priority: high
complexity: M
difficulty: complex
sprint: 2
depends_on: ["05.01"]
blocks: ["06.01", "07.01", "08.03"]
parent: "05"
branch: "feat/task-05-quote-crud-foundation"
assignee: dev
enriched: false
---

# Task 05.02: Expand Quote CRUD Access And Catalog State Management

## Business Requirements

### Problem
Even with a richer quote schema, Sprint 2 cannot deliver browse or form flows until the app exposes local CRUD behavior through reusable quote access and catalog state. KindWords needs one local quote management lane that can load, filter, create, update, and delete quotes consistently across the new CRUD experience.

### User Story
As a user, I want the app's quote collection to respond consistently to local quote changes so that catalog browsing and form actions stay in sync across the app.

### Acceptance Criteria
- [ ] The local quote access layer supports create, read, update, and delete behavior for both seeded and user-created quotes.
- [ ] The quote catalog state layer can load all locally stored quotes and apply an optional source filter plus an optional single-tag filter at the same time.
- [ ] After a local quote update or delete, the app can refresh or replace any currently displayed affected quote instead of leaving stale quote content visible.
- [ ] Local quote access remains fully offline and does not introduce any remote mutation path for seeded or user-created quotes.

### Business Rules
- Source filtering supports exactly three browse options: All, Seeded, and Mine.
- Tag filtering supports one predefined tag at a time while still allowing an optional source filter.
- CRUD state must stay compatible with Sprint 1 random quote behavior and existing favorites identity rules.
- Local quote creation, update, and deletion behavior must operate against the same local quote collection used for browse flows.

### Out of Scope
- Quote catalog screen presentation.
- Quote form create, edit, and delete screen behavior.
- Favorites screen edit/delete integration.

---

## Affected Areas

- Local quote CRUD access behavior
- Quote catalog filtering and refresh state
- Home quote continuity after quote edits or deletes
