# Module Map — KindWords

> Living document. Foundation baseline created 2026-03-20.

## Modules

| Module | Responsibility | Owns | Depends on |
|--------|----------------|------|-----------|
| app-bootstrap | App startup, plugin initialization, provider registration, route wiring | `lib/main.dart` (planned) | providers, notification service |
| quote-domain | Immutable quote contract and embedded dataset | `lib/models/quote.dart`, `lib/data/quotes_data.dart` | — |
| quote-selection | Random quote retrieval and no-immediate-repeat logic | `lib/services/quote_service.dart` | quote-domain |
| favorites | Favorite quote persistence and favorites state exposure | `lib/services/favorites_service.dart`, `lib/providers/favorites_provider.dart` (planned) | quote-domain, quote-selection, shared_preferences |
| notifications | Daily notification scheduling, saved notification settings, reboot rescheduling | `lib/services/notification_service.dart` | quote-selection, shared_preferences, flutter_local_notifications, timezone |
| home-ui | Current quote display, primary CTA, save-favorite action | `lib/screens/home_screen.dart` (planned), `lib/providers/quote_provider.dart` (planned) | quote-selection, favorites |
| favorites-ui | List, empty state, and delete flow for saved quotes | `lib/screens/favorites_screen.dart` (planned) | favorites |
| settings-ui | Notification enablement and time selection UX | `lib/screens/settings_screen.dart` (planned) | notifications |

## Boundary Rules

- `quote-domain` is pure data and model code; it never imports providers, screens, or plugin packages.
- UI modules (`home-ui`, `favorites-ui`, `settings-ui`) interact through providers or service-facing interfaces, not direct cross-screen state mutation.
- `notifications` owns all alarm/plugin concerns; other modules do not call plugin APIs directly.
- `favorites` persists quote IDs, not full quote payloads; quote reconstruction stays aligned with `quote-domain`.
- `app-bootstrap` may wire dependencies together, but business behavior stays out of `main.dart`.

## Current Gaps Against Target Module Map

- `app-bootstrap` is planned in `AGENTS.md` but `lib/main.dart` is not present yet.
- All three UI modules are planned in `AGENTS.md` but no screen files exist yet.
- Provider layer is planned in `AGENTS.md` but `lib/providers/` is not present yet.
- Existing code already covers `quote-domain`, `quote-selection`, `favorites`, and most of `notifications` at the service layer.

## Initial Rationale Notes

- 2026-03-20: Kept the module split small and behavior-oriented because KindWords is a single-app offline project with no backend boundary.
- 2026-03-20: Separated `notifications` from generic settings logic because Android alarm behavior is the highest-risk integration surface.
