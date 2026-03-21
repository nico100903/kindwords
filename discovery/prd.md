# PRD — KindWords

**Status:** Foundation baseline  
**Last updated:** 2026-03-20

## Product Summary

KindWords is an offline Android Flutter app that gives users a fast mood boost through random motivational quotes, daily local notifications, and locally saved favorites. The product is intentionally small-scope: no backend, no accounts, no network dependency, and no cloud sync.

## Problem

Students and other Android users often want a quick emotional reset during stressful days, but many wellness apps add friction through accounts, ads, or internet dependency. KindWords solves the smaller, more immediate problem: one tap should produce a positive message, and one daily reminder should reinforce the habit.

## Users

- Primary: university students using Android phones in low-connectivity or no-connectivity situations
- Secondary: any Android user who wants lightweight daily motivation without setup overhead

## Product Goals

- Deliver a working offline Android app for the midterm deadline
- Make the primary quote interaction feel instant and simple
- Persist favorites and notification settings across app restarts
- Keep implementation small enough for a 3-5 week student project

## Non-Goals

- iOS support
- User accounts or personalization profiles
- Cloud backup or cross-device sync
- Remote push notifications
- Social sharing, quote categories, or analytics

## Core User Journeys

### Journey 1 — Get a new quote
1. User opens the app.
2. Home screen shows a quote immediately.
3. User taps `Get Motivation`.
4. App shows a different random quote with a lightweight animation.

### Journey 2 — Save a favorite
1. User sees a quote they like.
2. User taps the favorite control.
3. App stores the quote locally.
4. User opens Favorites and sees the saved item.

### Journey 3 — Schedule daily motivation
1. User opens Settings.
2. User enables daily notifications.
3. User picks a time.
4. App schedules one local notification per day and restores that schedule after reboot.

## Functional Requirements

### FR-1 Home quote experience
- The app must show a quote on first launch of the home screen.
- The home screen must expose a primary action to fetch another quote.
- The next quote must not immediately repeat the current quote when more than one quote exists.
- Quote text must remain readable on typical Android phone sizes.

### FR-2 Embedded quote catalog
- Quotes must be bundled in-app as Dart data.
- The release target is 100+ unique quotes with stable IDs.
- Quote entries may include optional author attribution.

### FR-3 Favorites
- Users must be able to save the currently shown quote.
- Duplicate favorites must be prevented by quote ID.
- Favorites must persist locally across restarts and reboots.
- Favorites screen must support empty state and delete behavior.

### FR-4 Daily local notifications
- Users must be able to enable or disable daily notifications.
- Users must be able to pick one time of day.
- Scheduled notifications must use a random quote body.
- Notification settings must persist locally.
- Notifications must be restored after device reboot.

### FR-5 Android permission handling
- Android 12+ exact alarm requirements must be handled before scheduling exact daily alarms.
- Android 13+ notification permission must be requested before notifications are shown.
- Permission-denied states must fail safely without crashing the app.

## Non-Functional Requirements

- Fully offline operation; no API calls, no backend services, no accounts
- Android-first implementation using Flutter and Dart
- Quote retrieval should feel instantaneous because data is in memory
- App should remain small, understandable, and demo-safe for midterm review
- Architecture should support parallel work across UI, persistence, and notification tasks

## Implementation Constraints

- Framework: Flutter
- State management: Provider
- Local persistence: `shared_preferences`
- Notification scheduling: `flutter_local_notifications`
- Timezone handling: `timezone`
- Planned Android runtime focus: API 31+

## Current Codebase Signals

- `lib/models/quote.dart` already defines the immutable quote entity.
- `lib/data/quotes_data.dart` currently contains only 10 sample quotes and must be expanded to satisfy release scope.
- `lib/services/quote_service.dart`, `lib/services/favorites_service.dart`, and `lib/services/notification_service.dart` already establish service-level interfaces.
- UI bootstrap, providers, and screen files listed in `AGENTS.md` do not yet exist in `lib/`, so Sprint planning must account for those missing modules.

## Release Scope for First Shippable Version

- Home screen with random quote card and primary CTA
- Favorites save/remove/list flow
- Settings screen for daily notification enablement and time picker
- Local notification scheduling with reboot recovery
- Clean demo path on Android emulator or device

## Success Criteria

- User can complete the three core journeys without internet access.
- No immediate quote repeats in normal use.
- Favorites survive restart.
- Notification schedule survives restart and is restorable after reboot.
- `flutter analyze` and `flutter test` are green before release.

## Risks To Track In Planning

- Android exact alarm behavior differs by API level and permission state.
- Boot receiver integration is Android-specific and must be validated on-device or emulator.
- The current project structure references files that are not created yet, so Plan must sequence foundation UI files before feature polish.

## Foundation Handoff

This PRD is the planning baseline for `discovery/architecture.md`, `vault/ai/docs/architecture/module-map.md`, and `vault/sprint/PLAN.md`.
