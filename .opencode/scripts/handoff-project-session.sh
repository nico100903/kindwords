#!/usr/bin/env bash
set -euo pipefail

DESCRIPTION="Compose a repo-aware handoff prompt and launch a persistent OpenCode TUI session in tmux"

usage() {
  cat <<'EOF'
handoff-project_session[session] - Compose a repo-aware handoff prompt and launch a persistent OpenCode TUI session in tmux

Usage: handoff-project-session.sh [--window|--pane] [--agent <agent-name>] [--title <title>] [--print-only]

Flags:
  --window       Launch in a new tmux window in the current tmux session
  --pane         Launch in a split tmux pane in the current tmux window when already inside tmux
  --agent        Agent to start in the new session (default: orchestrator)
  --title        Override the handoff title embedded in the synthesized prompt and output
  --print-only   Print the synthesized handoff prompt and tmux launch plan without launching
  --help         Show this help message
  --describe     Show brief description only
EOF
}

if [[ "${1:-}" == "--describe" ]]; then
  printf '%s\n' "$DESCRIPTION"
  exit 0
fi

PROJECT_DIR="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
TARGET="window"
PRINT_ONLY=0
AGENT="orchestrator"
TITLE=""
WINDOW_NAME=""
TMUX_SESSION_NAME=""
IN_TMUX=0
CURRENT_TMUX_SESSION=""
CURRENT_TMUX_WINDOW_ID=""
CURRENT_TMUX_WINDOW_INDEX=""
CURRENT_TMUX_WINDOW_NAME=""
CURRENT_TMUX_PANE_ID=""
LAUNCH_TARGET_LABEL=""
LAUNCH_TARGET_ID=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --help)
      usage
      exit 0
      ;;
    --window)
      TARGET="window"
      ;;
    --pane)
      TARGET="pane"
      ;;
    --print-only|--dry-run)
      PRINT_ONLY=1
      ;;
    --agent)
      shift
      AGENT="${1:-}"
      if [[ -z "$AGENT" ]]; then
        printf 'ERROR: --agent requires a value\n' >&2
        exit 1
      fi
      ;;
    --title)
      shift
      TITLE="${1:-}"
      if [[ -z "$TITLE" ]]; then
        printf 'ERROR: --title requires a value\n' >&2
        exit 1
      fi
      ;;
    --window-name)
      shift
      WINDOW_NAME="${1:-}"
      if [[ -z "$WINDOW_NAME" ]]; then
        printf 'ERROR: --window-name requires a value\n' >&2
        exit 1
      fi
      ;;
    --session-name)
      shift
      TMUX_SESSION_NAME="${1:-}"
      if [[ -z "$TMUX_SESSION_NAME" ]]; then
        printf 'ERROR: --session-name requires a value\n' >&2
        exit 1
      fi
      ;;
    --project-dir)
      shift
      PROJECT_DIR="${1:-}"
      if [[ -z "$PROJECT_DIR" ]]; then
        printf 'ERROR: --project-dir requires a value\n' >&2
        exit 1
      fi
      ;;
    *)
      printf 'ERROR: Unknown argument: %s\n\n' "$1" >&2
      usage >&2
      exit 1
      ;;
  esac
  shift
done

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    printf 'ERROR: Required command not found: %s\n' "$1" >&2
    exit 1
  fi
}

require_cmd git
require_cmd tmux
require_cmd opencode
require_cmd python3

PROJECT_DIR="$(cd "$PROJECT_DIR" && pwd)"
REPO_ROOT="$(git -C "$PROJECT_DIR" rev-parse --show-toplevel 2>/dev/null || true)"
if [[ -n "$REPO_ROOT" ]]; then
  PROJECT_DIR="$REPO_ROOT"
fi

cd "$PROJECT_DIR"

if [[ -n "${TMUX:-}" ]]; then
  IN_TMUX=1
  CURRENT_TMUX_SESSION="$(tmux display-message -p '#{session_name}')"
  CURRENT_TMUX_WINDOW_ID="$(tmux display-message -p '#{window_id}')"
  CURRENT_TMUX_WINDOW_INDEX="$(tmux display-message -p '#{window_index}')"
  CURRENT_TMUX_WINDOW_NAME="$(tmux display-message -p '#{window_name}')"
  CURRENT_TMUX_PANE_ID="$(tmux display-message -p '#{pane_id}')"
fi

slug="$(basename "$PROJECT_DIR")"
timestamp="$(date '+%Y-%m-%d %H:%M')"
if [[ -z "$TITLE" ]]; then
  TITLE="$slug handoff $timestamp"
fi
if [[ -z "$WINDOW_NAME" ]]; then
  WINDOW_NAME="oc-$slug"
fi
if [[ -z "$TMUX_SESSION_NAME" ]]; then
  TMUX_SESSION_NAME="oc-$slug-$(date '+%H%M%S')"
fi

tmux_target_format="$(printf '#{session_name}\t#{window_index}\t#{window_name}\t#{window_id}\t#{pane_id}')"

relpath() {
  python3 - "$PROJECT_DIR" "$1" <<'PY'
import os
import sys
root = os.path.abspath(sys.argv[1])
path = os.path.abspath(sys.argv[2])
print(os.path.relpath(path, root))
PY
}

indent_block() {
  sed 's/^/    /'
}

emit_file_excerpt() {
  local file_path="$1"
  local max_lines="$2"
  if [[ -f "$file_path" ]]; then
    printf 'File: %s\n' "$(relpath "$file_path")"
    sed -n "1,${max_lines}p" "$file_path"
  else
    printf 'File: %s\n(missing)\n' "$file_path"
  fi
}

emit_markdown_section() {
  local file_path="$1"
  local heading="$2"
  local fallback_lines="$3"
  if [[ ! -f "$file_path" ]]; then
    printf '(missing: %s)\n' "$file_path"
    return
  fi

  local section
  section="$({ awk -v heading="$heading" '
    $0 == heading { flag=1 }
    flag {
      if ($0 ~ /^## / && $0 != heading && seen) {
        exit
      }
      print
      seen=1
    }
  ' "$file_path"; } || true)"

  if [[ -n "$section" ]]; then
    printf '%s\n' "$section"
  else
    sed -n "1,${fallback_lines}p" "$file_path"
  fi
}

list_markdown_files() {
  local dir_path="$1"
  local limit="$2"
  local label="$3"
  local files=()
  shopt -s nullglob
  files=("$dir_path"/*.md)
  shopt -u nullglob

  if (( ${#files[@]} == 0 )); then
    printf '%s: none\n' "$label"
    return
  fi

  printf '%s:\n' "$label"
  local count=0
  local file
  for file in "${files[@]}"; do
    printf -- '- %s\n' "$(relpath "$file")"
    count=$((count + 1))
    if (( count >= limit )); then
      break
    fi
  done
}

collect_threads() {
  local thread_dirs=("vault/ai/threads" "vault/threads")
  local found=0
  local dir_path
  for dir_path in "${thread_dirs[@]}"; do
    local files=()
    shopt -s nullglob
    files=("$dir_path"/*.md)
    shopt -u nullglob
    if (( ${#files[@]} == 0 )); then
      continue
    fi
    found=1
    local thread_file
    for thread_file in "${files[@]}"; do
      local title status next_action
      title="$(grep -m1 '^title:' "$thread_file" | sed 's/^title:[[:space:]]*//' || true)"
      if [[ -z "$title" ]]; then
        title="$(grep -m1 '^# ' "$thread_file" | sed 's/^# //' || true)"
      fi
      if [[ -z "$title" ]]; then
        title="$(basename "$thread_file")"
      fi
      status="$(grep -m1 '^status:' "$thread_file" | sed 's/^status:[[:space:]]*//' || true)"
      if [[ -z "$status" ]]; then
        status="unknown"
      fi
      next_action="$(grep -m1 '^next_action:' "$thread_file" | sed 's/^next_action:[[:space:]]*//' || true)"
      printf -- '- %s (%s) [%s]' "$title" "$status" "$(relpath "$thread_file")"
      if [[ -n "$next_action" ]]; then
        printf ': %s' "$next_action"
      fi
      printf '\n'
    done
  done

  if (( found == 0 )); then
    printf -- '- none\n'
  fi
}

parse_tmux_target() {
  local payload="$1"
  IFS=$'\t' read -r LAUNCH_SESSION_NAME LAUNCH_WINDOW_INDEX LAUNCH_WINDOW_NAME LAUNCH_WINDOW_ID LAUNCH_PANE_ID <<< "$payload"
}

verify_tmux_target_exists() {
  local pane_id="$1"
  tmux display-message -p -t "$pane_id" '#{session_name}:#{window_index}.#{pane_index}' >/dev/null 2>&1
}

verify_live_launch() {
  local pane_id="$1"
  local expected_text="$2"
  local fallback_text="$3"
  local attempts="${4:-10}"
  local delay_seconds="${5:-1}"
  local attempt=1

  VERIFY_PANE_EXISTS=0
  VERIFY_PANE_DEAD="unknown"
  VERIFY_PANE_COMMAND=""
  VERIFY_PANE_TITLE=""
  VERIFY_CAPTURE_RAW=""
  VERIFY_MATCHED_TEXT=0
  VERIFY_MATCHED_MARKER=""

  while (( attempt <= attempts )); do
    sleep "$delay_seconds"

    if ! verify_tmux_target_exists "$pane_id"; then
      VERIFY_PANE_EXISTS=0
      attempt=$((attempt + 1))
      continue
    fi

    VERIFY_PANE_EXISTS=1
    VERIFY_PANE_DEAD="$(tmux display-message -p -t "$pane_id" '#{pane_dead}' 2>/dev/null || printf 'unknown')"
    VERIFY_PANE_COMMAND="$(tmux display-message -p -t "$pane_id" '#{pane_current_command}' 2>/dev/null || true)"
    VERIFY_PANE_TITLE="$(tmux display-message -p -t "$pane_id" '#{pane_title}' 2>/dev/null || true)"
    VERIFY_CAPTURE_RAW="$(tmux capture-pane -epS -80 -t "$pane_id" 2>/dev/null || true)"

    if printf '%s' "$VERIFY_CAPTURE_RAW" | grep -Fq "$expected_text"; then
      VERIFY_MATCHED_TEXT=1
      VERIFY_MATCHED_MARKER="$expected_text"
    elif [[ -n "$fallback_text" ]] && printf '%s' "$VERIFY_CAPTURE_RAW" | grep -Fq "$fallback_text"; then
      VERIFY_MATCHED_TEXT=1
      VERIFY_MATCHED_MARKER="$fallback_text"
    elif printf '%s' "$VERIFY_CAPTURE_RAW" | grep -Fq 'New session'; then
      VERIFY_MATCHED_TEXT=1
      VERIFY_MATCHED_MARKER='New session'
    fi

    if [[ "$VERIFY_PANE_DEAD" == "0" ]] && \
      [[ "$VERIFY_PANE_COMMAND" == "opencode" || "$VERIFY_PANE_COMMAND" == "bash" || "$VERIFY_PANE_COMMAND" == "sh" || "$VERIFY_PANE_COMMAND" == "zsh" ]] && \
      [[ "$VERIFY_MATCHED_TEXT" == "1" ]]; then
      return 0
    fi

    attempt=$((attempt + 1))
  done

  return 1
}

print_tmux_context() {
  printf '%s:%s (%s) pane %s' "$CURRENT_TMUX_SESSION" "$CURRENT_TMUX_WINDOW_INDEX" "$CURRENT_TMUX_WINDOW_NAME" "$CURRENT_TMUX_PANE_ID"
}

branch_name="$(git branch --show-current 2>/dev/null || true)"
if [[ -z "$branch_name" ]]; then
  branch_name="detached-head"
fi

status_output="$(git status --short --branch 2>/dev/null || true)"
if [[ -z "$status_output" ]]; then
  status_output="(clean working tree)"
fi

recent_commits="$(git log --oneline -5 2>/dev/null || true)"
if [[ -z "$recent_commits" ]]; then
  recent_commits="(no commits found)"
fi

agents_excerpt="$(emit_file_excerpt "$PROJECT_DIR/AGENTS.md" 140)"
plan_state="$(emit_markdown_section "$PROJECT_DIR/vault/sprint/PLAN.md" '## Current Execution State' 120)"
plan_notes="$(emit_markdown_section "$PROJECT_DIR/vault/sprint/PLAN.md" '## Planning Notes For Main Orchestrator' 120)"

ongoing_tasks="$(list_markdown_files "$PROJECT_DIR/vault/sprint/ongoing" 6 'Ongoing tasks')"
backlog_tasks="$(list_markdown_files "$PROJECT_DIR/vault/sprint/backlog" 8 'Backlog candidates')"
done_tasks="$(list_markdown_files "$PROJECT_DIR/vault/sprint/done" 6 'Recently completed task files')"
thread_summary="$(collect_threads)"

PROMPT_FILE="$(mktemp "${TMPDIR:-/tmp}/opencode-handoff-prompt.XXXXXX")"
LAUNCHER_FILE="$(mktemp "${TMPDIR:-/tmp}/opencode-handoff-launch.XXXXXX")"

cat > "$PROMPT_FILE" <<EOF
# $TITLE

You are taking over an existing OpenCode project session because the prior session became too long. Start with orientation, not assumptions.

Repository
- Project: $slug
- Root: $PROJECT_DIR
- Generated: $(date '+%Y-%m-%d %H:%M:%S %Z')
- Launch intent: fresh handoff session for continued SDLC work

Current git snapshot
- Branch: $branch_name

Git status
$(printf '%s\n' "$status_output" | indent_block)

Recent commits
$(printf '%s\n' "$recent_commits" | indent_block)

AGENTS.md orientation
$(printf '%s\n' "$agents_excerpt" | indent_block)

Sprint plan - current execution state
$(printf '%s\n' "$plan_state" | indent_block)

Sprint plan - planning notes
$(printf '%s\n' "$plan_notes" | indent_block)

Sprint file inventory
$(printf '%s\n%s\n%s\n' "$ongoing_tasks" "$backlog_tasks" "$done_tasks" | indent_block)

Active concern threads
$(printf '%s\n' "$thread_summary" | indent_block)

Startup protocol
1. Read AGENTS.md first and honor its workflow configuration and commit discipline.
2. Read vault/sprint/PLAN.md next, then inspect the task files that match the current execution lane.
3. Inspect git status --short --branch, git diff --stat, and the most recent relevant task or code files before editing anything.
4. Re-state the current SDLC position in concrete terms, citing the repo artifacts you used.
5. Continue the highest-priority unfinished work unless a newer user instruction overrides it.
6. If the current next step is ambiguous, say what evidence conflicts and propose the safest default.

Response contract for your first reply
- Name the likely current task or verification lane.
- Cite the files that support that conclusion.
- Call out any dirty-worktree risk before making changes.
- State the first 2-4 actions you will take in this new session.
EOF

cat > "$LAUNCHER_FILE" <<EOF
#!/usr/bin/env bash
set -euo pipefail
prompt_file="$PROMPT_FILE"
launcher_file="$LAUNCHER_FILE"
cleanup() {
  rm -f "\$prompt_file" "\$launcher_file"
}
trap cleanup EXIT
exec opencode "$PROJECT_DIR" --agent "$AGENT" --prompt "\$(cat "\$prompt_file")"
EOF

chmod +x "$LAUNCHER_FILE"

launch_mode="$TARGET"
launch_note=""
if (( IN_TMUX == 0 )) && [[ "$TARGET" == "pane" ]]; then
  launch_mode="window"
  launch_note="Requested --pane outside tmux; falling back to a detached tmux session."
fi

if (( PRINT_ONLY == 1 )); then
  printf 'Prompt synthesized for %s\n' "$PROJECT_DIR"
  printf 'Agent: %s\n' "$AGENT"
  printf 'Handoff title: %s\n' "$TITLE"
  if [[ -n "$launch_note" ]]; then
    printf 'Note: %s\n' "$launch_note"
  fi
  if (( IN_TMUX == 1 )); then
    if [[ "$launch_mode" == "pane" ]]; then
      printf 'Launch target: tmux pane in current window %s\n' "$(print_tmux_context)"
    else
      printf 'Launch target: tmux window in current session %s:%s (%s)\n' "$CURRENT_TMUX_SESSION" "$CURRENT_TMUX_WINDOW_INDEX" "$CURRENT_TMUX_WINDOW_NAME"
    fi
  else
    printf 'Launch target: detached tmux session %s (window %s)\n' "$TMUX_SESSION_NAME" "$WINDOW_NAME"
  fi
  printf '\n--- BEGIN HANDOFF PROMPT ---\n'
  cat "$PROMPT_FILE"
  printf '\n--- END HANDOFF PROMPT ---\n'
  rm -f "$PROMPT_FILE" "$LAUNCHER_FILE"
  exit 0
fi

if (( IN_TMUX == 1 )); then
  if [[ "$launch_mode" == "pane" ]]; then
    launch_result="$(tmux split-window -P -F "$tmux_target_format" -t "$CURRENT_TMUX_PANE_ID" -c "$PROJECT_DIR" "$LAUNCHER_FILE")"
    parse_tmux_target "$launch_result"
    LAUNCH_TARGET_LABEL="tmux pane"
    LAUNCH_TARGET_ID="$LAUNCH_SESSION_NAME:$LAUNCH_WINDOW_INDEX ($LAUNCH_WINDOW_NAME) pane $LAUNCH_PANE_ID"
  else
    launch_result="$(tmux new-window -P -F "$tmux_target_format" -t "$CURRENT_TMUX_SESSION:" -c "$PROJECT_DIR" -n "$WINDOW_NAME" "$LAUNCHER_FILE")"
    parse_tmux_target "$launch_result"
    LAUNCH_TARGET_LABEL="tmux window"
    LAUNCH_TARGET_ID="$LAUNCH_SESSION_NAME:$LAUNCH_WINDOW_INDEX ($LAUNCH_WINDOW_NAME) pane $LAUNCH_PANE_ID"
  fi
else
  launch_result="$(tmux new-session -d -P -F "$tmux_target_format" -s "$TMUX_SESSION_NAME" -n "$WINDOW_NAME" -c "$PROJECT_DIR" "$LAUNCHER_FILE")"
  parse_tmux_target "$launch_result"
  LAUNCH_TARGET_LABEL="detached tmux session"
  LAUNCH_TARGET_ID="$LAUNCH_SESSION_NAME:$LAUNCH_WINDOW_INDEX ($LAUNCH_WINDOW_NAME) pane $LAUNCH_PANE_ID"
fi

if ! verify_live_launch "$LAUNCH_PANE_ID" "$TITLE" "${AGENT^}" 12 1; then
  printf 'Launch failed: %s -> %s\n' "$LAUNCH_TARGET_LABEL" "$LAUNCH_TARGET_ID" >&2
  printf 'Expected persistent OpenCode TUI with handoff marker: %s\n' "$TITLE" >&2
  printf 'Verification details: exists=%s dead=%s command=%s pane_title=%s matched_text=%s matched_marker=%s\n' \
    "$VERIFY_PANE_EXISTS" "$VERIFY_PANE_DEAD" "${VERIFY_PANE_COMMAND:-unknown}" "${VERIFY_PANE_TITLE:-unknown}" "$VERIFY_MATCHED_TEXT" "${VERIFY_MATCHED_MARKER:-none}" >&2
  if [[ -n "$VERIFY_CAPTURE_RAW" ]]; then
    printf '%s\n' 'Captured pane excerpt:' >&2
    printf '%s\n' "$VERIFY_CAPTURE_RAW" | sed -n '1,20p' >&2
  elif verify_tmux_target_exists "$LAUNCH_PANE_ID"; then
    printf '%s\n' 'Captured pane excerpt: (empty)' >&2
  else
    printf '%s\n' 'Captured pane excerpt: pane no longer exists' >&2
  fi
  exit 1
fi

if (( IN_TMUX == 0 )); then
  printf 'Started detached tmux session %s with window %s.\n' "$TMUX_SESSION_NAME" "$WINDOW_NAME"
  printf 'Attach with: tmux attach -t %s\n' "$TMUX_SESSION_NAME"
fi

if [[ -n "$launch_note" ]]; then
  printf 'Note: %s\n' "$launch_note"
fi

printf 'Launch verified: %s -> %s\n' "$LAUNCH_TARGET_LABEL" "$LAUNCH_TARGET_ID"
printf 'Handoff title: %s\n' "$TITLE"
printf 'Agent: %s\n' "$AGENT"
printf 'Verification: pane exists=%s dead=%s current_command=%s pane_title=%s matched_marker=%s\n' \
  "$VERIFY_PANE_EXISTS" "$VERIFY_PANE_DEAD" "$VERIFY_PANE_COMMAND" "$VERIFY_PANE_TITLE" "$VERIFY_MATCHED_MARKER"
