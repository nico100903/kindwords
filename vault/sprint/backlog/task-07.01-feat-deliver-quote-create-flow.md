---
id: "07.01"
title: "Deliver quote create flow"
type: feat
priority: high
complexity: M
difficulty: moderate
sprint: 4
depends_on: ["06.01"]
blocks: ["07.02"]
parent: "07"
branch: "feat/task-07-quote-form-flows"
assignee: dev
enriched: false
---

# Task 07.01: Deliver Quote Create Flow

## Business Requirements

### Problem
The new catalog experience is incomplete unless the user can add their own quotes into the local collection. KindWords needs a create flow that validates quote input clearly and saves user-authored quotes with the required local metadata.

### User Story
As a user, I want to write and save my own quote so that KindWords can store personal motivation alongside the bundled catalog.

### Acceptance Criteria
- [ ] From the Quote Catalog, the user can start quote creation from the add action in the app bar and from the floating action button.
- [ ] In create mode, the Quote Form allows entry of quote text, optional author, and 0 to 3 predefined tags.
- [ ] Saving a valid new quote stores it locally with source `userCreated` and with required fields `id`, `text`, `author`, `tags`, `source`, `createdAt`, and `updatedAt`.
- [ ] The form rejects quote creation when quote text is blank or fewer than 10 characters and shows visible field-level validation.
- [ ] After a successful save, the user returns to an updated quote collection that includes the newly created quote.

### Business Rules
- Only predefined tags are selectable in this release.
- The create flow must not allow more than 3 selected tags.
- The quote source is shown as read-only information rather than something the user can choose.
- Create behavior remains fully offline and local to the device.

### Out of Scope
- Editing an existing quote.
- Deleting an existing quote.
- Favorites screen entry into the form.

---

## Affected Areas

- Quote creation entry points from the catalog
- New quote validation and save behavior
- User-created quote metadata continuity
