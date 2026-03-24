---
id: "01.03"
title: "Expand embedded quote catalog"
type: feat
priority: high
complexity: M
difficulty: routine
sprint: 2
depends_on: ["01.01"]
blocks: ["01.04"]
parent: "01"
branch: "feat/task-01-core-app-shell-and-quote-experience"
assignee: dev
enriched: true
---

# Task 01.03: Expand Embedded Quote Catalog

## Business Requirements

### Problem
The product promises a rich offline motivation library, but the current planning baseline only reflects a small sample set. The release scope is not credible until the bundled quote catalog reaches the minimum size promised to users.

### User Story
As a user, I want a large built-in quote library so that the app stays fresh without needing internet access.

### Acceptance Criteria
- [ ] The shipped catalog contains at least 100 unique quotes.
- [ ] Every quote has a stable unique identifier that can be reused by favorites and notifications.
- [ ] No quote entry has empty body text.
- [ ] The quote catalog remains fully bundled inside the app with no runtime download step.

### Business Rules
- The minimum release target is 100 quotes.
- Quote identifiers must remain stable once introduced.
- Author attribution is optional, but quote body text is required for every entry.

### Out of Scope
- Category tagging or search.
- Quote source attribution beyond optional author names.
- Any network-based content refresh.

---
<!-- TECHNICAL GUIDANCE - written by Tech Lead below this line -->
<!-- Do not modify Business Requirements when enriching -->

## Architecture Notes

**Axis:** Data shape — static embedded content with stable identifiers.

**Pattern:** Continue using the existing `const List<Quote>` in `lib/data/quotes_data.dart`. No changes to `Quote` model or `QuoteService` are required. The task is pure data expansion.

**ID Scheme:** Maintain the `qNNN` zero-padded format (e.g., `q011`, `q042`, `q100`). This format:
- Aligns with existing `q001`–`q010` entries
- Enables deterministic lookup via `QuoteService.getById()`
- Is used by `FavoritesService` to persist/reconstruct quote references

**Constraints:**
- Preserve existing quotes `q001`–`q010` verbatim — favorites may already reference them
- `author` is optional (`null` for anonymous quotes); `text` is required and must not be empty
- All quotes are `const` — compile-time immutable, zero runtime allocation

## Affected Areas

- `lib/data/quotes_data.dart` — primary edit target; expand `kAllQuotes` list
- `lib/services/quote_service.dart` — no changes required; `totalCount` will automatically reflect new size
- `lib/models/quote.dart` — no changes required

## Quality Gates

1. **Count threshold:** `kAllQuotes.length >= 100` — verify with `flutter test` or manual check
2. **No empty text:** Every `Quote.text` must be non-empty string — add a test that iterates and asserts
3. **Unique IDs:** No duplicate `id` values — add a test that asserts `Set(ids).length == ids.length`
4. **ID format compliance:** All IDs match pattern `q\d{3,}` — regex validation in test
5. **Analyzer passes:** `flutter analyze` returns no errors

## Gotchas

- **TODO comment mismatch:** `quotes_data.dart` references "Wave 1, Task 01.01" in its TODO comment. This is task 01.03. Update or remove the TODO when completing this task.
- **Favorites integrity:** Changing or removing existing IDs (`q001`–`q010`) will orphan saved favorites. Never modify or delete existing entries — only append.
- **Quote source:** No requirement for verified attribution. If sourcing quotes from public collections, ensure text is appropriate for the student target audience.

---
<!-- COMPLETION - appended after verification -->

## Changes
- `lib/data/quotes_data.dart` - new
- `test/quote_data_test.dart` - new
