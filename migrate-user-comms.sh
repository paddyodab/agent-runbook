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
#   3b. comms-as-git: init's comms/ as a git repo (initial commit of the protocol
#      files) when .git is absent, and stamps/renews the credential pre-push hook
#      whenever it is missing or stale (clones never inherit hooks). Idempotent.
#   4. Refuses to guess: an unsealed draft keeps its SEAL marker (it stays a draft
#      after the move); handoff paths inside ledgers are NOT rewritten — the ledger
#      keys on absolute path, so old entries keep pointing at their handoff. New
#      appends (reopen + re-seal) key on the NEW path. That is correct: the old
#      digest records what was known then; the moved file is the same content at a
#      new address.
#
# NOT done here (deliberate):
#   - No remote wiring (no URL guessing) — deliberate operator step.
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
# Resolution order: (a) repo-tree layout — scaffold/ next to this script; (b) the
# comms tree's own tracked protocol files (the scaffold's initial commit carries
# byte-identical copies — clone-time migration or installed copies WITHOUT a
# scaffold next door fall here); (c) the tracked hooks/pre-push stays the hook
# fallback in §3b. The laptop case (installed copy, no scaffold/ sibling) is (b).
resolve_scaffold_source() {
  if [[ -f "$HERE/scaffold/new-enclosing-folder.sh" ]]; then
    SCAFFOLD="$HERE/scaffold/new-enclosing-folder.sh"
    SCAFFOLD_MODE="scaffold"
  elif [[ -f "$COMMS/session-start.sh" ]]; then
    SCAFFOLD="$COMMS"
    SCAFFOLD_MODE="comms-tree"
  else
    die "no scaffold source: neither $HERE/scaffold/ (repo layout) nor the comms tree itself ($COMMS) — cannot refresh scripts"
  fi
}
SCAFFOLD=""
SCAFFOLD_MODE=""
resolve_scaffold_source

TMPDIR_M="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_M"' EXIT
if [[ "$SCAFFOLD_MODE" == "scaffold" ]]; then
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
else
  # comms-tree mode: the folder's OWN session scripts are the current-est source
  # available (they were stamped by THIS unit's scaffold). Refresh = cmp-only (the
  # migrator's job here is layout + hook, not script overwrite; there is nothing
  # newer locally to install). AGENTS refresh uses the enclosing folder's own file.
  for f in session-start.sh session-end.sh; do
    [[ -f "$COMMS/$f" ]] || die "$COMMS/$f missing — comms tree incomplete; refusing"
  done
  cp "$COMMS/session-start.sh" "$COMMS/session-end.sh" "$TMPDIR_M/"
  bash -n "$TMPDIR_M/session-start.sh" && bash -n "$TMPDIR_M/session-end.sh" \
    || die "comms-tree scripts fail syntax check — refusing"
fi
# AGENTS.md refresh: the standing rules (incl. the two-workers/one-repo worktree rule)
# live in the scaffold heredoc; an old folder's AGENTS.md drifts as the runbook evolves.
# Refresh the body (everything after the slug heading), keeping the folder's own heading.
# comms-tree mode: no scaffold → no newer AGENTS source locally; leave AGENTS.md alone
# (the enclosing folder's own file is the source of truth on that node).
AGENTS_F="$TARGET/AGENTS.md"
if [[ "$SCAFFOLD_MODE" == "scaffold" ]]; then
  AG_START="$(awk '/cat > "\$STAGE\/AGENTS.md"/ {print NR; exit}' "$SCAFFOLD")"
  [[ -n "$AG_START" ]] || die "scaffold AGENTS heredoc marker not found"
  awk -v n="$AG_START" 'NR>n { print }' "$SCAFFOLD" \
    | awk 'BEGIN{done=0} !done && /^AGENTS_EOF$/ {done=1; exit} !done { print }' > "$TMPDIR_M/AGENTS.md"
  if [[ ! -s "$TMPDIR_M/AGENTS.md" ]]; then
    die "extracted AGENTS.md is empty — scaffold drift"
  fi
fi
if [[ "$SCAFFOLD_MODE" == "scaffold" ]]; then
  if [[ ! -f "$AGENTS_F" ]]; then
    cp "$TMPDIR_M/AGENTS.md" "$AGENTS_F"
    echo "AGENTS.md stamped (was missing)"
  else
    # compare bodies: line 1 is the slug heading (may legitimately differ)
    if ! diff <(tail -n +2 "$AGENTS_F") <(tail -n +2 "$TMPDIR_M/AGENTS.md") >/dev/null; then
      HEAD_LINE="$(head -1 "$AGENTS_F")"
      { printf '%s\n' "$HEAD_LINE"; tail -n +2 "$TMPDIR_M/AGENTS.md"; } > "$AGENTS_F.new"
      mv "$AGENTS_F.new" "$AGENTS_F"
      echo "AGENTS.md body refreshed to current standing rules"
    else
      echo "AGENTS.md already current"
    fi
  fi
fi

TEMPLATES_DIR="$COMMS/templates"
if [[ ! -f "$TEMPLATES_DIR/session-handoff.md" ]]; then
  if [[ "$SCAFFOLD_MODE" == "scaffold" ]]; then
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
  else
    die "$TEMPLATES_DIR missing and no scaffold source to stamp it from — clone a full comms (unit-1 scaffold commits templates/) or run from the repo tree"
  fi
fi
for f in session-start.sh session-end.sh; do
  if cmp -s "$COMMS/$f" "$TMPDIR_M/$f"; then
    echo "comms/$f already current"
  elif [[ "$SCAFFOLD_MODE" == "scaffold" ]]; then
    cp "$TMPDIR_M/$f" "$COMMS/$f.new" && chmod +x "$COMMS/$f.new" && mv "$COMMS/$f.new" "$COMMS/$f"
    echo "comms/$f replaced with current (user-keyed) version"
  else
    : # comms-tree mode: the tree's own copies ARE the source; nothing newer to install
  fi
done

# --- 3b. comms-as-git: init the repo + stamp the credential pre-push hook -------
# Idempotent: init only when .git is absent (a pre-fork folder has none); stamp
# the hook whenever it is missing or stale (clones don't inherit hooks — the
# same self-heal comms-sync export owns later; wired here for every node that
# might push). Hook source resolution (one resolver): scaffold heredoc when in
# repo-tree layout, else the comms tree's tracked copy at comms/hooks/pre-push.
HOOK_ACTIVE_EXISTS=0
if [[ "$SCAFFOLD_MODE" == "scaffold" ]]; then
  HOOK_SRC_LINE="$(awk '/cat > "\$STAGE\/comms-hook-pre-push"/ {print NR; exit}' "$SCAFFOLD")"
  [[ -n "$HOOK_SRC_LINE" ]] || die "scaffold hook heredoc marker not found"
  extract_hook() {
    awk -v n="$HOOK_SRC_LINE" 'NR>n { print }' "$SCAFFOLD" \
      | awk 'BEGIN{done=0} !done && /^HOOK_EOF$/ {done=1; exit} !done { print }'
  }
  extract_hook > "$TMPDIR_M/pre-push"
  [[ -s "$TMPDIR_M/pre-push" ]] || die "extracted pre-push hook is empty — scaffold drift"
  bash -n "$TMPDIR_M/pre-push" || die "extracted hook fails syntax check — scaffold drift"
else
  [[ -f "$COMMS/hooks/pre-push" ]] || die "no scaffold source and no tracked $COMMS/hooks/pre-push — cannot stamp the hook"
  cp "$COMMS/hooks/pre-push" "$TMPDIR_M/pre-push"
  bash -n "$TMPDIR_M/pre-push" || die "tracked hook fails syntax check — refusing"
fi
if [[ ! -d "$COMMS/.git" ]]; then
  command -v git >/dev/null 2>&1 || die "git not found — comms/ must be a git repo for history transport; install git and re-run"
  mkdir -p "$COMMS/hooks"
  cp "$TMPDIR_M/pre-push" "$COMMS/hooks/pre-push" && chmod +x "$COMMS/hooks/pre-push"
  git -C "$COMMS" init -q
  GIT_ID_NAME="$(git config user.name 2>/dev/null || echo "${USER_NAME:-$(id -un 2>/dev/null || echo comms)}")"
  GIT_ID_EMAIL="$(git config user.email 2>/dev/null || echo "${USER_NAME:-comms}@$(hostname 2>/dev/null || echo local)")"
  git -C "$COMMS" add -A
  git -C "$COMMS" -c user.name="$GIT_ID_NAME" -c user.email="$GIT_ID_EMAIL" commit -q \
    -m "comms protocol + credential pre-push hook (stamped by migrate-user-comms.sh)"
  echo "comms/ initialized as a git repo (initial commit made)"
else
  echo "comms/ already a git repo"
fi
if [[ ! -x "$COMMS/.git/hooks/pre-push" ]] || ! cmp -s "$COMMS/.git/hooks/pre-push" "$TMPDIR_M/pre-push"; then
  cp "$TMPDIR_M/pre-push" "$COMMS/.git/hooks/pre-push" && chmod +x "$COMMS/.git/hooks/pre-push"
  if [[ -d "$COMMS/.git" ]]; then
    mkdir -p "$COMMS/hooks"
    cp "$TMPDIR_M/pre-push" "$COMMS/hooks/pre-push" && chmod +x "$COMMS/hooks/pre-push"
  fi
  echo "credential pre-push hook stamped (was missing or stale)"
else
  echo "credential pre-push hook already current"
fi
git -C "$COMMS" status --porcelain >/dev/null 2>&1 || die "comms/ git repo invalid after migrate"

# --- 4. report -------------------------------------------------------------------
if [[ -d "$USER_COMMS" ]]; then
  n="$(find "$USER_COMMS" -mindepth 1 -maxdepth 1 -type d -name "$PAT" | wc -l)"
  echo "comms/$USER_NAME/ now holds $n session folder(s)."
fi
echo "done. Next: ./comms/session-start.sh (keys sessions to your OS user automatically)."