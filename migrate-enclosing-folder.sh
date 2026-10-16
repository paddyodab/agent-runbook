#!/usr/bin/env bash
# migrate-enclosing-folder.sh — reconcile an EXISTING enclosing folder's stamped
# protocol artifacts with the CURRENT scaffold. Sibling to new-enclosing-folder.sh
# (which stamps only at creation) and migrate-user-comms.sh (which owns the comms
# tier: layout + session scripts + templates + hook). This tool is the REPORT +
# reconcile layer on top of that family; the comms-tier logic is delegated, never
# forked.
#
# What it checks/fixes (per class):
#   agents          — enclosing AGENTS.md standing rules vs scaffold AGENTS heredoc
#   readme          — enclosing README.md vs scaffold README heredoc (rendered with
#                     the live folder's identity: FOLDER from dirname, PURPOSE from
#                     live line 3, CONVENTION from the scaffold var)
#   comms-protocol  — comms/session-start.sh, session-end.sh, glow-pane.sh vs the
#                     scaffold heredocs (byte-parity, migrate-user-comms resolution)
#   comms-readme    — comms/README.md vs the scaffold PROTOCOL heredoc
#   templates       — comms/templates/{session-handoff.md,conversation.md,preamble.txt}
#   hook            — comms/hooks/pre-push + .git/hooks/pre-push vs the HOOK heredoc
#   .gitignore      — comms/.gitignore vs the scaffold GITIGNORE heredoc
#   dirs            — prior-art/, artifacts/, work/ exist (missing → stampable)
#
# Verdicts (one per artifact): current | drift (what) | missing | operator-modified
# (review). Report-first by default; NOTHING is mutated without --apply.
#
# Rollback trails:
#   versioned homes (under comms/)  — applied via a git -C comms commit naming the
#     scaffold source; comms history IS the rollback (no .bak in comms).
#   unversioned homes (root AGENTS.md, README.md) — sibling .bak-<timestamp> copy
#     before overwrite. Live slug heading (AGENTS) and live PURPOSE (README) are
#     preserved through the render.
#   Standing-section hand-edits CANNOT be derived from the render — verdict
#     operator-modified; apply refuses that section unless --force-section is given
#     for it. A .bak is still written.
#
# Refuse-to-guess (every refusal names its hatch):
#   - not an enclosing folder (no comms/session-start.sh) → rc 1
#   - unsealed draft under comms → --apply refuses (report still works); hatch:
#     seal first (./comms/session-end.sh) or --force-session-state
#   - scaffold heredoc markers missing → rc 1 (format-drift fence)
#   - comms-tree fallback (no scaffold, no installed sibling) → report only, apply
#     refused loud (nothing newer locally to install)
#   - unknown class / bad usage → rc 1 with usage
#   - git missing where comms commit is needed → rc 1 (hatch: install git)
#   - comms/ has uncommitted mutations → refuse comms-class apply (hatch: run
#     comms-sync export or commit deliberately first; mixed state is unrollbackable)
#
# NEVER: pushes, remote wiring, session-folder mutation, ledger changes, herdr/omp
# config. Migration of the comms LAYOUT (flat → user-keyed) stays in
# migrate-user-comms.sh; this tool will point you there if it detects flat layout.
#
# Usage:
#   migrate-enclosing-folder.sh [<enclosing-folder>]              (report)
#   migrate-enclosing-folder.sh <folder> --apply                  (all classes)
#   migrate-enclosing-folder.sh <folder> --apply --only readme,agents
#   migrate-enclosing-folder.sh <folder> --apply --only agents --force-section
#   migrate-enclosing-folder.sh <folder> --apply --force-session-state   (rare)
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
die() { echo "migrate-enclosing-folder: $*" >&2; exit 1; }

usage() {
  sed -n '2,45p' "$0" | sed 's/^# \{0,1\}//;s/^#//' | sed '/^Usage:/,$d'
  echo "Usage: migrate-enclosing-folder.sh [<folder>] [--apply] [--only class,class] [--force-section] [--force-session-state]" >&2
  exit 1
}

TARGET=""
APPLY=0
ONLY=""
FORCE_SECTION=0
FORCE_SESSION_STATE=0
while [ $# -gt 0 ]; do
  case "$1" in
    --apply) APPLY=1; shift ;;
    --only) [ $# -lt 2 ] && usage; ONLY="$2"; shift 2 ;;
    --force-section) FORCE_SECTION=1; shift ;;
    --force-session-state) FORCE_SESSION_STATE=1; shift ;;
    -h|--help) usage ;;
    -*) usage ;;
    *) [ -n "$TARGET" ] && usage; TARGET="$1"; shift ;;
  esac
done
TARGET="${TARGET:-$(pwd)}"
cd "$TARGET" 2>/dev/null || die "folder not found: '$TARGET'"
TARGET="$PWD"

ALL_CLASSES="agents readme comms-protocol comms-readme templates hook .gitignore dirs"
CLASS_OK=""
for c in ${ONLY:+$(echo "$ONLY" | tr ',' ' ')}; do
  case "$ALL_CLASSES" in
    *"$c"*) ;;
    *) die "unknown class '$c' (classes: $ALL_CLASSES)" ;;
  esac
  CLASS_OK=1
done
if [ -n "$ONLY" ] && [ "$APPLY" = 0 ]; then
  die "--only without --apply is meaningless — report always covers every class"
fi
want() { # want <class> — true if the class runs this invocation
  if [ -n "$ONLY" ]; then
    case ",$(echo "$ONLY" | tr ',' ',')," in
      *",$1,"*) return 0 ;;
      *) return 1 ;;
    esac
  fi
  return 0
}

COMMS="$TARGET/comms"
[[ -f "$COMMS/session-start.sh" ]] || die "$COMMS lacks session-start.sh — not an enclosing folder; run inside one (or pass its path). To CREATE one, run new-enclosing-folder.sh."

# Unsealed draft check (apply only): an unsealed handoff means the session protocol
# is mid-flight; protocol stamping mid-flight risks a stale-then-fixed state.
# Only real SESSION handoffs count — the glob must skip comms/templates/ (the
# template carries the SEAL comment boilerplate) and any depth-2 stray.
if [ "$APPLY" = 1 ] && [ "$FORCE_SESSION_STATE" = 0 ]; then
  for h in "$COMMS"/*/*/session-handoff.md "$COMMS"/*/session-handoff.md; do
    case "$h" in
      */templates/*|*"$COMMS/templates/"*) continue ;;
    esac
    [ -f "$h" ] || continue
    if grep -qF 'SEAL' "$h" 2>/dev/null; then
      die "unsealed draft at $h — seal first (./comms/session-end.sh <user>/<folder>) or re-run --apply with --force-session-state"
    fi
  done  # no redirect: grep -qF quiets itself; die() must stay loud
fi

# --- scaffold source resolution (migrate-user-comms ladder) ----------------------
if [ -f "$HERE/scaffold/new-enclosing-folder.sh" ]; then
  SCAFFOLD="$HERE/scaffold/new-enclosing-folder.sh"
elif [ -f "$HERE/new-enclosing-folder.sh" ]; then
  SCAFFOLD="$HERE/new-enclosing-folder.sh"
else
  SCAFFOLD=""
fi
if [ -z "$SCAFFOLD" ]; then
  echo "report-only mode: no scaffold source next to this script (repo tree or installed sibling) —"
  echo "  the comms tree's own protocol files are the newest source available here."
  echo "  To reconcile against the CURRENT runbook: install the runbook first (install.sh),"
  echo "  or run from a runbook repo clone."
  if [ "$APPLY" = 1 ]; then
    die "refusing --apply with no scaffold source — report-only is the safe mode here"
  fi
fi
SCAFFOLD_RC="$(git -C "$TARGET" rev-parse --is-inside-work-tree 2>/dev/null || true)"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# extract <marker-awk-pat> <terminator> <out>: heredoc body after marker line up to
# the FIRST lone terminator line (per-heredoc terminators; the over extraction bug
# class is fenced by passing the RIGHT terminator, never a shared one).
extract() {
  # marker is a FIXED STRING (index() match): awk -v/ENVIRON values munge
  # backslash escapes ("\$" → "$" with a warning), which defeats `\$` regex
  # patterns; index() needs no escaping and matches exactly.
  MARKER="$1" awk 'BEGIN{m=ENVIRON["MARKER"]} index($0,m){print NR; exit}' "$SCAFFOLD" > "$TMP/.m" || return 1
  local start; start="$(cat "$TMP/.m")"
  [ -n "$start" ] || die "scaffold heredoc marker not found for: $1 — scaffold format drift; refusing"
  # single awk pass: no pipe (the 2-stage pipe SIGPIPEs under pipefail when the
  # right side exits at the terminator — rc 141 killed applies); -v BEFORE the
  # program (assignments after the program apply at file-open — after BEGIN ran)
  awk -v startline="$start" -v t="$2" '
    NR > startline && !done && $0 == t { done = 1; next }
    NR > startline && !done { print }
    NR > startline && done { exit }
    END { if (!done) exit 3 }
  ' "$SCAFFOLD" > "$3" || {
    rc=$?
    [ "$rc" = 3 ] && { : > "$3"; return 0; }
    return "$rc"
  }
  [ -s "$3" ] || die "extracted $(basename "$3") is empty — scaffold format drift; refusing"
}

# render_dir_heredoc <target-file> <render-mode>: render the scaffold AGENTS heredoc
# with the LIVE folder's identity. Render = the scaffold's own substitution method
# (eval double-quoted heredoc; proven in work-clone-source-01 parity probes).
render_agents() {
  extract 'cat > "$STAGE/AGENTS.md"' 'AGENTS_EOF' "$TMP/AGENTS.md.tpl"
  # AGENTS tpl's ONLY substitution is <folder-slug> (line 2). Token replacement,
  # NOT eval-heredoc rendering: eval EXECUTES backticks/$(…) inside the body
  # (proven: `./session-start.sh` ran, backtick content vanished). Bodies are data.
  sed "1s/<folder-slug>/$(printf '%s' "$(basename "$TARGET")" | sed 's/[&|]/\\&/g')/" \
    "$TMP/AGENTS.md.tpl" > "$TMP/AGENTS.md.rendered"
}

render_readme() {
  # the scaffold's README heredoc is UNQUOTED <<EOF (its terminator is the plain
  # line EOF — not README_EOF; extraction with the wrong terminator dies before a
  # fallback could ever run)
  extract 'cat > "$TARGET/README.md"' 'EOF' "$TMP/README.md.tpl"
  # Live identity: PURPOSE is live line 3; CONVENTION is the live tree block minus
  # the line the scaffold prints LITERALLY after $CONVENTION (comms/.git line — it
  # is not part of the var). Render by TOKEN replacement of exactly the tpl's three
  # variables ($FOLDER, $PURPOSE, $CONVENTION) — NOT eval-heredoc rendering: eval
  # executes backticks/$(…) in the body; bodies are data (see render_agents).
  local purpose conv slug esc
  purpose="$(awk 'NR==3' "$TARGET/README.md" 2>/dev/null || true)"
  slug="$(basename "$TARGET")"
  # live tree block (lines between the ``` fences, slug line included)
  awk '/^```$/{f=!f; next} f && n++ {print}' "$TARGET/README.md" 2>/dev/null \
    > "$TMP/conv-all" || true
  # The scaffold prints the comms/.git line LITERALLY after $CONVENTION (not part
  # of the var). Generic + drift-proof: drop live tree lines that match the tpl's
  # literal tail (lines between the $CONVENTION token and the closing fence).
  awk '/^\$CONVENTION$/{t=1; next} t && $0 == "\\`\\`\\`" {exit} t {print}' \
    "$TMP/README.md.tpl" > "$TMP/conv-tails" || true
  grep -vxF -f "$TMP/conv-tails" "$TMP/conv-all" > "$TMP/.conv" 2>/dev/null \
    || cp "$TMP/conv-all" "$TMP/.conv"
  # pass live strings as files, read inside awk (awk -v munges embedded newlines)
  printf '%s' "$purpose" > "$TMP/.purpose"
  awk -v slug="$slug" -v pf="$TMP/.purpose" -v cf="$TMP/.conv" '
    BEGIN {
      while ((getline l < pf) > 0) purpose = purpose l
      while ((getline l < cf) > 0) conv = conv l "\n"
    }
    {
      gsub(/\\`/, "`")                       # scaffold-escaped backtick -> literal
      gsub(/\$FOLDER\//, slug "/")           # tree slug + inline `slug/` uses
      if ($0 == "$PURPOSE")    { print purpose; next }
      if ($0 == "$CONVENTION") { printf "%s", conv; next }
      print
    }' "$TMP/README.md.tpl" > "$TMP/README.md.rendered"
}

compare_agents() { # 0 = equal, 1 = drift (live missing scaffold lines), 2 = operator-modified
  render_agents
  local live_now rendered
  live_now="$TARGET/AGENTS.md"
  if [ ! -f "$live_now" ]; then return 3; fi
  if cmp -s "$live_now" "$TMP/AGENTS.md.rendered"; then return 0; fi
  # Tail-vs-tail (the slug heading is the only live-owned identity line).
  rendered="$TMP/AGENTS.md.rendered"
  diff <(tail -n +2 "$live_now") <(tail -n +2 "$rendered") > "$TMP/agents.diff" \
    2>/dev/null
  # live lines ABSENT from the render = live-only content (hand-edit/addition)
  # -> not derivable, operator owns them. Scaffold lines absent from live ->
  # drift the apply path restores. Missing-scaffold wins (recoverable loss first):
  if grep -q '^>' "$TMP/agents.diff" && grep -q '^<' "$TMP/agents.diff"; then
    return 1   # live lost scaffold content -> re-render restores
  fi
  if grep -q '^<' "$TMP/agents.diff"; then
    return 2   # live-only additions/hand-edits — apply needs --force-section
  fi
  return 1
}

compare_readme() {
  # The README identity (slug, PURPOSE, tree lines) is LIVE-OWNED — the operator
  # curates it; the tool cannot distinguish operator prose from drift there.
  # Verdict: current (render-equal) or operator-modified (apply needs
  # --force-section). Missing file -> stamped fresh. This is the boring choice:
  # no silent clobber of curated prose, no false-current from identity-derived
  # renders.
  render_readme
  [ -f "$TARGET/README.md" ] || return 3
  cmp -s "$TARGET/README.md" "$TMP/README.md.rendered" && return 0
  return 2
}

compare_file() { # compare_file <live> <marker-pat> <terminator> — 0 equal, 1 drift, 3 missing
  local out="$TMP/cmp.out"
  extract "$2" "$3" "$out" || return 1
  [ -f "$1" ] || return 3
  cmp -s "$1" "$out" && return 0 || return 1
}

# verdict bookkeeping
VERDICTS=""
MUTATIONS=""
report() { # report <class> <artifact-path> <verdict> [detail]
  local v="$3"
  VERDICTS="$VERDICTS
  [$v] $2${4:+ — $4}"
  case "$v" in
    current) : ;;
    drift|missing)
      if [ "$APPLY" = 1 ]; then MUTATIONS="$MUTATIONS $1"; fi ;;
    operator-modified) : ;;
  esac
}

# --- agents + readme (unversioned homes) -----------------------------------------
AGV=0; RDV=0
if want agents; then
  if compare_agents; then report 0 "$TARGET/AGENTS.md" current
  else
    AGV=$?
    case "$AGV" in
      3) report agents "$TARGET/AGENTS.md" missing ;;
      2) report agents "$TARGET/AGENTS.md" operator-modified "standing-section hand-edit not derivable from scaffold" ;;
      1) report agents "$TARGET/AGENTS.md" drift "body differs (live heading preserved on apply)" ;;
    esac
  fi
fi
if want readme; then
  if compare_readme; then report 0 "$TARGET/README.md" current
  else
    RDV=$?
    case "$RDV" in
      3) report readme "$TARGET/README.md" missing ;;
      *) report readme "$TARGET/README.md" operator-modified "root README carries folder-specific prose (purpose line, tree history) — apply only with --only readme --force-section" ;;
    esac
  fi
fi

# --- comms-protocol (versioned homes; byte-parity vs scaffold heredocs) ---
if want comms-protocol; then
  for f in session-start.sh session-end.sh glow-pane.sh; do
    # terminator differs per script: session scripts SCRIPT_EOF, glow-pane GLOW_EOF
    rv=0
    if [ "$f" = "glow-pane.sh" ]; then
      compare_file "$COMMS/$f" "cat > \"\$TARGET/comms/$f\"" 'GLOW_EOF' || rv=$?
    else
      compare_file "$COMMS/$f" "cat > \"\$TARGET/comms/$f\"" 'SCRIPT_EOF' || rv=$?
    fi
    case "$rv" in
      0) report comms-protocol "comms/$f" current ;;
      3) report comms-protocol "comms/$f" missing ;;
      1) report comms-protocol "comms/$f" drift "differs from scaffold heredoc" ;;
    esac
  done
fi

# --- comms-readme -----------------------------------------------------------------
if want comms-readme; then
  rv=0
  compare_file "$COMMS/README.md" 'cat > "$TARGET/comms/README.md"' 'PROTOCOL' || rv=$?
  case "$rv" in
    0) report comms-readme "comms/README.md" current ;;
    3) report comms-readme "comms/README.md" missing ;;
    1) report comms-readme "comms/README.md" drift "differs from scaffold PROTOCOL heredoc" ;;
  esac
fi

# --- templates ---------------------------------------------------------------------
if want templates; then
  # preamble.txt: extract the scaffold's template once; empty live copy = the
  # UN-FILLED stamp the protocol expects (operator fills it per session) — current.
  for t in session-handoff.md conversation.md preamble.txt; do
    if [ ! -f "$COMMS/templates/$t" ]; then
      report templates "comms/templates/$t" missing
      continue
    fi
    extract "cat > \"\$TARGET/comms/templates/$t\"" 'TEMPLATE_EOF' "$TMP/tpl-$t"
    if cmp -s "$COMMS/templates/$t" "$TMP/tpl-$t"; then
      report templates "comms/templates/$t" current
    elif [ "$t" = "preamble.txt" ] && [ ! -s "$COMMS/templates/$t" ]; then
      report templates "comms/templates/$t" current "(empty = un-filled stamp)"
    else
      report templates "comms/templates/$t" drift "differs from scaffold template"
    fi
  done
fi

# --- hook ---------------------------------------------------------------------------
if want hook; then
  rv=0
  compare_file "$COMMS/hooks/pre-push" 'cat > "$STAGE/comms-hook-pre-push"' 'HOOK_EOF' || rv=$?
  case "$rv" in
    0) report hook "comms/hooks/pre-push" current ;;
    3) report hook "comms/hooks/pre-push" missing "(tracked copy; active stamp checked too)" ;;
    1) report hook "comms/hooks/pre-push" drift "tracked hook differs from scaffold HOOK heredoc" ;;
  esac
  if [ -d "$COMMS/.git" ]; then
    if [ ! -x "$COMMS/.git/hooks/pre-push" ]; then
      report hook "comms/.git/hooks/pre-push" missing "(active stamp absent)"
    elif ! cmp -s "$COMMS/.git/hooks/pre-push" "$COMMS/hooks/pre-push"; then
      report hook "comms/.git/hooks/pre-push" drift "active stamp differs from tracked copy"
    else
      report hook "comms/.git/hooks/pre-push" current "(active == tracked)"
    fi
  else
    report hook "comms/.git" missing "(comms/ is not a git repo — migrate-user-comms.sh owns init)"
  fi
fi

# --- .gitignore ---------------------------------------------------------------------
if want .gitignore; then
  rv=0
  compare_file "$COMMS/.gitignore" 'cat > "$TARGET/comms/.gitignore"' 'GITIGNORE_EOF' || rv=$?
  case "$rv" in
    0) report .gitignore "comms/.gitignore" current ;;
    3) report .gitignore "comms/.gitignore" missing ;;
    1)
      if grep -qF '.overwatch-index.jsonl' "$COMMS/.gitignore" 2>/dev/null; then
        report .gitignore "comms/.gitignore" current "(superset of scaffold rules — live-local additions stand)"
      else
        report .gitignore "comms/.gitignore" drift "differs from scaffold GITIGNORE heredoc"
      fi
      ;;
  esac
fi

# --- dirs ----------------------------------------------------------------------------
if want dirs; then
  for d in prior-art artifacts work; do
    if [ -d "$TARGET/$d" ]; then report dirs "$TARGET/$d" current "(exists)"
    else report dirs "$TARGET/$d" missing "(stampable)"
    fi
  done
fi

# --- flat-layout pointer (migrate-user-comms owns it) --------------------------------
PAT='[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]-[0-9][0-9]'
flatcount="$(find "$COMMS" -mindepth 1 -maxdepth 1 -type d -name "$PAT" 2>/dev/null | wc -l | tr -d ' ' || echo 0)"
if [ "${flatcount:-0}" -gt 0 ] 2>/dev/null; then
  echo "NOTE: flat (pre-multi-user) session layout detected under comms/ — layout migration"
  echo "  is migrate-user-comms.sh's job: run it before/after this tool's protocol reconcile."
fi

# --- output ------------------------------------------------------------------------
echo "migrate-enclosing-folder report — $TARGET"
[ "$SCAFFOLD" ] && echo "  scaffold source: $SCAFFOLD"
[ -n "$ONLY" ] && echo "  scope: --only $ONLY"
echo "$VERDICTS"
echo

if [ "$APPLY" = 0 ]; then
  echo "report-only; nothing mutated. To reconcile: add --apply [--only class,class] [--force-section]"
  exit 0
fi

# --- APPLY (mutations start here; unversioned homes carry .bak, comms homes commit) ---
stamp_dirs() {
  for d in prior-art artifacts work; do
    [ -d "$TARGET/$d" ] || { mkdir -p "$TARGET/$d"; echo "stamped dir $TARGET/$d (was missing)"; }
  done
}

if want dirs; then stamp_dirs; fi

apply_unversioned() { # apply_unversioned <class> — agents|readme with .bak + heading/purpose preservation
  local class="$1"
  case "$class" in
    agents)
      render_agents
      if [ ! -f "$TARGET/AGENTS.md" ]; then
        cp "$TMP/AGENTS.md.rendered" "$TARGET/AGENTS.md"
        echo "agents: stamped (was missing)"
        return 0
      fi
      compare_agents; agv=$?
      if [ "$agv" = 0 ]; then echo "agents: already current"; return 0; fi
      if [ "$agv" = 2 ] && [ "$FORCE_SECTION" = 0 ]; then
        echo "agents: REFUSED — standing-section hand-edit (operator-modified); hatch: --only agents --force-section (a .bak is still written)" >&2
        return 1
      fi
      ts="$(date +%Y%m%d%H%M%S)"
      cp "$TARGET/AGENTS.md" "$TARGET/AGENTS.md.bak-$ts"
      slug_line="$(head -1 "$TARGET/AGENTS.md")"
      { printf '%s\n' "$slug_line"; tail -n +2 "$TMP/AGENTS.md.rendered"; } > "$TARGET/AGENTS.md.new"
      mv "$TARGET/AGENTS.md.new" "$TARGET/AGENTS.md"
      echo "agents: stamped current (live heading preserved; .bak-$ts beside it)"
      ;;
    readme)
      render_readme
      if [ ! -f "$TARGET/README.md" ]; then
        cp "$TMP/README.md.rendered" "$TARGET/README.md"; echo "readme: stamped (was missing)"; return 0
      fi
      compare_readme; rdv=$?
      if [ "$rdv" = 0 ]; then echo "readme: already current"; return 0; fi
      if [ "$rdv" = 2 ] && [ "$FORCE_SECTION" = 0 ]; then
        echo "readme: REFUSED — folder-specific prose (operator-modified); hatch: --only readme --force-section" >&2
        return 1
      fi
      ts="$(date +%Y%m%d%H%M%S)"
      cp "$TARGET/README.md" "$TARGET/README.md.bak-$ts"
      cp "$TMP/README.md.rendered" "$TARGET/README.md"
      echo "readme: stamped current (live purpose + convention preserved; .bak-$ts beside it)"
      ;;
  esac
}

apply_comms_file() { # apply_comms_file <class> <dest> <marker-pat> <terminator> <mode-bits>
  local class="$1" dest="$2" pat="$3" term="$4" bits="$5"
  extract "$pat" "$term" "$TMP/apply.out"
  if cmp -s "$dest" "$TMP/apply.out"; then echo "$class: $dest already current"; return 0; fi
  if [ ! -f "$dest" ]; then
    { cat "$TMP/apply.out"; } > "$dest" 2>/dev/null || cp "$TMP/apply.out" "$dest"
    chmod "$bits" "$dest" 2>/dev/null || true
    echo "$class: stamped (was missing)"
    return 0
  fi
  cp "$dest" "$dest.bak-$(date +%Y%m%d%H%M%S)"
  cp "$TMP/apply.out" "$dest"
  chmod "$bits" "$dest" 2>/dev/null || true
  echo "$class: $dest replaced with scaffold-current (named .bak kept)"
}

# comms/.gitignore apply: superset rule — only append rules the live file lacks
apply_gitignore() {
  extract 'cat > "$TARGET/comms/.gitignore"' 'GITIGNORE_EOF' "$TMP/gi.scaffold"
  if cmp -s "$COMMS/.gitignore" "$TMP/gi.scaffold"; then echo ".gitignore: already current"; return 0; fi
  added=0
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    grep -qxF "$line" "$COMMS/.gitignore" 2>/dev/null || { printf '%s\n' "$line" >> "$COMMS/.gitignore"; added=$((added+1)); }
  done < "$TMP/gi.scaffold"
  if [ "$added" -gt 0 ]; then
    echo ".gitignore: appended $added scaffold rule(s) (live-local rules stand)"
  else
    echo ".gitignore: live is a superset of scaffold rules — current"
  fi
}

# hook apply: stamp BOTH copies from the HOOK heredoc (tracked + active)
apply_hook() {
  extract 'cat > "$STAGE/comms-hook-pre-push"' 'HOOK_EOF' "$TMP/hook.out"
  local needs=0
  # tracked copy: missing or stale -> restamp
  if [ ! -f "$COMMS/hooks/pre-push" ] || ! cmp -s "$COMMS/hooks/pre-push" "$TMP/hook.out"; then
    needs=1
  fi
  # active copy: repo exists, stamp missing or differs -> restamp
  if [ -d "$COMMS/.git" ] && { [ ! -x "$COMMS/.git/hooks/pre-push" ] || ! cmp -s "$COMMS/.git/hooks/pre-push" "$TMP/hook.out" 2>/dev/null; }; then
    needs=1
  fi
  if [ "$needs" = 1 ]; then
    mkdir -p "$COMMS/hooks"
    cp "$TMP/hook.out" "$COMMS/hooks/pre-push" && chmod 755 "$COMMS/hooks/pre-push"
    if [ -d "$COMMS/.git" ]; then
      mkdir -p "$COMMS/.git/hooks"
      cp "$TMP/hook.out" "$COMMS/.git/hooks/pre-push" && chmod 755 "$COMMS/.git/hooks/pre-push"
    fi
    echo "hook: stamped tracked + active copies from scaffold HOOK heredoc"
  else
    echo "hook: already current (tracked == active == scaffold)"
  fi
}

# comms cleanliness gate: comms-class applies commit inside comms; mixed state
# would make the rollback commit ambiguous. Untracked is fine (session folders are
# committed by the session protocol itself); MODIFIED tracked files are not.
comms_dirty=0
if command -v git >/dev/null 2>&1 && [ -d "$COMMS/.git" ]; then
  if [ -n "$(git -C "$COMMS" status --porcelain 2>/dev/null | grep -v '^??' || true)" ]; then
    comms_dirty=1
  fi
fi
COMMS_CLASSES="comms-protocol comms-readme templates hook .gitignore"
need_comms=0
for c in $COMMS_CLASSES; do want "$c" && need_comms=1; done
if [ "$need_comms" = 1 ] && [ "$comms_dirty" = 1 ]; then
  die "comms/ has uncommitted MODIFIED tracked files — reconcile deliberately first (comms-sync export, or git -C comms commit); mixed-state applies are unrollbackable"
fi
if [ "$need_comms" = 1 ] && [ ! -d "$COMMS/.git" ]; then
  echo "NOTE: comms/ is not a git repo yet — layout migration (incl. init + hook) is migrate-user-comms.sh; run it first, then re-run this tool's comms classes."
fi

failed=0
for c in agents readme; do want "$c" && { apply_unversioned "$c" || failed=1; }; done
if want comms-protocol; then
  for f in session-start.sh session-end.sh; do
    apply_comms_file comms-protocol "$COMMS/$f" "cat > \"\$TARGET/comms/$f\"" 'SCRIPT_EOF' 755 || failed=1
  done
  if [ -f "$COMMS/glow-pane.sh" ]; then
    apply_comms_file comms-protocol "$COMMS/glow-pane.sh" 'cat > "$TARGET/comms/glow-pane.sh"' 'GLOW_EOF' 755 || failed=1
  fi
fi
if want comms-readme; then apply_comms_file comms-readme "$COMMS/README.md" 'cat > "$TARGET/comms/README.md"' 'PROTOCOL' 644 || failed=1; fi
if want templates; then
  for t in session-handoff.md conversation.md; do
    extract 'templates/'"$t"'"' 'TEMPLATE_EOF' "$TMP/tpl.out"
    if cmp -s "$COMMS/templates/$t" "$TMP/tpl.out" 2>/dev/null; then echo "templates: comms/templates/$t already current"; continue; fi
    mkdir -p "$COMMS/templates"
    [ -f "$COMMS/templates/$t" ] && cp "$COMMS/templates/$t" "$COMMS/templates/$t.bak-$(date +%Y%m%d%H%M%S)"
    cp "$TMP/tpl.out" "$COMMS/templates/$t"
    echo "templates: comms/templates/$t stamped scaffold-current"
  done
  extract 'preamble.txt"' 'PREAMBLE_EOF' "$TMP/tpl.out" 2>/dev/null || true
  if [ -s "$TMP/tpl.out" ]; then
    if cmp -s "$COMMS/templates/preamble.txt" "$TMP/tpl.out" 2>/dev/null; then
      echo "templates: comms/templates/preamble.txt already current"
    elif [ ! -s "$COMMS/templates/preamble.txt" ]; then
      cp "$TMP/tpl.out" "$COMMS/templates/preamble.txt"; echo "templates: preamble.txt stamped (was empty)"
    else
      echo "templates: preamble.txt non-derivable (operator content?) — left untouched"
    fi
  fi
fi
want hook && { apply_hook || failed=1; }
if want .gitignore; then
  if [ -f "$COMMS/.gitignore" ]; then apply_gitignore || failed=1
  else cp "$TMP/gi.scaffold" "$COMMS/.gitignore" 2>/dev/null || { extract 'cat > "$TARGET/comms/.gitignore"' 'GITIGNORE_EOF' "$TMP/gi.scaffold" && cp "$TMP/gi.scaffold" "$COMMS/.gitignore"; }; echo ".gitignore: stamped (was missing)"; fi
fi

# comms commit (the versioned rollback trail) — only when comms is a repo and
# something under comms/ actually changed
if [ -d "$COMMS/.git" ] && [ -d "$COMMS" ] && command -v git >/dev/null 2>&1; then
  if [ -n "$(git -C "$COMMS" status --porcelain 2>/dev/null | grep -v '^??' || true)" ]; then
    git -C "$COMMS" add -A -- ':!*/**' 2>/dev/null || git -C "$COMMS" add -A 2>/dev/null || true
    SCAFFOLD_ID="scaffold@$(git -C "$HERE" rev-parse --short HEAD 2>/dev/null || echo unknown)"
    git -C "$COMMS" -c user.name="$(git config user.name 2>/dev/null || echo "${USER:-comms}")" \
        -c user.email="$(git config user.email 2>/dev/null || echo "${USER:-comms}@$(hostname 2>/dev/null || echo local)")" \
        commit -q -m "protocol reconcile to $SCAFFOLD_ID (migrate-enclosing-folder.sh)" 2>/dev/null \
      && echo "comms: reconcile committed ($(git -C "$COMMS" rev-parse --short HEAD)) — comms history is the rollback" \
      || echo "comms: nothing to commit (template state only)"
  fi
fi

echo
echo "apply done ($([ "$failed" = 0 ] && echo 'all requested classes succeeded' || echo 'SOME CLASSES FAILED — see refusals above; each names its hatch'))."
exit "$failed"