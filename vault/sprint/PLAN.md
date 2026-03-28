# Project Plan — KindWords

## Overview

KindWords remains an offline Flutter Android app with three release-critical capabilities: random quote browsing, local favorites, and one daily local notification. This update inserts a database-first quote foundation before favorites persistence so the app can seed its bundled catalog into a local runtime store, keep future provider options open, and preserve favorites as user-owned quote IDs.

## Foundation Status

- `SPEC.md` defines release scope and acceptance targets.
- `discovery/prd.md` defines user journeys, product goals, and implementation constraints.
- `discovery/architecture.md` defines module boundaries, data contracts, and recommended sequencing.
- `vault/ai/docs/architecture/module-map.md` defines module ownership and current gaps.
- `vault/sprint/backlog/` and `vault/sprint/done/` reflect current execution state for Build-phase tasks.

## Current Execution State

- Done: ALL — `01.01`, `01.02`, `01.03`, `01.04`, `02.01`, `02.02`, `02.03`, `03.01`, `03.02`, `03.03`, `03.04`, `04.01`, `04.02`
- Backlog: empty
- Ongoing: empty

### Sprint completion: 2026-03-26
Automated release gates passed. Manual device journeys pending physical device install.
- `01.03` stays done, but it is now treated as the bundled seed-source milestone for the future local catalog rather than the long-term runtime quote source.
- `03.02` remains verification-first. Existing scheduling logic is already present, and the next pass should prove physical-device schedule, cancel, and reschedule behavior before any additional implementation.
- Favorites persistence work must not continue until the new quote data foundation lane (`04.01`, `04.02`) is complete.

## Task Summary

| ID | Title | Type | Cx | Sprint | Depends | Parallel with |
|----|-------|------|----|--------|---------|---------------|
| 01 | Core app shell and quote experience | feat | L | 1 | — | 02, 03, 04 |
| 01.01 | Create app bootstrap and provider wiring | feat | M | 1 | — | 01.02 |
| 01.02 | Build home screen shell with quote card and CTA | feat | M | 1 | — | 01.01 |
| 01.03 | Expand embedded quote catalog | feat | M | 2 | 01.01 | 02.01, 03.01 |
| 01.04 | Connect random quote flow | feat | M | 3 | 01.02, 01.03 | 03.02, 04.01 |
| 02 | Favorites experience | feat | L | 4 | 01.04 | 03, 04 |
| 02.01 | Create favorites provider and screen shell | feat | M | 2 | 01.01 | 03.01, 04.01 |
| 02.02 | Persist favorite quotes and prevent duplicates | feat | M | 5 | 02.01, 04.01, 04.02 | 03.03 |
| 02.03 | Implement favorites list and delete flow | feat | M | 6 | 02.01, 02.02 | — |
| 03 | Daily notifications and release readiness | feat | L | 4 | 01.04 | 02, 04 |
| 03.01 | Build settings screen and notification preferences | feat | M | 2 | 01.01 | 01.03, 02.01 |
| 03.02 | Complete daily notification scheduling | feat | L | 3 | 03.01 | 04.01 |
| 03.03 | Add permission and reboot recovery | feat | L | 5 | 03.02 | 02.02 |
| 03.04 | Run release verification | test | M | 7 | 02.03, 03.03 | — |
| 04 | Quote data foundation for local catalog | feat | L | 3 | 01.03, 01.04 | 03 |
| 04.01 | Introduce local quote database and repository | feat | M | 3 | 01.03 | 02.01, 03.02 |
| 04.02 | Migrate quote access to repository API | feat | M | 4 | 01.04, 04.01 | 03.03 |

## Execution Waves

### Wave 1 — App entry and primary home shell
| ID | Title | Type | Cx | Depends | Parallel with |
|----|-------|------|----|---------|---------------|
| 01.01 | Create app bootstrap and provider wiring | feat | M | — | 01.02 |
| 01.02 | Build home screen shell with quote card and CTA | feat | M | — | 01.01 |

### Wave 2 — Parallel scaffolding after bootstrap
| ID | Title | Type | Cx | Depends | Parallel with |
|----|-------|------|----|---------|---------------|
| 01.03 | Expand embedded quote catalog | feat | M | 01.01 | 02.01, 03.01 |
| 02.01 | Create favorites provider and screen shell | feat | M | 01.01 | 01.03, 03.01 |
| 03.01 | Build settings screen and notification preferences | feat | M | 01.01 | 01.03, 02.01 |

### Wave 3 — Current quote loop completion plus next ready parallel work
| ID | Title | Type | Cx | Depends | Parallel with |
|----|-------|------|----|---------|---------------|
| 01.04 | Connect random quote flow | feat | M | 01.02, 01.03 | complete |
| 03.02 | Complete daily notification scheduling | feat | L | 03.01 | 04.01 |
| 04.01 | Introduce local quote database and repository | feat | M | 01.03 | 03.02 |

Wave 3 note: `03.02` stays verification-first even after the quote-storage pivot. `04.01` is the newly inserted prerequisite foundation step for the database-first architecture.

### Wave 4 — Prerequisite quote-source migration lane (Wave 2.5 insert)
| ID | Title | Type | Cx | Depends | Parallel with |
|----|-------|------|----|---------|---------------|
| 04.02 | Migrate quote access to repository API | feat | M | 01.04, 04.01 | 03.03 |

Wave 4 note: this is the database-first prerequisite lane requested before favorites persistence continues. `02.02` must not start until `04.01` and `04.02` are both done.

### Wave 5 — Favorites persistence and Android-specific recovery
| ID | Title | Type | Cx | Depends | Parallel with |
|----|-------|------|----|---------|---------------|
| 02.02 | Persist favorite quotes and prevent duplicates | feat | M | 02.01, 04.01, 04.02 | 03.03 |
| 03.03 | Add permission and reboot recovery | feat | L | 03.02 | 02.02 |

### Wave 6 — Favorites completion
| ID | Title | Type | Cx | Depends | Parallel with |
|----|-------|------|----|---------|---------------|
| 02.03 | Implement favorites list and delete flow | feat | M | 02.01, 02.02 | — |

### Wave 7 — Release verification
| ID | Title | Type | Cx | Depends | Parallel with |
|----|-------|------|----|---------|---------------|
| 03.04 | Run release verification | test | M | 02.03, 03.03 | — |

## Dependency Graph

01.01 -> 01.03 -> 01.04
01.01 -> 02.01 -> 02.02 -> 02.03 -> 03.04
01.01 -> 03.01 -> 03.02 -> 03.03 -> 03.04
01.03 -> 04.01 -> 04.02 -> 02.02
01.04 -> 04 -> 04.02

## Critical Path

01.01 -> 01.03 -> 04.01 -> 04.02 -> 02.02 -> 02.03 -> 03.04

Reason: the database-first pivot is now the gating lane for favorites persistence, and favorites completion still blocks final release verification.

## Planning Notes For Main Orchestrator

- Treat `04.01` as the first new architecture-guided implementation task. It is the new prerequisite for database-first quote storage and should be enriched before `02.02`.
- Treat `04.02` as the follow-on migration step that aligns quote browsing and future quote lookups to the repository-backed runtime source.
- Keep `02.01` structurally valid and available in parallel; it does not need to wait for the quote-storage pivot.
- Keep `03.02` as a verification-led backlog item first; only open follow-up implementation work if device audit evidence exposes a real scheduling gap.
- Use individual task frontmatter as source of truth if it ever conflicts with this summary.

## Sprint 2 Overview

Sprint 2 adds local quote CRUD on top of the finished offline foundation from Sprint 1. The plan keeps migration, storage expansion, browse flows, form flows, and cross-screen integration in narrow waves so favorites, notifications, and the random quote journey stay stable while the app gains a user-managed local quote collection.

## Sprint 2 Current Execution State

- Backlog ready: `08.03`
- Ongoing: empty
- Done: `05`, `05.01`, `05.02`, `06`, `06.01`, `07`, `07.01`, `07.02`, `08`, `08.01`, `08.02`

## Sprint 2 Task Summary

| ID | Title | Type | Cx | Wave | Depends | Parallel with |
|----|-------|------|----|------|---------|---------------|
| 05 | Quote CRUD foundation and data model | feat | L | 1 | 04.02 | 06, 07, 08 |
| 05.01 | Extend quote entity and migrate local quote storage | feat | M | 1 | 04.02 | — |
| 05.02 | Expand quote CRUD access and catalog state management | feat | M | 2 | 05.01 | — |
| 06 | Quote catalog and browse/read flows | feat | L | 3 | 05.02 | 08 |
| 06.01 | Deliver quote catalog browse and filter experience | feat | M | 3 | 05.02 | — |
| 07 | Quote create/edit/delete form flows | feat | L | 4 | 06.01 | 08 |
| 07.01 | Deliver quote create flow | feat | M | 4 | 06.01 | — |
| 07.02 | Deliver quote edit and delete flows | feat | M | 5 | 07.01 | — |
| 08 | Favorites and navigation integration | feat | L | 6 | 07.02, 06.01 | — |
| 08.01 | Extend favorites for quote edit and delete continuity | feat | M | 6 | 07.02, 02.03 | 08.02 |
| 08.02 | Expand top-level navigation for quote catalog access | feat | S | 6 | 06.01 | 08.01 |
| 08.03 | Run quote CRUD regression verification | test | M | 7 | 08.01, 08.02 | — |

## Sprint 2 Execution Waves

### Wave 1 - Data model and migration foundation
| ID | Title | Type | Cx | Depends | Parallel with |
|----|-------|------|----|---------|---------------|
| 05.01 | Extend quote entity and migrate local quote storage | feat | M | 04.02 | — |

### Wave 2 - CRUD access and provider state foundation
| ID | Title | Type | Cx | Depends | Parallel with |
|----|-------|------|----|---------|---------------|
| 05.02 | Expand quote CRUD access and catalog state management | feat | M | 05.01 | — |

### Wave 3 - Quote catalog browse/read surface
| ID | Title | Type | Cx | Depends | Parallel with |
|----|-------|------|----|---------|---------------|
| 06.01 | Deliver quote catalog browse and filter experience | feat | M | 05.02 | — |

### Wave 4 - Quote create flow
| ID | Title | Type | Cx | Depends | Parallel with |
|----|-------|------|----|---------|---------------|
| 07.01 | Deliver quote create flow | feat | M | 06.01 | — |

### Wave 5 - Quote edit and delete flow
| ID | Title | Type | Cx | Depends | Parallel with |
|----|-------|------|----|---------|---------------|
| 07.02 | Deliver quote edit and delete flows | feat | M | 07.01 | — |

### Wave 6 - Cross-screen integration
| ID | Title | Type | Cx | Depends | Parallel with |
|----|-------|------|----|---------|---------------|
| 08.01 | Extend favorites for quote edit and delete continuity | feat | M | 07.02, 02.03 | 08.02 |
| 08.02 | Expand top-level navigation for quote catalog access | feat | S | 06.01 | 08.01 |

### Wave 7 - Regression verification
| ID | Title | Type | Cx | Depends | Parallel with |
|----|-------|------|----|---------|---------------|
| 08.03 | Run quote CRUD regression verification | test | M | 08.01, 08.02 | — |

## Sprint 2 Dependency Graph

05.01 -> 05.02 -> 06.01 -> 07.01 -> 07.02 -> 08.01 -> 08.03
06.01 -> 08.02 -> 08.03
02.03 -> 08.01
04.02 -> 05.01

## Sprint 2 Critical Path

04.02 -> 05.01 -> 05.02 -> 06.01 -> 07.01 -> 07.02 -> 08.01 -> 08.03

Reason: safe migration and CRUD contracts must land before UI flows can rely on them, and favorites continuity remains the last user-facing integration gate before final regression verification.

## Sprint 2 Planning Notes For Orchestrator

- Use `vault/ai/docs/srs-quote-crud-update.md` as the source of truth when it conflicts with discovery or UI notes.
- Treat the predefined tag set as fixed for this sprint and keep selection to 0-3 tags; do not introduce free-form tag creation.
- Treat seeded quote edits and deletes as local-only mutations of the device database. No task should imply bundle mutation, sync, or remote propagation.
- Preserve Sprint 1 behavior as a standing compatibility gate: random quote display, favorites persistence, and daily notifications must remain functional after every wave.
- Follow the repo's BDD-first model for every feature task: QA writes failing tests first, coder implements to green, then the wave passes through an integrate gate before the next wave opens.
- `08.03` should verify migration, CRUD operations, filter behavior, form validation, favorites continuity, and notification/random-quote non-regression in one closing pass.
- Resolve the `personal` tag ambiguity in favor of the SRS: it is part of the predefined selectable tag set, but not an automatically required tag for new quotes unless a later approved requirement says otherwise.
