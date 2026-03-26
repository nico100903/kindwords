---
id: "03.04"
title: "Run release verification"
type: test
priority: high
complexity: M
difficulty: moderate
sprint: 6
depends_on: ["02.03", "03.03"]
blocks: []
parent: "03"
branch: "feat/task-03-daily-notifications-and-release-readiness"
assignee: qa
enriched: true
---

# Task 03.04: Run Release Verification

## Business Requirements

### Problem
The project is not ready for a demo or handoff until the full offline experience is verified end to end. This task confirms that the implemented product matches the promised journeys and remains stable under standard project checks.

### User Story
As a reviewer, I want final verification of the app's core journeys so that I can trust the build for demo and submission.

### Acceptance Criteria
- [ ] Verification confirms the quote journey, favorites journey, and daily reminder journey all work without internet access.
- [ ] Static analysis completes with no errors.
- [ ] Automated tests complete successfully.
- [ ] The release candidate shows no crash during a basic demo path covering launch, quote refresh, save favorite, and notification settings.

### Business Rules
- Final verification covers the three core user journeys defined in product planning.
- Release verification is blocked until favorites and notification recovery work are complete.
- Verification must record pass or fail results for analyzer, tests, and demo path.

### Out of Scope
- New feature implementation.
- Performance benchmarking beyond standard demo readiness.
- Post-release enhancements.

---
<!-- TECHNICAL GUIDANCE - written by Tech Lead below this line -->
<!-- Do not modify Business Requirements when enriching -->

## Architecture Notes

This is a **verification-only task** — no implementation files change. The verifier runs four automated gates and four manual device journeys, records pass/fail results, and commits the completed checklist to `vault/sprint/done/task-03.04`.

### Automated Gates (run locally; reproducible in CI)

All four must exit 0 before the manual gates begin.

**Gate A — Static analysis**
```bash
/home/cmark/fvm/versions/stable/bin/flutter analyze
```
Strict analyzer config (`analysis_options.yaml`): `strict-casts`, `strict-inference`, `strict-raw-types` plus eight enforced linter rules (`always_declare_return_types`, `avoid_print`, `prefer_const_constructors`, `prefer_const_declarations`, `prefer_final_fields`, `prefer_final_locals`, `require_trailing_commas`, `sort_child_properties_last`). Note: `test/main_boot_callback_test.dart` is excluded from analysis via `analyzer.exclude` — this is intentional and correct; do not remove that exclusion.

**Gate B — Unit + widget tests**
```bash
/home/cmark/fvm/versions/stable/bin/flutter test
```
Current baseline (as of Sprint 6 completion): **140 passing, 5 skipped, 0 failures**. The 5 skips are platform-channel tests that require a real Android runtime (`main_boot_callback_test.dart` — annotated with `skip:` guards). These skips are expected and do not constitute failures.

**Gate C — Release APK build**
```bash
/home/cmark/fvm/versions/stable/bin/flutter build apk --release
```
Does **not** require a connected device — the build toolchain is self-contained. Output artifact: `build/app/outputs/flutter-apk/app-release.apk`. The build must complete without errors. Tree-shaker warnings about `notificationBootCallback` are suppressed by the `@pragma('vm:entry-point')` annotation on that function — if the build emits a tree-shaker warning or error for that symbol, it means the pragma was removed and must be restored before proceeding.

**Gate D — Dart formatter**
```bash
dart format --set-exit-if-changed lib/ test/
```
Must exit 0 (no diffs). If this fails, run `dart format lib/ test/` to auto-fix and re-run.

### Manual Gates (device required)

Run on a physical Android device (API 31+) where possible. An emulator running API 31+ is acceptable for journeys A, B, and C; **real device strongly preferred for journey D** (notification delivery through Android's exact-alarm stack).

**Journey 1 — Quote journey**
Install the release APK (`adb install build/app/outputs/flutter-apk/app-release.apk`). Launch app → confirm a quote is displayed on the home screen → tap "Get Motivation" → confirm quote changes with a visible animation → tap again → confirm a different quote appears (no immediate repeat).

**Journey 2 — Favorites journey**
From the home screen, tap the heart icon → confirm the icon toggles to filled (quote saved) → navigate to Favorites screen → confirm the saved quote appears in the list → tap the delete icon on the saved quote → confirm the quote is removed → confirm the empty-state message appears.

**Journey 3 — Notification journey**
Navigate to Settings → enable the "Daily Notification" toggle → tap the time row → set a time 2–3 minutes in the future → confirm the UI reflects the new time → exit the app (do not force-quit) → lock the device → wait for the scheduled time → confirm a notification appears on the lock screen containing a motivational quote text.

**Journey 4 — Offline check**
Enable airplane mode on the device → cold-launch the app (full process kill, not resume) → run journeys 1, 2, and 3 above. All three must complete identically with no errors, no network timeouts, and no crashes. This confirms the fully-offline guarantee.

---

## Affected Areas

No implementation files are modified by this task. The only files that change are:

- `vault/sprint/done/task-03.04-test-run-release-verification.md` — the completed verification checklist committed as the task deliverable

---

## Quality Gates

Copy this checklist into the task file's `## Changes` section and fill in results before committing:

### Automated Gates

- [ ] **Gate A — `flutter analyze`** exits 0 with "No issues found"
- [ ] **Gate B — `flutter test`** exits 0 with 140 passed, 5 skipped, 0 failed
- [ ] **Gate C — `flutter build apk --release`** exits 0; `app-release.apk` exists at `build/app/outputs/flutter-apk/app-release.apk`; no tree-shaker errors for `notificationBootCallback`
- [ ] **Gate D — `dart format --set-exit-if-changed lib/ test/`** exits 0

**All four gates must be green before manual testing begins.**

### Manual Journey Results

- [ ] **Journey 1 — Quote journey:** App launches → quote visible → tap CTA → quote changes with animation → no immediate repeat
- [ ] **Journey 2 — Favorites journey:** Heart toggles → quote saved → Favorites screen shows quote → delete removes it → empty state appears
- [ ] **Journey 3 — Notification journey:** Toggle on → set future time → notification fires at set time with quote text in body
- [ ] **Journey 4 — Offline check (airplane mode):** All three journeys above complete without internet — no crashes, no errors

### Non-Functional Checks

- [ ] Cold start feels fast (< 2 seconds subjectively from tap to quote visible)
- [ ] APK file size is within acceptable range (target: < 20 MB per SPEC.md §7)
- [ ] No crashes observed during any of the four journeys

---

## Gotchas

1. **Tree-shaker and `notificationBootCallback`:** The release build applies Dart's tree-shaker, which can eliminate code reachable only via platform-channel callbacks (not called from Dart code). The `@pragma('vm:entry-point')` annotation on `notificationBootCallback` in `main.dart` tells the tree-shaker to preserve it. If a future commit accidentally removes this pragma, the release APK will compile successfully but the boot-completed receiver will silently fail to reschedule the notification after reboot. Verify the annotation is still present before running Gate C: `grep -n "vm:entry-point" lib/main.dart`.

2. **Release APK build does not require a device:** `flutter build apk --release` is a pure build-machine operation. The device is only needed for the manual journey tests (install via `adb install`). Do not block Gate C on device availability.

3. **Emulator vs. physical device for notifications:** Android emulators running API 31+ support `flutter_local_notifications` scheduling and can trigger notifications for journeys 2 and 3. However, emulators bypass OEM battery-optimization layers (Doze, OEM killers on Xiaomi/Samsung/Oppo). Journey 3 on an emulator proves the API path works; it does not prove delivery on a real device under Doze. Physical device test is strongly preferred for the notification journey. If only an emulator is available, document this in the Changes section.

4. **Exact alarm permission on Android 12+ (API 31+):** The app requests `SCHEDULE_EXACT_ALARM` (API ≤ 32) and `USE_EXACT_ALARM` (API 33+). On first launch of the release APK, Android may present a permission dialog or redirect to the "Alarms & Reminders" system settings screen. Accept the permission during Journey 3 setup or the notification will not fire at the exact time (it may fire late or not at all).

5. **SharedPreferences and SQLite are on-device only:** There is no shared state between emulator and device. Run all four journeys on the same target (either all-emulator or all-device) to avoid cross-device state confusion.

6. **The 5 skipped tests are expected:** `test/main_boot_callback_test.dart` contains tests that invoke the Android platform channel for the boot-completed broadcast receiver. These tests are skipped on the host VM (`skip: 'requires Android platform channel'`). They are not a test suite regression — do not attempt to un-skip them or count them as failures.
