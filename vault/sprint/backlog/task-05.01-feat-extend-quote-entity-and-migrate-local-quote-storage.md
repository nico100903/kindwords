---
id: "05.01"
title: "Extend quote entity and migrate local quote storage"
type: feat
priority: high
complexity: M
difficulty: complex
sprint: 1
depends_on: ["04.02"]
blocks: ["05.02"]
parent: "05"
branch: "feat/task-05-quote-crud-foundation"
assignee: dev
enriched: false
---

# Task 05.01: Extend Quote Entity And Migrate Local Quote Storage

## Business Requirements

### Problem
The current quote record is too small to support local CRUD behavior, filtering, and edit history. KindWords needs a safe local migration that enriches stored quotes without breaking existing quote access, favorites continuity, or the app's offline behavior.

### User Story
As a user, I want my existing local quotes to survive the quote CRUD update so that I can gain richer quote management without reinstalling the app or losing current data continuity.

### Acceptance Criteria
- [ ] Upgrading a device from quote database version 1 to version 2 preserves previously stored quote records and their existing stable IDs.
- [ ] After migration, every locally stored quote record includes `id`, `text`, `author`, `tags`, `source`, `createdAt`, and `updatedAt` fields, with `tags` defaulting to an empty list and `source` defaulting to `seeded` for migrated rows.
- [ ] The quote data model supports exactly two sources in this release: `seeded` and `userCreated`.
- [ ] The migrated quote store remains usable by existing favorites references and does not require the user to clear app data or reinstall.

### Business Rules
- Predefined tags for this release are `personal`, `motivational`, `wisdom`, `humor`, `love`, and `focus`.
- A quote may have 0, 1, 2, or 3 tags, but never more than 3.
- Seeded quote edits and deletes remain local-device actions only and must never imply bundled-catalog mutation or remote propagation.
- `createdAt` is required for every stored quote; `updatedAt` may remain empty until a local edit occurs.

### Out of Scope
- Repository CRUD contract expansion.
- Quote catalog browsing and filtering UI.
- Quote form create, edit, or delete screens.

---

## Affected Areas

- Quote entity shape and local persistence contract
- Local quote schema versioning and migration continuity
- Seeded quote compatibility with existing favorites references
