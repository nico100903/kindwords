---
description: "Compose a repo-aware handoff prompt and launch a persistent OpenCode TUI session in tmux"
agent: orchestrator
subtask: false
---

## Help

Arguments: `$ARGUMENTS`

If `$ARGUMENTS` is `--help`, print the following and stop:

~~~
handoff-project_session[session] - Compose a repo-aware handoff prompt and launch a persistent OpenCode TUI session in tmux

Usage: /handoff-project_session[session] [--window|--pane] [--agent <agent-name>] [--title <title>] [--print-only]

Flags:
  --window       Launch in a new tmux window in the current tmux session
  --pane         Launch in a split tmux pane in the current tmux window when already inside tmux
  --agent        Agent to start in the new session (default: orchestrator)
  --title        Override the handoff title embedded in the synthesized prompt and output
  --print-only   Print the synthesized handoff prompt and tmux launch plan without launching
  --help         Show this help message
  --describe     Show brief description only

Examples:
  /handoff-project_session[session]
  /handoff-project_session[session] --pane
  /handoff-project_session[session] --agent debugger --print-only
~~~

If `$ARGUMENTS` is `--describe`, print only the first line (command name + description) and stop.

---

# Project Session Handoff

Use the project-local helper at `.opencode/scripts/handoff-project-session.sh`.

What it does:
- Synthesizes a fresh-session handoff prompt from `AGENTS.md`, `vault/sprint/PLAN.md`, sprint task folders, active vault threads, and current git state.
- Launches a persistent OpenCode TUI in tmux with that prompt, defaulting to a new window and supporting a same-session split-pane path.
- Falls back to a detached tmux session when invoked outside tmux.
- Verifies the launched pane is still alive before reporting success.

## Execution

1. Verify `.opencode/scripts/handoff-project-session.sh` exists.
2. Run from the repo root:

```bash
bash ".opencode/scripts/handoff-project-session.sh" $ARGUMENTS
```

3. Relay the key results to the user:
- whether a prompt was synthesized successfully
- whether the launch target was a tmux window, pane, or detached session, including the resolved tmux target when available
- the handoff title used in the synthesized prompt and any tmux attach instructions
- the verification summary (pane exists, pane dead/alive state, current command)

## Notes

- Prefer the script instead of reimplementing the synthesis inside the command; the script is easier to verify and reuse.
- Treat `--print-only` as the safe verification path when the user wants to inspect the handoff before launching.
- When `--pane` is used inside tmux, prefer the current session and current window unless the helper reports a fallback.
- `--title` labels the synthesized handoff prompt and launch report; it does not rename tmux itself.
