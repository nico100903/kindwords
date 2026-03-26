---
id: "04.02"
title: "Migrate quote access to repository API"
type: feat
priority: high
complexity: M
difficulty: complex
sprint: 4
depends_on: ["01.04", "04.01"]
blocks: ["02.02"]
parent: "04"
branch: "feat/task-04-quote-data-foundation"
assignee: dev
enriched: false
---

# Task 04.02: Migrate Quote Access To Repository API

## Business Requirements

### Problem
Even with a prepared local quote catalog, the app will not benefit from the storage pivot until quote-driven experiences actually use the new source. This task keeps quote browsing dependable while aligning runtime quote access around one local foundation.

### User Story
As a user, I want quote browsing and quote-based behaviors to keep working after the storage pivot so that the app feels consistent while its data foundation improves.

### Acceptance Criteria
- [ ] Refreshing the home quote still shows a valid quote and can show a different quote when more than one quote is available.
- [ ] Quote-driven app behaviors use the same runtime quote source for random selection and quote lookup.
- [ ] Quote retrieval handles startup or loading states safely, with no crash or broken placeholder state visible to the user.
- [ ] Quote identity remains consistent across browsing, favorites preparation, and notification content lookup.

### Business Rules
- The quote browsing experience must remain fully offline.
- The storage pivot must not require users to re-save favorites or reset reminder preferences.
- Future quote-source expansion is prepared for, but no remote provider behavior is implemented in this task.

### Out of Scope
- Implementing a remote quote provider.
- Notification permission or reboot-recovery work.
- Final favorites save, list, or delete behavior.

---
<!-- TECHNICAL GUIDANCE - written by Tech Lead below this line -->
<!-- Do not modify Business Requirements when enriching -->

## Architecture Notes

## Affected Areas

## Quality Gates

## Gotchas
