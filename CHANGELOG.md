# Changelog

All notable changes to KindWords are documented here.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).  
Versioning follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [Unreleased]

### Fixed
- Scheduled notifications now fire correctly on all tested Android devices — the missing `ScheduledNotificationReceiver` broadcast receiver has been registered in the Android manifest.

### Removed
- Temporary in-app test notification buttons and scheduled-test slider removed from the Settings screen; the screen now shows only production-relevant controls.

### Added
- Notification debug UI (test-send button, scheduled-test slider, countdown timer) restored behind a compile-time flag: launch with `--dart-define=KINDWORDS_DEBUG_NOTIFICATIONS=true` to reveal the section. Invisible and tree-shaken in normal/release builds.

---

## [1.0.0] — 2026-03-26

First public release. All three core user journeys ship fully offline.

### Added

**Quote experience**
- Home screen displays a random motivational quote from a catalog of 110 embedded quotes
- "Get Motivation" button refreshes the quote with a fade animation — no immediate repeats
- Quotes are seeded into a local SQLite database on first launch and served from there at runtime

**Favorites**
- Heart icon button in the app bar saves or unsaves the current quote
- Favorites screen shows all saved quotes in a scrollable list
- Each saved quote has a delete button — removals take effect immediately
- Empty state message shown when no favorites have been saved yet
- Favorites survive app restarts and device reboots (stored via SharedPreferences)
- Duplicate saves are prevented — saving the same quote twice results in one entry

**Daily notifications**
- Settings screen lets the user pick any time of day for a daily reminder
- Notification body contains a random motivational quote from the catalog
- Changing the time replaces the previous schedule — at most one active reminder at a time
- Toggle to enable or disable the daily reminder
- Chosen time and enabled state persist across restarts
- Boot receiver reschedules the notification after device reboot automatically

**Android permissions (runtime)**
- Exact alarm permission requested before scheduling on Android 12+ (API 31+)
- Notification permission requested on first launch on Android 13+ (API 33+)
- Permission-denied states handled gracefully — app remains fully usable

**Technical foundation**
- Clean architecture: SQLite database → repository → service → provider → UI
- 140 automated tests (unit + widget) covering all three feature areas
- Strict static analysis (`strict-casts`, `strict-inference`, `strict-raw-types`)
- `@pragma('vm:entry-point')` on boot callback — survives release tree-shaker

### Technical details

| Item | Value |
|------|-------|
| Flutter version | stable (fvm) |
| Min Android SDK | API 21 (Android 5.0) |
| Target Android SDK | API 34 (Android 14) |
| APK size (release) | ~31 MB |
| Quote catalog | 110 unique quotes |
| Test coverage | 140 passing, 5 skipped (platform-channel) |

---

## [1.1.1] — 2026-03-29

### Fixed
- Scheduled notifications now work correctly: the Android receivers required by `flutter_local_notifications` are registered in the app manifest, so AlarmManager-delivered broadcasts are no longer silently dropped.
- Notification scheduling now includes stronger Android-side diagnostics and a temporary in-app scheduled test flow to verify delivery during debugging.
- Notification scheduling and delivery on Android now use the correct local timezone, a high-importance channel, and improved user guidance around exact alarms and battery optimization.

---

## [1.1.0] — 2026-03-29

### Added
- Quotes is now a top-level bottom navigation destination (Home → Quotes → Favorites → Settings), giving direct one-tap access to the full quote catalog from anywhere in the app.
- Quote CRUD foundation: local SQLite schema migrated from v1 to v2, adding tags, source, and timestamp fields to every stored quote. Existing quotes are preserved and enriched with safe defaults — no data loss or reinstall required.
- Quote CRUD data-access and catalog state foundation: `QuoteDatabase` gains insert, update, delete, getBySource, and getByTag methods; `QuoteRepositoryBase` and `LocalQuoteRepository` expose the same CRUD interface; new `QuoteCatalogProvider` owns full catalog state with reactive source and tag filters; `QuoteProvider` adds `refreshCurrentIfStale` continuity hook; `FavoritesProvider` adds `reload()` continuity hook.
- Quote Catalog screen (`/quotes`): browse and filter the full local quote collection by source (All / Seeded / Mine) and predefined tag; each row shows quote text, author or anonymous fallback, source icon, tags, and edit/delete action buttons.
- Quote create flow: new `QuoteFormScreen` allows users to write their own quotes with text (≥10 chars), optional author, and up to 3 predefined tags; quotes are saved locally with source `userCreated` and a generated timestamp; the Quote Catalog exposes create entry points via an AppBar `+` icon and a `"New Quote"` floating action button; after a successful save the catalog reloads automatically to include the new quote.
- Quote edit and delete flows: any quote in the local collection (seeded or user-created) can now be edited or deleted; editing a quote pre-populates all fields and preserves the original id, creation timestamp, and source; deleting from the form requires an AlertDialog confirmation; deleting from the catalog row requires a bottom-sheet confirmation; after either mutation the catalog automatically refreshes.

### Changed
- Favorites screen now exposes edit and delete actions for each saved quote — tapping the edit icon opens the quote form in edit mode, and returning after a save or delete automatically refreshes the favorites list so stale entries are never shown.

---

<!-- Roadmap items tracked in README.md §Roadmap -->
