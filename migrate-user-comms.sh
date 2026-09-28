#!/usr/bin/env bash
# migrate-user-comms.sh — bring an EXISTING enclosing folder onto the user-keyed
# comms layout. Run once per folder, from inside the enclosing folder (or with the
# folder as $1).
#
# What it does, in order (idempotent — a second run is a no-op):
#   1. Detects the current layout:
#        - flat pre-fork: comms/<YYYYMMDD>-<NN>/ session folders directly in comms/
#        - user-keyed:    comms/<user>/<YYYYMMDD>-<NN>/   (nothing to migrate)
#   2. Moves flat session folders into comms/<calling-user>/ (git-less mv; comms/
#      is not tracked anywhere — attribution becomes structural, history preserved).
#   3. Installs the CURRENT scripts (session-start.sh, session-end.sh) + templates
#      from the runbook copy this script ships with — so an old folder's stale
#      single-user scripts are replaced, not trusted.
#   4. Refuses to guess: an unsealed draft keeps its SEAL marker (it stays a draft
#      after the move); handoff paths inside ledgers are NOT rewritten — the ledger
#      keys on absolute path, so old entries keep pointing at their handoff. New
#      appends (reopen + re-seal) key on the NEW path. That is correct: the old
#      digest records what was known then; the moved file is the same content at a
#      new address.
#
# NOT done here (deliberate):
#   - No ledger migration (per-user ledgers; old entries stay where they were).
#   - No herdr/omp config changes.
#   - No migration of prior-art/ artifacts/ work/ — layout-agnostic already.
#
# Usage: ./migrate-user-comms.sh [<enclosing-folder>]   (default: cwd)
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET="${1:-$(pwd)}"
TARGET="$(cd "$TARGET" && pwd)"
COMMS="$TARGET/comms"
USER_NAME="${USER:-$(id -un)}"
die() { echo "migrate-user-comms: $*" >&2; exit 1; }

case "$USER_NAME" in
  ""|*[!a-zA-Z0-9_.-]*) die "unusable user name '$USER_NAME'" ;;
esac

[[ -d "$COMMS" ]] || die "$COMMS not found — run inside an enclosing folder (or pass its path)"

# --- 1. detect layout -----------------------------------------------------------
PAT='[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]-[0-9][0-9]'
flat=()
while IFS= read -r d; do flat+=("$d"); done \
  < <({ find "$COMMS" -mindepth 1 -maxdepth 1 -type d -name "$PAT" 2>/dev/null || true; } | sort)
USER_COMMS="$COMMS/$USER_NAME"
if (( ${#flat[@]} == 0 )) && [[ -d "$USER_COMMS" ]]; then
  echo "comms/ is already user-keyed under comms/$USER_NAME/ — checking scripts only."
  flat=()   # nothing to move
fi

# --- 2. move flat sessions under the calling user -------------------------------
moved=0
for d in ${flat[@]+"${flat[@]}"}; do
  [[ -d "$USER_COMMS/$(basename "$d")" ]] && die "target comms/$USER_NAME/$(basename "$d") already exists — resolve by hand"
done
if (( ${#flat[@]} )); then
  mkdir -p "$USER_COMMS"
  for d in ${flat[@]+"${flat[@]}"}; do
    mv "$d" "$USER_COMMS/$(basename "$d")"
    moved=$((moved+1))
  done
  echo "moved $moved session folder(s) into comms/$USER_NAME/"
fi

# --- 3. install current scripts + templates from the scaffold (mirror source) ---
# The scaffold's heredocs ARE the stamped copies (byte-verified against live at
# build time), so an old folder gets the current scripts from the same source the
# scaffold uses — no separate live copy to drift.
SCAFFOLD="$HERE/scaffold/new-enclosing-folder.sh"
[[ -f "$SCAFFOLD" ]] || die "scaffold not found next to this script (expected $SCAFFOLD)"
TMPDIR_M="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_M"' EXIT
START_MARKER="$(awk '/cat > "\$TARGET\/comms\/session-start.sh"/ {print NR; exit}' "$SCAFFOLD")"
END_MARKER="$(awk '/cat > "\$TARGET\/comms\/session-end.sh"/ {print NR; exit}' "$SCAFFOLD")"
[[ -n "$START_MARKER" && -n "$END_MARKER" ]] || die "scaffold heredoc markers not found — scaffold format drift"
# extraction: from marker line +1 to the FIRST lone SCRIPT_EOF line after it
extract() { # <start-line>
  awk -v n="$1" 'NR>n { print }' "$SCAFFOLD" \
    | awk 'BEGIN{done=0} !done && /^SCRIPT_EOF$/ {done=1; exit} !done { print }'
}
extract "$START_MARKER" > "$TMPDIR_M/session-start.sh"
extract "$END_MARKER" > "$TMPDIR_M/session-end.sh"
for f in session-start.sh session-end.sh; do
  [[ -s "$TMPDIR_M/$f" ]] || die "extracted $f is empty — scaffold format drift"
done
bash -n "$TMPDIR_M/session-start.sh" && bash -n "$TMPDIR_M/session-end.sh" \
  || die "extracted scripts fail syntax check — scaffold drift; refusing to install"
TEMPLATES_DIR="$COMMS/templates"
if [[ ! -f "$TEMPLATES_DIR/session-handoff.md" ]]; then
  extract_tpl() { # <marker-line-number> <out>
    awk -v n="$1" 'NR>n { print }' "$SCAFFOLD" \
      | awk 'BEGIN{done=0} !done && /^TEMPLATE_EOF$/ {done=1; exit} !done { print }'
  }
  T1="$(awk '/cat > "\$TARGET\/comms\/templates\/session-handoff.md"/ {print NR; exit}' "$SCAFFOLD")"
  T2="$(awk '/cat > "\$TARGET\/comms\/templates\/conversation.md"/ {print NR; exit}' "$SCAFFOLD")"
  mkdir -p "$TEMPLATES_DIR"
  extract_tpl "$T1" > "$TEMPLATES_DIR/session-handoff.md"
  extract_tpl "$T2" > "$TEMPLATES_DIR/conversation.md"
  echo "templates/ missing — stamped fresh from scaffold"
fi
for f in session-start.sh session-end.sh; do
  if cmp -s "$COMMS/$f" "$TMPDIR_M/$f"; then
    echo "comms/$f already current"
  else
    cp "$TMPDIR_M/$f" "$COMMS/$f.new" && chmod +x "$COMMS/$f.new" && mv "$COMMS/$f.new" "$COMMS/$f"
    echo "comms/$f replaced with current (user-keyed) version"
  fi
done

# --- 4. report -------------------------------------------------------------------
if [[ -d "$USER_COMMS" ]]; then
  n="$(find "$USER_COMMS" -mindepth 1 -maxdepth 1 -type d -name "$PAT" | wc -l)"
  echo "comms/$USER_NAME/ now holds $n session folder(s)."
fi
echo "done. Next: ./comms/session-start.sh (keys sessions to your OS user automatically)."