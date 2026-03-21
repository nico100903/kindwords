---
id: orchestrator-drift-self-improvement
title: Orchestrator drift self improvement
status: IN_PROGRESS
priority: high
created: 2026-03-20
updated: 2026-03-20
owner: orchestrator
links: []
next_action: Tighten routing so direct user workflow requests do not trigger unnecessary multi-level delegation.
---

## Intent
Capture user-friction incidents caused by orchestration drift and record concrete guardrails that reduce repeat failures.

## Current State
Fresh incident captured after over-delegating a direct SDLC kickoff request and attempting an unnecessary ecosystem detour.

## Next Action
Tighten routing so direct user workflow requests do not trigger unnecessary multi-level delegation.

## Incident Log
- 2026-03-20: User reported "you had a bug, you just did multiple multiple multiple levels of delegations." Observed signal: frustration after I routed a direct SDLC kickoff into an avoidable ecosystem dispatch instead of proceeding with the workflow.

## Ledger
- 2026-03-20 | failure: over-delegated a direct SDLC start request into ecosystem work | guardrail: when the user requests project SDLC execution and no current blocker remains, dispatch the SDLC orchestrator directly instead of inventing prerequisite delegation layers | acceptance check: next SDLC kickoff request produces one direct `sdlc-orchestrator` dispatch with no preparatory ecosystem task unless an actual unresolved blocker is still present.

## Notes / Parking Lot
- User has now said the Anthropic issue is fixed.
- Immediate recovery path: start SDLC for `/home/cmark/projects/kindwords` with a direct lifecycle dispatch.
