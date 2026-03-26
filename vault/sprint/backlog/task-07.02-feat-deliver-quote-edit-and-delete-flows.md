---
id: "07.02"
title: "Deliver quote edit and delete flows"
type: feat
priority: high
complexity: M
difficulty: complex
sprint: 5
depends_on: ["07.01"]
blocks: ["08.01", "08.03"]
parent: "07"
branch: "feat/task-07-quote-form-flows"
assignee: dev
enriched: false
---

# Task 07.02: Deliver Quote Edit And Delete Flows

## Business Requirements

### Problem
The quote CRUD update is incomplete unless the user can revise or remove any local quote after it exists. KindWords needs edit and delete flows that work for both seeded and user-created quotes while preserving quote identity, confirmation safety, and local-only mutation rules.

### User Story
As a user, I want to edit or delete any quote in my local collection so that the app reflects the collection I actually want to keep on my device.

### Acceptance Criteria
- [ ] The Quote Form supports edit mode with pre-populated values for the selected quote.
- [ ] The user can update quote text, optional author, and tags for both seeded and user-created quotes.
- [ ] Updating a quote preserves the original `id`, preserves the original `createdAt`, and sets `updatedAt` to the local edit time.
- [ ] The user can start quote deletion from both the Quote Catalog and the Quote Form in edit mode.
- [ ] Any quote deletion requires confirmation before the quote is removed from the local database.
- [ ] Editing or deleting a seeded quote changes only the local database representation and does not imply bundled-catalog mutation or any remote propagation.

### Business Rules
- Edit access applies equally to seeded and user-created quotes in this release.
- Delete behavior removes the selected quote from the device-local collection only.
- Destructive actions must remain explicitly confirmed before completion.
- After save or delete, the quote collection should no longer show stale data for the affected quote.

### Out of Scope
- Favorites screen-specific edit and delete entry points.
- Bottom navigation changes.
- Bulk edit or bulk delete behavior.

---

## Affected Areas

- Quote form edit mode behavior
- Quote deletion confirmation flow
- Local-only seeded quote mutation rules
