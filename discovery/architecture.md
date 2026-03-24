# Architecture — KindWords

**Status:** Foundation baseline  
**Last updated:** 2026-03-20

## Architecture Summary

KindWords uses a single-process Flutter architecture with embedded data and local device services only. There is no backend boundary; the main architectural risk is Android notification scheduling rather than distributed systems complexity.

## System Shape

- Client-only Android Flutter app
- Embedded quote catalog in Dart source
- Provider-managed UI state for current quote and favorites
- `shared_preferences` for lightweight persistence
- `flutter_local_notifications` plus timezone support for daily notifications

## Architectural Decisions

### 1. Layer-first structure
- Use `models/`, `data/`, `services/`, `providers/`, and `screens/` under `lib/`
- Rationale: the app is small, offline, and has only three core features; feature-first structure would add nesting without reducing complexity

### 2. Stable quote IDs as the core contract
- `Quote.id` is the durable reference shared across random selection, favorites persistence, and notification payload generation
- Rationale: storing quote IDs keeps persistence small and avoids serializing entire quote objects into preferences

### 3. Providers own presentation state, services own behavior
- Providers translate UI actions into state updates
- Services encapsulate randomization, persistence, and notification plugin integration
- Rationale: this keeps Flutter widget code thin and isolates plugin-specific logic from screens

### 4. Notification flow is an infrastructure concern inside the app
- Notification scheduling remains in a dedicated service module rather than screen code
- Rationale: exact alarm permissions, timezone setup, and reboot recovery are the most platform-specific parts of the app

## Module Breakdown

### App Bootstrap
- Planned files: `lib/main.dart`
- Responsibilities: initialize timezone/plugin state, register providers, build `MaterialApp`, route to screens

### Domain Model
- Existing file: `lib/models/quote.dart`
- Responsibility: immutable quote entity with stable ID equality

### Embedded Data
- Existing file: `lib/data/quotes_data.dart`
- Responsibility: source of truth for bundled quotes
- Current state: sample dataset only; must be expanded in implementation phase

### Quote Selection Service
- Existing file: `lib/services/quote_service.dart`
- Responsibility: random selection and ID lookup without immediate repeat

### Favorites Persistence Service
- Existing file: `lib/services/favorites_service.dart`
- Responsibility: store and restore favorite quote IDs from `shared_preferences`

### Notification Service
- Existing file: `lib/services/notification_service.dart`
- Responsibility: notification channel creation, schedule/cancel behavior, preference persistence, reboot rescheduling
- Current state: interface and basic scheduling path exist; permission handling and Android integration still need implementation validation

### Presentation State
- Planned files: `lib/providers/quote_provider.dart`, `lib/providers/favorites_provider.dart`
- Responsibility: bridge services into reactive UI state

### Screens
- Planned files: `lib/screens/home_screen.dart`, `lib/screens/favorites_screen.dart`, `lib/screens/settings_screen.dart`
- Responsibility: user interactions, navigation, and visual presentation

## Dependency Rules

- Screens may depend on providers and presentational widgets only
- Providers may depend on services and models
- Services may depend on models, data, plugins, and persistence packages
- Data and models must not import UI layers
- Notification-specific Android concerns stay inside notification-related modules and bootstrap wiring

## Data Contracts

### Quote entity
```dart
class Quote {
  final String id;
  final String text;
  final String? author;
}
```

### SharedPreferences keys
- `favorite_quote_ids` -> JSON `List<String>`
- `notification_enabled` -> `bool`
- `notification_hour` -> `int`
- `notification_minute` -> `int`

## Primary Runtime Flows

### Quote refresh
1. Home screen calls `QuoteProvider`
2. `QuoteProvider` requests a new quote from `QuoteService`
3. `QuoteService` reads from `kAllQuotes`
4. Provider notifies listeners and UI animates the new quote

### Favorite save/remove
1. Home or Favorites screen triggers `FavoritesProvider`
2. Provider delegates to `FavoritesService`
3. Service updates stored IDs in `shared_preferences`
4. Provider refreshes in-memory favorites list

### Daily notification schedule
1. Settings screen updates notification preference/time
2. Notification service validates schedule prerequisites
3. Service schedules the plugin notification and persists settings
4. On reboot, Android receiver/bootstrap path calls reschedule from saved settings

## Key Risks And Mitigations

### Risk: Exact alarm and notification permission mismatch
- Mitigation: isolate permission checks and schedule calls inside notification service and test on API 31+

### Risk: Planned UI files do not yet exist
- Mitigation: Plan phase should create provider and screen tasks before higher-risk notification polish

### Risk: Quote dataset under release target
- Mitigation: treat quote catalog expansion as an early implementation task because multiple acceptance criteria depend on it

## Recommended Planning Sequence

1. Create app bootstrap, providers, and screen shell
2. Expand quote catalog and finish quote browsing flow
3. Implement favorites end-to-end
4. Finish notification permission and scheduling flow
5. Run QA hardening on analyzer, tests, and demo path

## Foundation Exit Assessment

The architecture is now defined well enough for Plan because the module boundaries, dependency rules, state ownership, persistence contracts, and implementation sequence are explicit.
