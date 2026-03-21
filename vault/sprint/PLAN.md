# Project Plan — KindWords

## Overview

KindWords is an offline Flutter Android app with three release-critical capabilities: random quote browsing, local favorites, and one daily local notification. Plan now converts the Foundation artifacts into executable backlog tasks, with wave sequencing optimized to unblock the app shell first, then parallelize quote data, favorites scaffolding, and settings scaffolding before higher-risk notification integration.

## Foundation Status

- `SPEC.md` defines release scope and acceptance targets.
- `discovery/prd.md` defines user journeys, product goals, and implementation constraints.
- `discovery/architecture.md` defines module boundaries, data contracts, and recommended sequencing.
- `vault/ai/docs/architecture/module-map.md` defines module ownership and current gaps.
- `vault/sprint/backlog/` and `vault/sprint/done/` reflect current execution state for Build-phase tasks.

## Current Execution State

- Done: `01.01`, `01.02`, `01.03`, `03.01`
- Backlog: `01.04`, `02`, `02.01`, `02.02`, `02.03`, `03`, `03.02`, `03.03`, `03.04`
- Working tree already contains fresh enrichment for upcoming tasks `01.04` and `03.02`; keep both in backlog until their implementation is completed and verified.

## Task Summary

| ID | Title | Type | Cx | Sprint | Depends | Parallel with |
|----|-------|------|----|--------|---------|---------------|
| 01 | Core app shell and quote experience | feat | L | 1 | — | 02, 03 |
| 01.01 | Create app bootstrap and provider wiring | feat | M | 1 | — | 01.02 |
| 01.02 | Build home screen shell with quote card and CTA | feat | M | 1 | — | 01.01 |
| 01.03 | Expand embedded quote catalog | feat | M | 2 | 01.01 | 02.01, 03.01 |
| 01.04 | Connect random quote flow | feat | M | 3 | 01.02, 01.03 | 03.02 |
| 02 | Favorites experience | feat | L | 4 | 01.04 | 03 |
| 02.01 | Create favorites provider and screen shell | feat | M | 2 | 01.01 | 01.03, 03.01 |
| 02.02 | Persist favorite quotes and prevent duplicates | feat | M | 4 | 01.04, 02.01 | 03.03 |
| 02.03 | Implement favorites list and delete flow | feat | M | 5 | 02.01, 02.02 | — |
| 03 | Daily notifications and release readiness | feat | L | 4 | 01.04 | 02 |
| 03.01 | Build settings screen and notification preferences | feat | M | 2 | 01.01 | 01.03, 02.01 |
| 03.02 | Complete daily notification scheduling | feat | L | 3 | 03.01 | 01.04 |
| 03.03 | Add permission and reboot recovery | feat | L | 4 | 03.02 | 02.02 |
| 03.04 | Run release verification | test | M | 6 | 02.03, 03.03 | — |

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

### Wave 3 — Primary quote loop and notification scheduling
| ID | Title | Type | Cx | Depends | Parallel with |
|----|-------|------|----|---------|---------------|
| 01.04 | Connect random quote flow | feat | M | 01.02, 01.03 | 03.02 |
| 03.02 | Complete daily notification scheduling | feat | L | 03.01 | 01.04 |

### Wave 4 — Persistence hardening and Android-specific recovery
| ID | Title | Type | Cx | Depends | Parallel with |
|----|-------|------|----|---------|---------------|
| 02.02 | Persist favorite quotes and prevent duplicates | feat | M | 01.04, 02.01 | 03.03 |
| 03.03 | Add permission and reboot recovery | feat | L | 03.02 | 02.02 |

### Wave 5 — Favorites completion
| ID | Title | Type | Cx | Depends | Parallel with |
|----|-------|------|----|---------|---------------|
| 02.03 | Implement favorites list and delete flow | feat | M | 02.01, 02.02 | — |

### Wave 6 — Release verification
| ID | Title | Type | Cx | Depends | Parallel with |
|----|-------|------|----|---------|---------------|
| 03.04 | Run release verification | test | M | 02.03, 03.03 | — |

## Dependency Graph

01.01 -> 01.03 -> 01.04 -> 02 -> 02.02 -> 02.03 -> 03.04
01.01 -> 02.01 -> 02.02 -> 02.03
01.01 -> 03.01 -> 03.02 -> 03.03 -> 03.04
01.02 -> 01.04 -> 03 -> 03.04

## Critical Path

01.01 -> 03.01 -> 03.02 -> 03.03 -> 03.04

Reason: daily notification delivery remains the highest-risk lane because it combines reminder scheduling, Android permission behavior, reboot recovery, and final release verification dependency.

## Planning Notes For Main Orchestrator

- Start with Wave 1 immediately; both tasks are unblocked and establish the app structure every later lane relies on.
- Route `03.02` and `03.03` as `difficulty: complex` candidates for heavy implementation support after tech-lead enrichment.
- Treat `01.03`, `02.01`, and `03.01` as the first major parallel batch once `01.01` is complete.
- Use individual task frontmatter as source of truth if it ever conflicts with this summary.
