---
id: "03.01"
title: "Build settings screen and notification preferences"
type: feat
priority: high
complexity: M
difficulty: moderate
sprint: 2
depends_on: ["01.01"]
blocks: ["03.02"]
parent: "03"
branch: "feat/task-03-daily-notifications-and-release-readiness"
assignee: dev
enriched: true
---

# Task 03.01: Build Settings Screen And Notification Preferences

## Business Requirements

### Problem
Users need a clear place to control their daily reminder, otherwise notification behavior feels hidden and unpredictable. This task establishes the visible settings experience for turning reminders on or off and selecting a reminder time.

### User Story
As a user, I want a settings screen where I can control whether and when daily motivation appears so that the app fits my routine.

### Acceptance Criteria
- [ ] The app exposes a settings destination reachable from the main experience.
- [ ] The settings destination includes a daily notification on/off control.
- [ ] The settings destination includes a time selection control for the daily reminder.
- [ ] The currently chosen notification state and time remain visible after the user leaves and reopens the app.

### Business Rules
- Notification settings consist of exactly one enablement state and one daily time.
- The reminder time uses a 24-hour range of 00:00 through 23:59.
- Users must be able to disable daily reminders after enabling them.

### Out of Scope
- Actual notification delivery behavior.
- Android permission request flow.
- Reboot recovery behavior.

---
<!-- TECHNICAL GUIDANCE - written by Tech Lead below this line -->
<!-- Do not modify Business Requirements when enriching -->

## Architecture Notes

**Axis:** State lifecycle + UI-binding — settings must persist via SharedPreferences and reflect accurately on screen load.

**Pattern:** StatefulWidget with async init, calling NotificationService for persistence. No new Provider class needed.

**Rationale:** NotificationService already owns the persistence keys (`notification_enabled`, `notification_hour`, `notification_minute`) and provides `loadSettings()`, `scheduleDailyNotification()`, and `cancelNotification()`. Creating a NotificationProvider would follow existing patterns but adds complexity for a single-screen concern. Instead:

1. Expose `NotificationService` as a Provider value (not ChangeNotifier) in `main.dart`
2. SettingsScreen reads via `context.read<NotificationService>()`
3. StatefulWidget manages local UI state; calls service methods for persistence

**DO:**
- Convert `SettingsScreen` from StatelessWidget to StatefulWidget
- Call `notificationService.loadSettings()` in `initState()` to populate initial values
- Use `Switch` widget for enable/disable toggle
- Use `showTimePicker()` with 24-hour format for time selection
- Call `scheduleDailyNotification(hour, minute)` when toggle is switched ON
- Call `cancelNotification()` when toggle is switched OFF
- Display current time using `TimeOfDay(hour, minute).format(context)`
- Add `Provider.value(value: notificationService)` in `main.dart` MultiProvider

**AVOID:**
- Bypassing NotificationService to write SharedPreferences directly (violates module boundary)
- Creating a full ChangeNotifier Provider for notification state (over-engineering for one screen)
- Calling permission request APIs (explicitly out of scope — Task 03.02)
- Scheduling logic beyond what `scheduleDailyNotification`/`cancelNotification` already provide

**Constraints:**
- Settings must survive cold start (kill app, relaunch)
- Time picker must show 24-hour format (per SPEC: 00:00–23:59)
- Toggle state must accurately reflect persisted `notification_enabled` value on load

## Affected Areas

- `lib/screens/settings_screen.dart` — convert to StatefulWidget, add toggle + time picker UI
- `lib/main.dart` — add `Provider.value(value: notificationService)` to MultiProvider

## Quality Gates

1. **Persistence verification:** Change toggle → kill app → relaunch → toggle reflects saved state
2. **Time persistence:** Change time to 14:30 → kill app → relaunch → displayed time is 14:30
3. **Toggle OFF persists:** Switch toggle OFF → kill app → relaunch → toggle is OFF
4. **No crash on fresh install:** First launch with no saved preferences shows defaults (disabled, 08:00) without crash
5. **`flutter analyze`** passes with zero errors

## Gotchas

1. **NotificationService not in widget tree yet** — `main.dart` instantiates it but doesn't expose it via Provider. You MUST add `Provider.value(value: notificationService)` to MultiProvider before SettingsScreen can access it.

2. **`loadSettings()` returns defaults, not null** — The method returns `(enabled: false, hour: 8, minute: 0)` when no preferences exist. UI cannot distinguish "user set 8:00" from "no saved value" — this is acceptable per SPEC defaults.

3. **`scheduleDailyNotification` persists enabled=true automatically** — You don't need to separately save the enabled state; the method sets `notification_enabled: true` internally.

4. **`cancelNotification` persists enabled=false automatically** — Same as above; the method handles persistence.

5. **TimeOfDay.format() respects device locale** — For 24-hour enforcement, consider manual formatting (`${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}`) if locale produces AM/PM.
