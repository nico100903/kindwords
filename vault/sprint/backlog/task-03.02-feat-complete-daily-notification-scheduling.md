---
id: "03.02"
title: "Complete daily notification scheduling"
type: feat
priority: high
complexity: L
difficulty: moderate
sprint: 3
depends_on: ["03.01"]
blocks: ["03.03", "03.04"]
parent: "03"
branch: "feat/task-03-daily-notifications-and-release-readiness"
assignee: dev
enriched: true
---

# Task 03.02: Complete Daily Notification Scheduling

## Business Requirements

### Problem
The settings controls only matter if the app actually schedules and cancels a reliable daily reminder. This task turns stored notification preferences into real daily local behavior with quote content.

### User Story
As a user, I want my chosen reminder time to produce one daily motivational notification so that the app supports my routine even when closed.

### Acceptance Criteria
- [ ] Enabling daily reminders schedules exactly one local notification per day at the selected time.
- [ ] The notification body contains a motivational quote from the bundled catalog.
- [ ] Changing the reminder time replaces the prior schedule with the new daily time.
- [ ] Disabling daily reminders cancels the scheduled reminder.

### Business Rules
- The product supports one scheduled reminder per day, not multiple concurrent reminder times.
- Notification content must come from the embedded quote catalog.
- Schedule changes must leave at most one active daily reminder.

### Out of Scope
- Android runtime permission prompts.
- Reboot-triggered restore behavior.
- Release verification and demo checklist.

---
<!-- TECHNICAL GUIDANCE - written by Tech Lead below this line -->
<!-- Do not modify Business Requirements when enriching -->

## Architecture Notes

**Axis: Scheduled side-effect timing.** The core challenge is ensuring Android's exact alarm scheduling behaves correctly across app lifecycle events. The implementation uses `zonedSchedule` with `DateTimeComponents.time` for daily repeat — this is the correct pattern for fixed-time recurring notifications.

**Current state (HEAD `ad93003`):** Task 03.01 implemented most of the wiring. `NotificationService.scheduleDailyNotification()` already:
1. Cancels any existing notification before rescheduling (ensures single-active constraint)
2. Fetches a random quote via `QuoteService.getRandomQuote()`
3. Uses `zonedSchedule` with `matchDateTimeComponents: DateTimeComponents.time` for daily repeat
4. Persists enabled/hour/minute to SharedPreferences

**What remains:** Verification on physical device that notifications fire at the scheduled time. The code is structurally complete but Android notification behavior varies by OEM and battery optimization settings.

**Key invariant:** `_notificationId` (1001) is hardcoded — this ensures cancel-before-reschedule always targets the same notification. Do not change this ID.

## Affected Areas

- `lib/services/notification_service.dart` — primary implementation (lines 63–96 for scheduling)
- `lib/screens/settings_screen.dart` — UI triggers scheduling (lines 51–94)
- `lib/main.dart` — service initialization and Provider wiring (lines 18–21, 33)

## Quality Gates

1. **Schedule verification:** On a physical Android device, enable notifications at a time 2 minutes in the future. Verify notification appears with quote text. Repeat 3 times with different times.
2. **Cancel verification:** Enable notifications, then disable. Wait past scheduled time. Verify no notification appears.
3. **Reschedule verification:** Enable at time T1, then change to time T2 (both in future). Verify only T2 notification fires.
4. **Quote content check:** Trigger 5 notifications; verify each has non-empty `quote.text` from the catalog.

## Gotchas

- **OEM battery optimization:** Xiaomi, Samsung, and Huawei devices may kill exact alarms in power-saving mode. This is out of scope for this task but document the behavior if observed.
- **Timezone initialization:** `tz_data.initializeTimeZones()` is called but `tz.local` is not explicitly set — flutter_local_notifications uses the device local timezone by default. If notifications fire at wrong times, investigate explicit `tz.setLocalLocation()`.
- **Quote only shows text:** Author is not included in notification body. This matches the simple UX requirement — do not add author without explicit request.
