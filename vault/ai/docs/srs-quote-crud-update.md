# Software Requirements Specification (SRS) — KindWords Quote CRUD Update

| Metadata | Value |
|---|---|
| Project | KindWords |
| Document type | Software Requirements Specification |
| Version | 1.0 |
| Status | Approved reference artifact before development |
| Date | 2026-03-27 |
| Platform | Android-only Flutter application |
| Product mode | Offline-first, single-user personal app |
| Source inputs | `SPEC.md`, `vault/ai/docs/sprint-crud-quotes-discovery.md`, `vault/ai/docs/sprint-crud-quotes-ui.md` |

## 1. Purpose

This document defines the software requirements for the KindWords quote CRUD update. The update extends the existing offline motivational quote application so the user can browse, create, edit, and delete quotes within a local personal collection while preserving current favorites and notification behavior.

The SRS is intended to serve as the formal reference artifact for backlog generation, implementation planning, verification, and academic review.

## 2. Scope

The quote CRUD update adds visible and testable create, read, update, and delete capabilities to KindWords.

The update includes:
- a new Quote Catalog screen for browsing all quotes;
- a new Quote Form screen for create and edit flows;
- local editing and deletion of both seeded and user-created quotes;
- predefined tags/categories on quotes;
- CRUD access from the Favorites screen for favorited quotes;
- an expanded bottom navigation structure that includes Quotes;
- a required SQLite schema migration from database version 1 to version 2.

The update remains fully offline and local to a single device user. No backend, account, synchronization, or remote moderation capability is introduced in this release.

## 3. Definitions and Terminology

| Term | Definition |
|---|---|
| Quote | A locally stored motivational text item shown in the app and managed by the user. |
| Seeded quote | A quote initially populated from the bundled catalog during local database seeding. |
| User-created quote | A quote authored or added by the user inside the app. |
| Quote source | The origin classification of a quote: `seeded` or `userCreated`. |
| Quote Catalog | The new screen that lists all locally available quotes and provides browse, filter, edit, and delete entry points. |
| Quote Form | The new screen used to create a quote or edit an existing quote. |
| Local delete | Removal of a quote from the device database only. |
| Favorites | User-selected saved quotes shown in the Favorites screen. |
| Tag | A predefined category label assigned to a quote for organization and filtering. |
| CRUD | Create, Read, Update, Delete operations over locally stored quotes. |

## 4. Stakeholders and User Profile

### 4.1 Primary stakeholders
- Student developer and project owner;
- course instructor and academic evaluator;
- end user of the app, represented by a single Android device owner.

### 4.2 User profile
The intended user is a single person using KindWords as a personal offline motivation app. The user does not manage other users, does not authenticate, and does not share ownership of data. All quote operations are performed for personal local use only.

## 5. Product Perspective

KindWords currently provides random quote display, local favorites, and daily local notifications. The quote CRUD update is an extension of the existing product baseline defined in `SPEC.md`.

After this update:
- quotes shall be stored and managed as a local collection rather than only as a fixed seeded catalog;
- the app shall support two quote sources: `seeded` and `userCreated`;
- existing favorites and notification features shall continue to operate without regression;
- all quote modifications shall remain device-local and offline.

This update does not change the overall product identity of KindWords as an offline Android application with no account system and no required network connectivity.

## 6. Assumptions and Constraints

- The application shall remain Android-only and built with Flutter.
- The application shall remain offline-first and shall perform no network calls for quote CRUD actions.
- The data store for quotes shall remain SQLite, with a required migration from schema version 1 to version 2.
- The product remains single-user; no role separation, authentication, or ownership model is introduced.
- Seeded quotes are editable and deletable by the user, but only within the local database copy.
- Local edits or deletions of seeded quotes shall never propagate to any future Firebase quote pool or other remote source.
- Tags shall be selected from a predefined list only, with a maximum of 3 tags per quote.
- Existing favorites and daily notification behavior are mandatory compatibility constraints and shall not regress.

## 7. Functional Requirements

### 7.1 Read and browse requirements

FR-1. The system shall provide a Quote Catalog screen that lists all quotes currently stored in the local database.

FR-2. The Quote Catalog screen shall be reachable through bottom navigation via a Quotes tab.

FR-3. The Quote Catalog screen shall display both `seeded` and `userCreated` quotes in a single browsable collection.

FR-4. The user shall be able to filter the Quote Catalog by quote source using All, Seeded, and Mine options.

FR-5. The user shall be able to filter the Quote Catalog by one predefined tag at a time while retaining an optional source filter.

FR-6. Each quote list item in the Quote Catalog shall display the quote text, author or anonymous fallback, source indicator, and visible tags when present.

FR-7. The system shall provide an empty-filter state when no quotes match the active filters.

### 7.2 Create requirements

FR-8. The system shall provide a Quote Form screen that supports creation of a new quote.

FR-9. The user shall be able to start quote creation from the Quote Catalog using the add action in the app bar or the floating action button.

FR-10. In create mode, the Quote Form shall allow entry of quote text, optional author, and 0 to 3 predefined tags.

FR-11. A newly created quote shall be stored with source `userCreated`.

FR-12. A newly created quote shall be persisted locally with the required fields `id`, `text`, `author`, `tags`, `source`, `createdAt`, and `updatedAt`.

FR-13. The system shall reject quote creation when quote text is blank or fewer than 10 characters.

### 7.3 Update requirements

FR-14. The system shall allow the user to edit any existing quote, including both `seeded` and `userCreated` quotes.

FR-15. The Quote Form screen shall support edit mode with pre-populated values for the selected quote.

FR-16. In edit mode, the user shall be able to update quote text, author, and tags for any quote.

FR-17. When a quote is updated, the system shall preserve the original `id`, preserve the original `createdAt`, and update `updatedAt` to the time of the local edit.

FR-18. The system shall reflect quote edits in all affected visible app areas, including the Quote Catalog, Favorites screen, and any currently displayed matching quote where applicable.

### 7.4 Delete requirements

FR-19. The system shall allow the user to delete any existing quote, including both `seeded` and `userCreated` quotes.

FR-20. The Quote Catalog shall provide a delete action for each listed quote.

FR-21. The Quote Form in edit mode shall provide a delete action for the current quote.

FR-22. The system shall require user confirmation before any quote deletion is finalized.

FR-23. Deleting a quote shall remove that quote from the local database only.

FR-24. Deleting or editing a seeded quote shall not modify the bundled seed catalog artifact and shall never propagate to any future Firebase quote pool or remote quote source.

### 7.5 Favorites requirements

FR-25. The Favorites screen shall continue to display the user's favorited quotes after this update.

FR-26. The Favorites screen shall provide an edit action for each favorited quote.

FR-27. Editing a quote from the Favorites screen shall open the Quote Form screen in edit mode for that quote.

FR-28. The Favorites screen shall provide a delete action for each favorited quote.

FR-29. If a favorited quote is edited or deleted, the Favorites screen shall update to reflect the current local quote state.

### 7.6 Data integrity and continuity requirements

FR-30. The system shall migrate the local SQLite quote schema from version 1 to version 2 without losing existing quote records.

FR-31. Existing favorites behavior shall continue to function with migrated quotes.

FR-32. Existing daily notification scheduling behavior shall continue to function after the quote CRUD update is introduced.

## 8. Data Requirements

### 8.1 Quote entity

Each quote record shall contain the following fields:

| Field | Type | Requirement |
|---|---|---|
| `id` | string | Required, unique within the local database |
| `text` | string | Required |
| `author` | string or null | Optional |
| `tags` | list of strings | Required, may be empty, maximum 3 values |
| `source` | enum | Required; valid values are `seeded` and `userCreated` |
| `createdAt` | datetime | Required |
| `updatedAt` | datetime or null | Optional until first update |

### 8.2 Quote source rules

- The system shall support exactly two quote sources in this release: `seeded` and `userCreated`.
- A quote created within the app shall be assigned source `userCreated`.
- A quote originating from the bundled catalog and stored locally shall be assigned source `seeded`.

### 8.3 Tag rules

- Tags shall be selected only from a predefined tag set.
- A quote may have 0, 1, 2, or 3 tags.
- The initial predefined tags shall include: `personal`, `motivational`, `wisdom`, `humor`, `love`, and `focus`.

### 8.4 Persistence and migration

- Quote data shall be persisted in SQLite.
- The quote table schema shall be migrated from version 1 to version 2 to support tags, source, createdAt, and updatedAt.
- Existing stored records shall be upgraded without destructive reset.
- Existing favorites references shall remain usable after migration.

## 9. UI and Navigation Requirements

- The app shall include a Quote Catalog screen as a top-level navigation destination.
- Bottom navigation shall expand to include Home, Quotes, Favorites, and Settings.
- The Quote Catalog shall expose browse, filter, create, edit, and delete entry points.
- The Quote Form screen shall support both create and edit flows within one screen pattern.
- The Quote Form shall visibly distinguish create mode from edit mode using title and action labeling.
- The Quote Form shall display the quote source as read-only information.
- The Favorites screen shall support edit and delete access for favorited quotes.
- Destructive actions shall require confirmation before completion.
- Validation errors for quote entry shall be visible and specific to the affected field.
- Empty states shall be provided for filter results and for any quote list that has no displayable items.

## 10. Non-Functional Requirements

NFR-1. The update shall preserve the product's fully offline behavior; no network dependency shall be introduced for quote browsing, creation, editing, or deletion.

NFR-2. The application shall remain Android-only and compatible with the project's defined Flutter Android target.

NFR-3. Quote CRUD operations against local storage shall complete with user-perceivable responsiveness appropriate for a local mobile app, with normal list refreshes and form saves occurring without noticeable delay under ordinary device conditions.

NFR-4. The database migration from version 1 to version 2 shall preserve previously available data and shall not require the user to reinstall the app.

NFR-5. The update shall not regress existing favorites persistence behavior.

NFR-6. The update shall not regress existing daily local notification configuration or delivery behavior.

NFR-7. Destructive actions shall be guarded by confirmation prompts to reduce accidental data loss.

NFR-8. Primary interactive controls on list items, forms, and navigation shall remain accessible in a standard Material mobile interface, including readable labels, icon affordances, and field-level validation feedback.

## 11. Out of Scope

- Cloud synchronization or backup of quotes;
- Firebase integration or any remote quote pool behavior beyond the explicit non-propagation constraint;
- multi-user support, authentication, or ownership sharing;
- free-form custom tag creation;
- full-text search;
- bulk edit or bulk delete of quotes;
- quote import/export;
- iOS support;
- changes to the core notification feature beyond non-regression support;
- social sharing or advanced moderation workflows.

## 12. Acceptance Criteria and Success Conditions

The update shall be considered successful when all of the following are true:

- The app provides a new Quote Catalog screen that the user can reach from bottom navigation.
- The user can browse all local quotes and filter them by source and predefined tags.
- The user can create a new quote with valid text, optional author, and up to 3 predefined tags.
- The user can edit any quote, including seeded quotes and user-created quotes.
- The user can delete any quote locally, including seeded quotes and user-created quotes, only after confirmation.
- Editing or deleting a seeded quote affects only the local database representation and does not affect any future online quote pool.
- The Favorites screen allows the user to edit and delete favorited quotes.
- The Quote Form supports create and edit flows and displays field validation for invalid input.
- The SQLite schema upgrades from version 1 to version 2 without loss of existing stored quotes or breakage of favorites references.
- Existing favorites and notification behavior continue to function after the update.
- The delivered behavior remains fully offline on Android.

## 13. Traceability Notes

| Requirement area | Primary source reference |
|---|---|
| Baseline product constraints and existing feature continuity | `SPEC.md` |
| Single-user CRUD scope and local-only seeded edit/delete rules | `vault/ai/docs/sprint-crud-quotes-discovery.md` Sections 1, 14 |
| Quote fields, sources, tags, and schema migration | `vault/ai/docs/sprint-crud-quotes-discovery.md` Sections 2, 3 |
| Quote Catalog, Quote Form, Favorites CRUD extension | `vault/ai/docs/sprint-crud-quotes-discovery.md` Sections 5, 6, 7 |
| Bottom navigation and route expansion | `vault/ai/docs/sprint-crud-quotes-discovery.md` Section 8 |
| Catalog layout, filters, destructive confirmations, and form validation behavior | `vault/ai/docs/sprint-crud-quotes-ui.md` Sections 17-191 |
| Favorites tile interaction changes and accessibility notes | `vault/ai/docs/sprint-crud-quotes-ui.md` Sections 193-262 |

This SRS resolves the baseline `SPEC.md` statement that quote categories or tags were deferred by superseding that limitation for this update only. All other baseline constraints remain in force unless explicitly revised by this document.
