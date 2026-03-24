# SPEC.md — KindWords: Daily Motivation Generator

**Version:** 1.0  
**Author:** Alcantara  
**Course:** Application Development and Emerging Technologies  
**Institution:** University of Nueva Caceres, School of Computer and Information Sciences  
**Platform:** Android only (Flutter/Dart)  
**Last updated:** 2026-03-18

---

## 1. Product Overview

KindWords is a fully offline Android app that delivers random motivational quotes, compliments, and positive affirmations on demand. It targets students and anyone who needs a quick mood lift during stressful days. The app requires no internet connection, no user account, and no server — all data is embedded in the app.

### 1.1 Problem Statement

Students face daily stress and sometimes need an instant, effortless pick-me-up. Existing wellness apps are overengineered, require internet, or demand account creation. KindWords provides immediate positive reinforcement with a single tap.

### 1.2 Solution

A single-purpose Android app with:
- One big "Get Motivation" button → displays a random quote with animation
- Daily scheduled local notification at a user-configured time
- Ability to save and revisit favorite quotes (persisted locally)

---

## 2. Target Users

- **Primary:** University students (Philippines, Android users)
- **Secondary:** Anyone needing daily positive reinforcement

---

## 3. Platform & Constraints

| Constraint | Value |
|------------|-------|
| Platform | Android only |
| Framework | Flutter (Dart) |
| Min SDK | API 21 (Android 5.0) |
| Target SDK | API 34 (Android 14) |
| Compile SDK | API 34 |
| Network | None — fully offline |
| Backend | None |
| Accounts | None |
| Analytics | None |

---

## 4. Features

### 4.1 Feature 1 — One-Tap Random Quote (P0)

**Description:** The main screen displays a motivational quote. Tapping the "Get Motivation" button replaces the current quote with a new random one, with an animation.

**Acceptance Criteria:**
- [ ] App opens to a screen showing a motivational quote
- [ ] A "Get Motivation" button is prominently visible
- [ ] Tapping the button loads a new random quote (no immediate repeat of the same quote)
- [ ] The new quote appears with a fade-in or slide animation
- [ ] The quote text is legible (min 16sp, wraps correctly on all screen sizes)
- [ ] At least 100 unique quotes are embedded in the app
- [ ] No network call is made at any point

**Data:** Embedded Dart `List<Quote>` in `lib/data/quotes_data.dart`

---

### 4.2 Feature 2 — Daily Scheduled Notification (P0)

**Description:** The user can pick a specific time of day. The app schedules a daily local notification at that time containing a random motivational quote.

**Acceptance Criteria:**
- [ ] Settings screen allows user to pick notification time via time picker
- [ ] Notification fires daily at the chosen time
- [ ] Notification contains a random motivational quote in the body
- [ ] Notification is re-scheduled after device reboot (RECEIVE_BOOT_COMPLETED)
- [ ] User can disable the notification
- [ ] Exact alarm permission is requested at runtime on Android 12+ (API 31+)
- [ ] POST_NOTIFICATIONS permission is requested at runtime on Android 13+ (API 33+)
- [ ] Chosen time persists across app restarts (stored in shared_preferences)

**Android Permissions:**
- `RECEIVE_BOOT_COMPLETED`
- `SCHEDULE_EXACT_ALARM`
- `USE_EXACT_ALARM`
- `POST_NOTIFICATIONS` (runtime, Android 13+)

---

### 4.3 Feature 3 — Favorites (P0)

**Description:** The user can save any displayed quote to a favorites list. Favorites are persisted locally using shared_preferences and survive app restarts.

**Acceptance Criteria:**
- [ ] Home screen shows a "Save to Favorites" / heart icon button for the current quote
- [ ] Saved quotes appear in the Favorites screen
- [ ] Favorites screen is reachable from the main screen (nav bar or button)
- [ ] User can delete individual favorites from the list
- [ ] Favorites list is empty-state friendly (shows a message when no favorites saved)
- [ ] Favorites persist across app restarts and device reboots
- [ ] Duplicate saves are prevented (same quote cannot be added twice)

**Storage:** `shared_preferences` — serialized JSON list of quote IDs

---

## 5. Data Model

### 5.1 Quote

```dart
class Quote {
  final String id;       // Unique identifier (e.g., UUID or index-based)
  final String text;     // The quote text
  final String? author;  // Optional attribution
}
```

### 5.2 Favorites Store

Stored as a JSON-encoded list of quote IDs in `shared_preferences`:

```
Key: "favorite_quote_ids"
Value: JSON-encoded List<String>  // e.g., ["q001", "q042", "q099"]
```

### 5.3 Notification Settings

```
Key: "notification_enabled"    Value: bool
Key: "notification_hour"       Value: int  (0–23)
Key: "notification_minute"     Value: int  (0–59)
```

---

## 6. Screen Map

```
App Start
  └── HomeScreen (default route "/")
        ├── [Top right] → FavoritesScreen ("/favorites")
        └── [Settings icon] → SettingsScreen ("/settings")
```

### 6.1 HomeScreen

- App bar with title "KindWords" + favorites icon + settings icon
- Large quote card in the center (text + optional author)
- Save-to-favorites button (heart icon, toggles filled/unfilled)
- "Get Motivation" button at the bottom
- Fade animation on quote change

### 6.2 FavoritesScreen

- App bar "My Favorites" with back button
- Scrollable list of saved quotes
- Each item: quote text + optional author + delete button
- Empty state: "No favorites yet. Start saving quotes you love!"

### 6.3 SettingsScreen

- App bar "Settings" with back button
- Toggle: "Daily Notification" (on/off)
- Time picker row: "Notification Time" → opens TimePickerDialog
- Current scheduled time displayed
- Save button or auto-save on change

---

## 7. Non-Functional Requirements

| Requirement | Target |
|-------------|--------|
| Cold start time | < 2 seconds |
| Quote load time | < 100ms (in-memory) |
| Crash rate | 0 crashes in demo |
| APK size | < 20 MB |
| Min Android version | Android 5.0 (API 21) |
| Accessibility | Minimum 4.5:1 contrast ratio on quote text |

---

## 8. Out of Scope

- iOS support
- Cloud sync or backup
- User accounts / login
- Push notifications from a server
- Social sharing
- Quote categories or tags (nice-to-have, deferred)
- Dark mode (nice-to-have, deferred)
- Localization / multi-language

---

## 9. Dependencies

```yaml
flutter_local_notifications: ^17.0.0   # Daily notification scheduling
timezone: ^0.9.4                        # Required by flutter_local_notifications
shared_preferences: ^2.3.2              # Favorites + settings persistence
provider: ^6.1.2                        # State management
```

---

## 10. Deliverables

1. Working Android APK (tested on emulator + physical device)
2. GDD-style documentation (4–6 pages)
3. GitHub repository with README, pubspec.yaml, and clean commit history
4. `docs/ARCHITECTURE.md` — technical architecture document

---

## 11. Definition of Done

A feature is DONE when:
1. Code is written and committed
2. It runs without crash on Android emulator (API 31+)
3. The acceptance criteria above are all checked
4. `flutter analyze` passes with no errors
5. Manual test on physical Android device passes (or emulator if device unavailable)
