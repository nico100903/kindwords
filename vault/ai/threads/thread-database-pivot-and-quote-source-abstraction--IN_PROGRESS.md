---
id: thread-database-pivot-and-quote-source-abstraction
title: "Database pivot and quote source abstraction"
status: in-progress
priority: high
created: 2026-03-26
updated: 2026-03-26
owner: orchestrator
links:
  - vault/sprint/PLAN.md
  - vault/sprint/backlog/task-04-feat-quote-data-foundation-for-local-catalog.md
  - vault/sprint/backlog/task-04.01-feat-introduce-local-quote-database-and-repository.md
  - vault/sprint/backlog/task-04.02-feat-migrate-quote-access-to-repository-api.md
next_action: "Enrich task 04.01 with implementation guidance so the database pivot can enter build execution."
---

## Intent

Repivot the MVP away from hardcoded quote storage so favorites and future quote refresh can build on a stable database-first architecture.

## Current State

User requested a local database for the 100 seed quotes and a provider-agnostic facade for future online quote refresh, likely with Firebase first. A Sonnet-led architecture pass recommended `sqflite` plus a `QuoteRepository` abstraction, keeping favorites as quote-ID data in `shared_preferences` and protecting favorites from future refresh deletion. The sprint plan now includes epic `04` with tasks `04.01` and `04.02`, and `02.02` is blocked on that prerequisite lane.

## Next Action

Enrich task `04.01` with implementation guidance so the database pivot can enter build execution.

## Notes / Parking Lot

- Request explicitly prefers architecture-capable agents and Anthropic Sonnet over GLM-5 for the decision work.
- Expected scope impact: quote data layer, favorites persistence, future sync boundary, and backlog reshaping before favorites implementation.
- Planning artifacts updated: `vault/sprint/PLAN.md`, `vault/sprint/backlog/task-04*.md`, plus dependency updates on `02.02` and `03.02`.
