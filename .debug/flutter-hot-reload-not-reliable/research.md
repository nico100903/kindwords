# Research

## Queries Run
- `Flutter hot reload not showing changes initialization runApp provider initState notification service 2026`
- `site:docs.flutter.dev hot reload main initState provider initialization flutter run device session FVM 2026`
- `Flutter hot reload vs hot restart changes to main() runApp provider initialization initState notification service`

## Top Findings
1. Official Flutter docs: hot reload rebuilds the widget tree but does not re-run `main()` or `initState()`; code changes only have visible effect if that code is executed again.
2. Official docs: recent UI changes can appear excluded after a successful reload when the modified code is not downstream of the current rebuild path.
3. External issue reports mention stale-session/FVM/device attachment problems, but these are secondary until a failing live-session console log is captured.

## Version Applicability
- Flutter 3.41.x docs are current and match the local SDK major/minor version.
- Findings apply directly to this project's provider and notification initialization pattern.

## Sources
- https://docs.flutter.dev/tools/hot-reload (accessed 2026-03-21) — official hot reload semantics and exclusions
- https://docs.flutter.dev/development/tools/hot-reload (accessed 2026-03-21) — same official guidance under current docs path
- https://docs.flutter.dev/flutter/widgets/State/initState.html (accessed 2026-03-21) — `initState()` is called exactly once per `State` object
- https://github.com/leoafarias/fvm/issues/124 (accessed 2026-03-21) — historical FVM hot reload issue report, relevant only as secondary hypothesis
