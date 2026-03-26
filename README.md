# KindWords 💛

A fully offline Android app that delivers daily motivational quotes, lets you save your favorites, and sends a gentle daily reminder — all without an internet connection, no account required.

Built with Flutter for Android (API 21+).

---

## Features

| Feature | Description |
|---------|-------------|
| **Random quotes** | Tap "Get Motivation" to get a new quote from a catalog of 110 embedded quotes. No immediate repeats. |
| **Favorites** | Save quotes you love with the heart icon. View and delete them anytime from the Favorites screen. |
| **Daily reminders** | Set a daily notification time in Settings. The app sends a motivational quote to your lock screen every day at that time — even after a reboot. |
| **Fully offline** | No internet, no account, no tracking. Everything lives on your device. |

---

## Screenshots

> _Coming soon — run the app on an emulator or device to see it in action._

---

## Getting started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (stable channel) — or use [fvm](https://fvm.app)
- Android emulator or physical device (Android 5.0 / API 21 or higher)
- Android Studio or VS Code with Flutter extension

### Run from source

```bash
# Clone the repo
git clone https://github.com/nico100903/kindwords.git
cd kindwords

# Install dependencies
flutter pub get

# Run on a connected device or emulator
flutter run
```

### Install the release APK

Download the latest `app-release.apk` from the [Releases page](https://github.com/nico100903/kindwords/releases) and install it:

```bash
adb install app-release.apk
```

Or transfer the APK to your device and open it (you may need to allow "Install from unknown sources" in Android settings).

---

## Project structure

```
lib/
  main.dart                    # Entry point + boot recovery callback
  bootstrap/
    app_bootstrap.dart         # Dependency wiring (DB → repo → services → providers)
  models/
    quote.dart                 # Quote data model
  data/
    quotes_data.dart           # Embedded 110-quote catalog (seed source)
    quote_database.dart        # SQLite adapter (open, seed, query)
  repositories/
    quote_repository.dart      # Repository interface + local implementation
  services/
    quote_service.dart         # Random quote selection logic
    favorites_service.dart     # Favorites persistence (SharedPreferences)
    notification_service.dart  # Daily notification scheduling
  providers/
    quote_provider.dart        # Quote state (ChangeNotifier)
    favorites_provider.dart    # Favorites state (ChangeNotifier)
  screens/
    home_screen.dart           # Main screen — quote + save + refresh
    favorites_screen.dart      # Saved quotes list + delete
    settings_screen.dart       # Notification time picker + toggle
  widgets/
    quote_card.dart            # Reusable quote display card
android/
  app/src/main/
    AndroidManifest.xml        # Permissions + BootReceiver declaration
    kotlin/.../BootReceiver.kt # Reboot recovery (restarts notification schedule)
```

---

## Build commands

```bash
# Install dependencies
flutter pub get

# Analyze code (strict mode)
flutter analyze

# Run tests
flutter test

# Build release APK
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk

# Format code
dart format lib/ test/
```

---

## Tech stack

| Layer | Technology |
|-------|-----------|
| UI framework | Flutter (Dart) |
| State management | Provider |
| Local database | SQLite via sqflite |
| Notifications | flutter_local_notifications |
| Persistence | shared_preferences |
| Testing | flutter_test + mocktail |

---

## Roadmap

Planned improvements beyond the current v1.0.0 release, in priority order.

---

### v1.1 — Firebase quote pool

Replace the embedded 110-quote catalog with a live Firebase Firestore collection so the quote library can grow without requiring an app update.

**What this involves:**
- A Firestore collection `quotes/{id}` with `text`, `author`, and optional `tags` fields
- A new `RemoteQuoteRepository` that fetches from Firestore and caches locally in SQLite
- **Offline-first guarantee preserved**: if the device is offline or the fetch fails, the app serves from the local SQLite cache — no degradation in user experience
- The existing `QuoteRepositoryBase` interface already supports this swap with zero changes to the service or UI layers

**Why:** The current catalog is compiled into the APK. A Firestore-backed pool means new quotes can be published to all users instantly, themed collections become possible (exam season, graduation, Monday motivation), and the catalog can grow to thousands of entries without touching app code.

---

### v1.2 — App backend (quote management API)

Build a lightweight backend on top of the Firebase infrastructure to support quote curation, moderation, and admin tooling.

**What this involves:**
- Firebase Cloud Functions as the API layer — no separate server to manage or scale
- Endpoints: `GET /quotes/random`, `GET /quotes/{id}`, `POST /quotes` (admin-only)
- Firebase Authentication for admin access (quote submission and approval)
- A simple web admin dashboard for reviewing, editing, and publishing quotes
- Optional user-facing features: report an inappropriate quote, rate quotes

**Why:** A raw Firestore collection works for a small team but lacks access control and moderation. A backend adds rate limiting, an approval workflow, and the foundation for personalised content (e.g., serving quotes filtered by category or user preference).

---

### v2.0 — UI revamp

A visual redesign that elevates KindWords from a functional utility to something users look forward to opening every day.

**What this involves:**
- **Design system refresh:** custom typography scale, a warm and calm color palette, polished micro-animations throughout
- **Dark mode:** the codebase already uses Material 3 — the theming infrastructure is in place, dark mode is a configuration change
- **Quote card redesign:** full-bleed background gradients per quote mood, author attribution styling, share-to-clipboard button
- **Swipeable home screen:** swipe left to skip a quote, swipe right to save — replaces the button-based interaction
- **Favorites screen upgrade:** grid layout option, search by keyword or author, bulk-delete
- **Onboarding flow:** a 2-screen intro for first-time users explaining the daily notification feature and how to save favorites
- **Accessibility improvements:** larger tap targets (min 48×48dp), screen reader labels on all interactive elements, high-contrast mode

**Why:** v1.0 prioritises correctness, reliability, and clean architecture. v2.0 is where the app earns daily engagement. The clean repository pattern and extracted widget components introduced in v1.0 are specifically designed to let a UI layer be replaced without touching business logic.

---

## Academic context

This project was built as a midterm deliverable for **Application Development and Emerging Technologies** at the University of Nueva Caceres, School of Computer and Information Sciences.

**Author:** Alcantara  
**Course:** Application Development and Emerging Technologies  
**Institution:** University of Nueva Caceres, SCIS  
**Year:** 2026

---

## License

This project is for academic purposes.
