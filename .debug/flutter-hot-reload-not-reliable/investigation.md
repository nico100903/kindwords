# Investigation: Flutter hot reload not reliably reflecting code changes
Started: 2026-03-21 00:00
Status: DIAGNOSING

## Symptom
`fvm flutter run` launches successfully on a physical Android device, but subsequent code changes often do not appear through the normal hot reload workflow, forcing the user to stop the app and rerun `fvm flutter run`.

## Environment
- Project: KindWords Flutter Android app
- Platform: Linux host, Android target device
- Tooling: `fvm flutter run`
- Recent change areas: startup/service wiring, provider setup, notification initialization, settings screen state, home screen animation updates

## Fingerprint
- **Error signature**: Hot reload appears ineffective; user must terminate and relaunch `fvm flutter run`
- **Error code**: none reported
- **Stack trace top frame**: none reported
- **Stack/runtime**: Flutter app, Android device, FVM-managed SDK
- **Component**: Flutter dev loop / app startup / stateful UI refresh boundaries
- **Tags**: hot-reload, hot-restart, initialization, flutter, fvm, android-device

## Hypothesis Stack

### H1 (top): Recent edits are landing in startup-only code paths that Flutter hot reload does not re-execute, so the app looks unchanged until a full restart.
**Confidence**: high
**Rationale**: Reported change areas include app startup, provider wiring, and initialization, which are classic hot-restart/full-restart boundaries.
#### Iteration 1: Inspect startup wiring in app entrypoint
- **Ran**: `read lib/main.dart`
- **Found**: `main()` constructs services, awaits `notificationService.initialize()`, and creates providers before `runApp()`.
- **Meaning**: changes to service wiring, provider setup, and notification initialization are not re-executed by hot reload.
- **Impact**: SUPPORTS — local code structure matches Flutter's documented hot-restart boundary.

#### Iteration 2: Inspect provider and notification initialization paths
- **Ran**: `read lib/providers/quote_provider.dart`, `read lib/providers/favorites_provider.dart`, `read lib/services/notification_service.dart`
- **Found**: both providers do constructor-time initialization; notification plugin/timezone/channel setup occurs in `initialize()` and is documented as `main()`-time setup.
- **Meaning**: several recent change areas fall in one-time initialization flows.
- **Impact**: SUPPORTS — these edits would often appear to require restart even when hot reload itself succeeds.

#### Iteration 3: Compare against Flutter hot reload semantics
- **Ran**: `websearch` / `codesearch` for Flutter hot reload `main()` and `initState()` behavior
- **Found**: official docs say hot reload rebuilds widgets but does not rerun `main()` or `initState()`; recent UI changes can be excluded if modified code is not re-executed.
- **Meaning**: the behavior expected by the user conflicts with Flutter's documented semantics for these change types.
- **Impact**: SUPPORTS — strongest current explanation.
**Status**: INVESTIGATING

### H2: The `flutter run` session is stale or detached from the active device/app process, so reload commands are not reaching the running instance consistently.
**Confidence**: medium
**Rationale**: User specifically says they must Ctrl+C and rerun, which can indicate a session attachment/device targeting problem rather than an app-code problem alone.
#### Iteration 1: Check toolchain and visible devices
- **Ran**: `fvm flutter --version && fvm dart --version`; `fvm flutter devices`
- **Found**: stable Flutter 3.41.5 / Dart 3.11.3; Android device is detected normally.
- **Meaning**: baseline tooling and device discovery work outside a live run session.
- **Impact**: NEUTRAL — stale session remains possible, but no direct evidence yet.

#### Iteration 2: Look for project-local signs of session-specific reload bugs
- **Ran**: external research on FVM/session issues plus repo inspection for stronger app-structure explanations
- **Found**: local code strongly explains restart-needed edits; external sources mention possible `flutter run`/FVM issues but without repo-specific proof.
- **Meaning**: session/tooling is a fallback hypothesis pending live console capture from a failing `r`.
- **Impact**: CONTRADICTS — weaker than H1 with current evidence.
**Status**: INVESTIGATING

### H3: Some visible UI areas are not rebuilding because state/animation/config is initialized once and retained across reload, masking code changes until restart.
**Confidence**: low
**Rationale**: Home animation and settings state changes can appear stuck when widgets preserve state or initialization is outside `build`/reload-friendly flows.
#### Iteration 1: Inspect home/settings UI code for preserved-state masking
- **Ran**: `read lib/screens/home_screen.dart`; `read lib/screens/settings_screen.dart`
- **Found**: `HomeScreen` uses `AnimatedSwitcher` in `build()` without `AnimationController`; `SettingsScreen` loads settings asynchronously outside `build()`.
- **Meaning**: settings logic can preserve old state across reload, but there is no strong evidence of an animation-specific hot reload defect.
- **Impact**: NEUTRAL — localized masking is possible, not the primary explanation.

#### Iteration 2: Search for root-key/controller anti-patterns
- **Ran**: `grep UniqueKey|GlobalKey|AnimationController`
- **Found**: no matches for these patterns in `lib/`.
- **Meaning**: common causes of tree recreation or animation-controller reload issues are absent.
- **Impact**: CONTRADICTS — lowers confidence in H3.
**Status**: INVESTIGATING
