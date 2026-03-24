# Hypotheses

## H1
- Statement: Recent edits are concentrated in startup-only code paths that hot reload does not re-run.
- Confidence: high
- Evidence status: supported by `lib/main.dart`, provider constructors, `NotificationService.initialize()`, and official Flutter hot reload docs

## H2
- Statement: The active `fvm flutter run` session or target attachment is stale/wrong, so reloads do not reach the intended app instance.
- Confidence: medium
- Evidence status: possible but unconfirmed; device discovery works and no failing live-session logs were captured

## H3
- Statement: App structure preserves state/animation/init in ways that hide UI changes after reload even when the VM accepts the reload.
- Confidence: low
- Evidence status: some settings-state masking is plausible, but no `AnimationController`/root-key evidence found
