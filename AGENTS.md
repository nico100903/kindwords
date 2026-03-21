# AGENTS.md — KindWords

## Workflow Configuration

- Git: `gitflow.config[orchestrator]`
- Tasks: `task-waves.config[orchestrator,pm]`
- Worker: `worker-scope.standard[workers]`

---

## Project Context

**KindWords** is a Flutter Android app that displays random motivational quotes, schedules daily local notifications, and persists user favorites. It is fully offline — no backend, no network code, no accounts.

- **Platform:** Android (Flutter/Dart)
- **Target API:** Android 12+ (API 31+)
- **Timeline:** 3–5 weeks (midterm deliverable)

---

## Tech Stack

| Layer | Technology | Package |
|-------|-----------|---------|
| UI framework | Flutter (Dart) | — |
| State management | Provider | `provider: ^6.1.2` |
| Local notifications | flutter_local_notifications | `flutter_local_notifications: ^17.0.0` |
| Timezone support | timezone | `timezone: ^0.9.4` |
| Persistence | shared_preferences | `shared_preferences: ^2.3.2` |
| Data | Embedded Dart list | — |

---

## Project Structure

```
lib/
  main.dart                  # App entry point, notification init
  models/
    quote.dart               # Quote data model
  data/
    quotes_data.dart         # Full 100+ quotes list
  services/
    quote_service.dart       # Random quote logic
    favorites_service.dart   # shared_preferences persistence
    notification_service.dart # flutter_local_notifications scheduling
  providers/
    favorites_provider.dart  # Provider state for favorites
    quote_provider.dart      # Provider state for current quote
  screens/
    home_screen.dart         # Main screen — random quote + button
    favorites_screen.dart    # Saved favorites list
    settings_screen.dart     # Notification time picker
```

---

## Build / Test / Lint Commands

```bash
# Get dependencies
flutter pub get

# Run on connected Android device or emulator
flutter run

# Build release APK
flutter build apk --release

# Analyze code (lint)
flutter analyze

# Run tests
flutter test

# Format code
dart format lib/
```

---

## Android Permissions Required

- `android.permission.RECEIVE_BOOT_COMPLETED` — restart notification on reboot
- `android.permission.SCHEDULE_EXACT_ALARM` — exact alarm scheduling (Android 12+)
- `android.permission.POST_NOTIFICATIONS` — runtime permission (Android 13+)
- `android.permission.USE_EXACT_ALARM` — fallback for exact alarm

---

## Agents Active for Build Phase

| Agent | Role | Scope |
|-------|------|-------|
| `pipeline/sdlc-coder[zai-coding-plan](glm-5)` | Primary coder | Feature implementation per wave |
| `pipeline/sdlc-coder[anthropic](claude-sonnet-4-6)` | Heavy coder | NotificationService (complex Android integration) |
| `sdlc-sdlc-qa[anthropic](claude-sonnet-4-6)` | QA | BDD tests, acceptance criteria verification |
| `pipeline/sdlc-tech-lead[anthropic](claude-sonnet-4-6)` | Tech lead | Architecture review, Wave 3 notification complexity |

---

## Commit Discipline — Non-Negotiable

- **The commit IS the deliverable.** Uncommitted work does not exist.
- **One logical unit = one commit** the moment it works. `wip:` commits are legitimate.
- **Verify every commit:** `git log --oneline -1` after every commit. Empty = commit failed = stop.
- **Before any destructive action:** ensure previous state is committed first.

## Core Values

Load `values.standard[all]` skill. It is the shared DNA — every agent applies it when resolving ambiguity.
