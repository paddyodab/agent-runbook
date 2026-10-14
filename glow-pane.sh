#!/usr/bin/env bash
# glow-pane.sh — open a markdown file in a herdr pane rendered by `glow`.
#
# Usage: ./comms/glow-pane.sh <file.md> [label]
#
# Behavior:
#   - Inside herdr (HERDR_ENV=1): splits the calling pane right, runs
#     `glow -p <file>` there (glow's pager: scrollable, q quits, returns
#     the pane's shell to a prompt when done), names the pane, and prints
#     the pane id. Re-invoking on the same file re-renders in the SAME
#     "glow" pane rather than stacking splits — the pane is closed and
#     re-created in place.
#   - Outside herdr: prints the file rendered to stdout with glow -w0
#     (no pager), so the agent can read it back or the operator can pipe it.
#
# Fail-soft: if herdr/glow is missing or the socket refuses, fall back to
# plain stdout rendering. Never leaves a spinner: `-p` puts glow in its
# own pager process; when it exits the pane shows the shell prompt.
set -uo pipefail

FILE="${1:-}"
[[ -n "$FILE" ]] || { echo "usage: glow-pane.sh <file.md> [label]" >&2; exit 2; }
[[ -f "$FILE" ]] || { echo "glow-pane.sh: no such file: $FILE" >&2; exit 1; }
FILE="$(cd "$(dirname "$FILE")" && pwd)/$(basename "$FILE")"
LABEL="${2:-$(basename "$FILE" .md)}"

command -v glow >/dev/null 2>&1 || { glow -w0 "$FILE"; exit 0; }

if [[ "${HERDR_ENV:-}" = 1 && -n "${HERDR_PANE_ID:-}" ]] && command -v herdr >/dev/null 2>&1; then
  WS="${HERDR_WORKSPACE_ID:-}"
  OLD_ID=""
  if [[ -n "$WS" ]]; then
    OLD_ID=$(herdr pane list --workspace "$WS" 2>/dev/null \
      | jq -r --arg lbl "glow: $LABEL" \
        '.result.panes[] | select(.label? == $lbl) | .pane_id' 2>/dev/null | head -n1)
  fi
  # idempotent re-render: replace the previous glow pane for this document
  [[ -n "$OLD_ID" ]] && herdr pane close "$OLD_ID" >/dev/null 2>&1

  OUT=$(herdr pane split --pane "$HERDR_PANE_ID" --direction right --ratio 0.5 \
        --cwd "$(dirname "$FILE")" 2>/dev/null) || { glow -w0 "$FILE"; exit 0; }
  NEW_ID=$(printf '%s' "$OUT" | jq -r '.result.pane.pane_id // empty' 2>/dev/null)
  if [[ -z "$NEW_ID" ]]; then glow -w0 "$FILE"; exit 0; fi

  herdr pane rename "$NEW_ID" "glow: $LABEL" >/dev/null 2>&1
  herdr pane wait-output "$NEW_ID" --match . --lines 1 --timeout 2000 >/dev/null 2>&1
  herdr pane run "$NEW_ID" "glow -p '$FILE'" >/dev/null 2>&1
  echo "$NEW_ID"
  exit 0
fi

glow -w0 "$FILE"
