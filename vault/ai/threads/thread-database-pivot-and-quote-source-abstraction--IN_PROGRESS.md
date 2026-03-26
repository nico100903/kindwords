---
id: thread-database-pivot-and-quote-source-abstraction
title: "Database pivot and quote source abstraction"
status: in-progress
priority: high
created: 2026-03-26
updated: 2026-03-26
owner: orchestrator
links: []
next_action: "Produce an SDLC-backed architecture decision and updated sprint plan for local database quote storage plus a remote quote refresh facade."
---

## Intent

Repivot the MVP away from hardcoded quote storage so favorites and future quote refresh can build on a stable database-first architecture.

## Current State

User requested a local database for the 100 seed quotes and a provider-agnostic facade for future online quote refresh, likely with Firebase first.

## Next Action

Produce an SDLC-backed architecture decision and updated sprint plan for local database quote storage plus a remote quote refresh facade.

## Notes / Parking Lot

- Request explicitly prefers architecture-capable agents and Anthropic Sonnet over GLM-5 for the decision work.
- Expected scope impact: quote data layer, favorites persistence, future sync boundary, and backlog reshaping before favorites implementation.
