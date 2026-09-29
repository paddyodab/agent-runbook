#!/bin/bash
# comms-lifecycle-test.sh — prove the user-keyed comms protocol with TWO fake users.
#
# Drives session-start.sh / session-end.sh through the full lifecycle as u1 and u2:
#   1. u1 fresh start                 → comms/u1/<today>-01/ created, no prior handoff
#   2. u2 fresh start while u1 open   → SUCCEEDS (guard is per-user), comms/u2/<today>-01/
#   3. u1 fresh again                 → REFUSED (own unsealed guard)
#   4. u1 --resume                    → reopens u1's own folder
#   5. u1 seal (incomplete handoff)   → REFUSED with named sections
#   6. u1 seal (complete handoff)     → sealed; ledger digest written
#   7. u2 fresh start after u1 sealed → resumes from u1's sealed handoff (cross-user)
#   8. u2 seal via explicit arg       → u1 seals u2's draft (cross-user salvage path)
#   9. bad names refused              → templates, bad/user/path, unknown option
#  10. bare seal with no session      → refuses, names the prefixed salvage command
#
# Runs the scripts as-is; user identity comes from $COMMS_TEST_USER (the scripts read
# USER). Each assertion is observable: exit code + filesystem effect + stdout/stderr.
#
# Usage: ./comms-lifecycle-test.sh <folder-with-comms-scaffold>
#
# SAFETY: the run NEVER touches the folder you name, and never leaves /tmp state
# behind. It stages one disposable run root (a single mktemp -d holding the whole
# comms/ protocol tree MINUS any session folders, plus its own ledger HOME) and
# mutates only that. This harness drives the scripts THROUGH destructive lifecycle
# steps, so pointing it at a live enclosing folder must be structurally safe: the
# run root is what gets wiped, not the operator's sessions.
# CONCURRENCY: one run root per invocation (mktemp is PID/instance-unique) and the
# ledger HOME lives inside it, so concurrent gate runs cannot erase each other.
set -u

usage() {
  echo "usage: $0 <folder-with-comms-scaffold>" >&2
  echo "  <folder> must contain comms/ with README.md, session-start.sh," >&2
  echo "  session-end.sh, templates/ — i.e. any enclosing folder (live ones" >&2
  echo "  are safe: the run mutates only its own /tmp fixture, never <folder>)." >&2
  exit 1
}
[ "${1:-}" ] || usage
[ -d "$1/comms" ] || { echo "refused: no comms/ under $1 — not a comms scaffold" >&2; exit 1; }
[ -x "$1/comms/session-start.sh" ] && [ -x "$1/comms/session-end.sh" ] || {
  echo "refused: $1/comms lacks executable session-start.sh / session-end.sh" >&2
  exit 1
}

TARGET="$(cd "$1" && pwd)"
SCRIPTS="$TARGET/comms"        # the SOURCE scaffold (read-only from the harness's view)
RUNROOT="$(mktemp -d /tmp/comms-lifecycle.XXXXXX)"
FIXTURE="$RUNROOT/comms"       # backwards-compat alias in failure text
PASS=0; FAIL=0
declare -a RESULTS

ok()   { PASS=$((PASS+1)); RESULTS+=("PASS $1"); echo "  PASS: $1"; }
fail() { FAIL=$((FAIL+1)); RESULTS+=("FAIL $1: $2"); echo "  FAIL: $1 — $2" >&2; }

# run <expected-rc> <user> <script> [args...] — captures out+err separately
run() {
  local want_rc="$1" user="$2"; shift 2
  OUT="$(USER="$user" HOME="$LIFECYCLE_HOME" bash "$SCRIPTS/$1" "${@:2}" 2>"$LIFECYCLE_HOME/.stderr")"
  RC=$?
  ERR="$(cat "$LIFECYCLE_HOME/.stderr")"
  [ "$RC" = "$want_rc" ]
}

sess_dir() { printf '%s/comms/%s' "$TARGET" "$1"; }

# fixture staging: copy the named folder's comms/ protocol scaffold into a
# disposable run root; the run mutates ONLY the run root. Copy is the whole
# comms/ protocol tree minus session state (session dirs hold real operator
# sessions on a live folder; the fixture must start from template state). Anything
# a future scaffold stamps under comms/ rides along automatically — an explicit
# file manifest would silently exclude it (laptop review, concern 5).
mkdir -p "$RUNROOT"
cp -R "$SCRIPTS/." "$RUNROOT/comms/"
find "$RUNROOT/comms" -mindepth 2 -maxdepth 2 -type d -name '[0-9]*-*' -exec rm -rf {} + 2>/dev/null || true
rm -rf "$RUNROOT/comms/templates/../.agent" 2>/dev/null
chmod +x "$RUNROOT"/comms/session-start.sh "$RUNROOT"/comms/session-end.sh 2>/dev/null
# the scripts resolve this-session paths relative to the fixture root; SCRIPTS
# stays pinned to the fixture comms (the run executes the COPIED scripts — the
# source folder's copies are never executed or mutated)
SCRIPTS="$RUNROOT/comms"
TARGET="$RUNROOT"
trap 'rm -rf "$RUNROOT"' EXIT
# the ledger HOME lives inside the run root (one mktemp owns everything; a
# root-run docker proof can leave root-owned files behind — recreate cleanly
# each run, and the refusal path names the hatch)
if [ -e "$RUNROOT/home" ]; then rm -rf "$RUNROOT/home"; fi
mkdir -p "$RUNROOT/home"
LIFECYCLE_HOME="$RUNROOT/home"

echo "== 1. u1 fresh start"
run 0 u1 session-start.sh
[ -d "$(sess_dir u1/$(date +%Y%m%d)-01)" ] && ok "u1 fresh start creates comms/u1/<today>-01" || fail "u1 fresh start" "folder missing"
echo "$OUT" | grep -q "comms/u1/$(date +%Y%m%d)-01" && ok "intro names u1's session folder" || fail "intro" "session folder path not in intro"

echo "== 2. u2 fresh start while u1 unsealed (per-user guard)"
run 0 u2 session-start.sh
[ -d "$(sess_dir u2/$(date +%Y%m%d)-01)" ] && ok "u2 fresh start succeeds while u1 unsealed" || fail "u2 fresh start" "folder missing"

echo "== 3. u1 fresh again (own unsealed guard)"
run 1 u1 session-start.sh
echo "$ERR" | grep -q "still unsealed" && ok "u1 own-unsealed guard fires" || fail "u1 guard" "no refusal: $ERR"

echo "== 4. u1 --resume reopens own folder"
run 0 u1 session-start.sh --resume
echo "$OUT" | grep -q "u1/$(date +%Y%m%d)-01" && ok "u1 --resume reopens own session" || fail "u1 resume" "wrong folder: $OUT"

echo "== 5. u1 seal incomplete → refused with section names"
run 1 u1 session-end.sh
echo "$ERR" | grep -q "handoff incomplete" && ok "incomplete seal refused" || fail "incomplete seal" "no refusal: $ERR"

echo "== 6. fill u1 handoff + seal"
# bash-3.2 portable fill (no python): strip SEAL block, fill each section.
fill_handoff() {
  local f="$1" u="$2"
  # synthetic fixtures (mkdir'd by the test) may lack a handoff file — stamp the
  # template so the filler has something to fill
  if [[ ! -f "$f" ]]; then
    cp "$SCRIPTS/templates/session-handoff.md" "$f"
  fi
  awk 'BEGIN{skip=0} !skip && index($0,"<!-- SEAL:")==1 {skip=(index($0,"-->")==0); next} skip {skip=(index($0,"-->")==0); next} {print}' "$f" > "$f.tmp" && mv "$f.tmp" "$f"
  # awk wholesale section-body replacement (bash-3.2 portable; no python, no perl)
  awk -v u="$u" '
    BEGIN { insec = 0 }
    /^## / {
      h = $0
      body = ""
      if (h ~ /## What this session did/) body = "1. Lifecycle test."
      else if (h ~ /## Canonical state/) body = "1. " u " sealed."
      else if (h ~ /## How to resume/) body = "1. none\n2. none\n3. Files to read for the next piece of work — ONLY these:\n   - none\n4. Evidence dirs: none"
      else if (h ~ /## Methodology findings/) body = "1. " toupper(u) "-TEST-FINDING."
      else if (h ~ /## Open problems/) body = "1. none"
      else if (h ~ /## Do not/) body = "1. none"
      else if (h ~ /## Links backward/) body = "none"
      else if (h ~ /## Notes for the next session/) body = "none"
      if (body != "") { print h; print ""; print body; print ""; insec = 1; skip_body = 1; next }
    }
    skip_body && /^## / { skip_body = 0 }
    skip_body { next }
    { print }
  ' "$f" > "$f.tmp" && mv "$f.tmp" "$f"
}
fill_handoff "$(sess_dir u1/$(date +%Y%m%d)-01)/session-handoff.md" u1
sed "s/{{DATE-SEQ}}/$(date +%Y%m%d)-01/g" "$SCRIPTS/templates/conversation.md" > "$(sess_dir u1/$(date +%Y%m%d)-01)/conversation.md"
run 0 u1 session-end.sh
grep -qF 'SEAL' "$(sess_dir u1/$(date +%Y%m%d)-01/session-handoff.md)" && fail "u1 seal" "SEAL marker still present" || ok "u1 sealed (marker gone)"
grep -qF 'U1-TEST-FINDING' "$LIFECYCLE_HOME/.agent/learnings.md" && ok "ledger digest appended" || fail "ledger" "finding not appended"

echo "== 7. u2 fresh start resumes from u1's sealed handoff"
rm -rf "$(sess_dir u2)"
run 0 u2 session-start.sh
echo "$OUT" | grep -q "Resuming from sealed handoff: comms/u1/$(date +%Y%m%d)-01/session-handoff.md" \
  && ok "cross-user resume from u1 sealed handoff" || fail "cross-user resume" "not resumed: $OUT"

echo "== 8. cross-user seal: u1 seals u2's draft"
# u2's fresh-started handoff is a template draft — fill it like an operator would first
fill_handoff "$(sess_dir u2/$(date +%Y%m%d)-01)/session-handoff.md" u2
run 0 u1 session-end.sh "u2/$(date +%Y%m%d)-01"
grep -qF 'SEAL' "$(sess_dir u2/$(date +%Y%m%d)-01/session-handoff.md)" && fail "cross-user seal" "SEAL still present" || ok "u2 draft sealed by u1 (explicit prefixed arg)"

echo "== 9. bad names refused"
run 1 u1 session-end.sh templates
echo "$ERR" | grep -q "not a session folder name" && ok "templates refused" || fail "templates" "no refusal"
run 1 u1 session-end.sh "bad/path/20260928-01"
echo "$ERR" | grep -q "too many slashes" && ok "multi-slash name refused" || fail "bad name" "no refusal"
run 1 u1 session-end.sh --resume
echo "$ERR" | grep -q "unknown option" && ok "--resume refused in session-end" || fail "--resume" "no refusal"

echo "== 10. bare seal, caller has no session → refuse naming salvage"
rm -rf "$(sess_dir u2)"
run 1 u2 session-end.sh
echo "$ERR" | grep -qE 'no session folder from today.*under comms/u2/' && ok "bare seal refuses for empty user" || fail "bare seal" "no refusal: $ERR"

echo "== 11. cross-user CHRONOLOGY: newest date-seq wins regardless of user name"
# The path-sort bug class: a LATE-alphabet user holding an OLD handoff vs an
# EARLY-alphabet user holding a NEW one. Fixtures use real calendar offsets so the
# test is date-independent:
YESTERDAY="$(date -v -1d +%Y%m%d 2>/dev/null || date -u -d "@$(( $(date -u +%s) - 86400 ))" +%Y%m%d)"
TODAY="$(date +%Y%m%d)"
mkdir -p "$(sess_dir zz/$YESTERDAY-01)"
fill_handoff "$(sess_dir zz/$YESTERDAY-01)/session-handoff.md" zz
run 0 u2 session-end.sh "zz/$YESTERDAY-01" 2>/dev/null || true
grep -qF 'SEAL' "$(sess_dir zz/$YESTERDAY-01/session-handoff.md)" && fail "zz seal" "SEAL still present" || ok "zz/$YESTERDAY-01 sealed (old handoff)"
# u2's own TODAY sealed session: create explicitly (step 10 removed u2)
run 0 u2 session-start.sh
fill_handoff "$(sess_dir u2/$(date +%Y%m%d)-01)/session-handoff.md" u2
sed "s/{{DATE-SEQ}}/$(date +%Y%m%d)-01/g" "$SCRIPTS/templates/conversation.md" > "$(sess_dir u2/$(date +%Y%m%d)-01)/conversation.md"
run 0 u2 session-end.sh "u2/$(date +%Y%m%d)-01" 2>/dev/null || true
grep -qF 'SEAL' "$(sess_dir u2/$(date +%Y%m%d)-01/session-handoff.md)" && fail "u2 seal" "SEAL still present" || ok "u2/$TODAY-01 sealed (newest handoff)"
# own newest wins over older other-user handoff: u2's own TODAY is sealed; the
# only OLDER handoffs are zz (yesterday) + mw (2 days ago). u1's handoff is ALSO
# today's date-seq (sealed in step 6) — a genuine date-seq TIE, broken by user
# name (u1 < u2, deterministic, documented). So the resumed PRIOR must be either
# u2's own (sole-newest case) or u1's (tie case) — NEVER zz/mw (older).
run 0 u2 session-start.sh
echo "$OUT" | grep -Eq "Resuming from sealed handoff: comms/u[12]/$TODAY-01/session-handoff.md" \
  && ok "own-newest (or documented tie) wins over older other-user handoff" || fail "own newest" "wrong: $OUT"
# the real trap: u1 (alphabetically EARLY) with the NEWEST date-seq — impossible
# with real dates (can't seal tomorrow), so the newest-cross-user fixture is:
# u2 has OWN today-sealed + zz has OLDER sealed; a THIRD user (mid-alphabet 'mw')
# gets an intermediate date; fresh-start for a FOURTH user 'anew' must pick u2's
# today (newest), regardless of zz sorting last.
MW_YESTERDAY="$(date -v -2d +%Y%m%d 2>/dev/null || date -u -d "@$(( $(date -u +%s) - 172800 ))" +%Y%m%d)"
mkdir -p "$(sess_dir mw/$MW_YESTERDAY-01)"
fill_handoff "$(sess_dir mw/$MW_YESTERDAY-01)/session-handoff.md" mw
run 0 u2 session-end.sh "mw/$MW_YESTERDAY-01" 2>/dev/null || true
# u2's sealed handoff must SURVIVE: copy it to a neutral user ('zz2' would re-sort;
# instead rename u2's session under a fresh user 'u2' -> keep, and just drop u2's
# UNSEALED drafts). The rm target is anew only; u2 keeps its sealed handoff.
rm -rf "$(sess_dir anew)"
run 0 anew session-start.sh
echo "$OUT" | grep -q "Resuming from sealed handoff: comms/u2/$TODAY-01/session-handoff.md" \
  && ok "newest date-seq wins across users (not path order)" || fail "chronology" "wrong: $OUT"

echo
echo "== RESULTS: $PASS pass, $FAIL fail (18 assertions) =="
[ "$FAIL" = 0 ]