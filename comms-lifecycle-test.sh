#!/bin/bash
# comms-lifecycle-test.sh — prove the user-keyed comms protocol with TWO fake users,
# and the comms-as-git tier (unit comms-git-01) on the same fixture.
#
# Drives session-start.sh / session-end.sh through the full lifecycle as u1 and u2:
#   1. u1 fresh start                 → comms/u1/<today>-01/ created, no prior handoff
#   2. u2 fresh start while u1 open   → SUCCEEDS (guard is per-user), comms/u2/<today>-01/
#   3. u1 fresh again                 → REFUSED (own unsealed guard)
#   4. u1 --resume                    → reopens u1's own folder
#   5. u1 seal (incomplete handoff)   → REFUSED with named sections
#   6. u1 seal (complete handoff)     → sealed; ledger digest written
#   7. u2 fresh start after u1 sealed, u2's folder removed → u2's first session;
#      does NOT adopt u1's handoff; u1's newest sealed is listed as reading
#  13. cases A–D (+ own-draft fallback): resume source is the caller's own
#      newest sealed handoff; other users' newest sealed are reading only
#   8. u2 seal via explicit arg       → u1 seals u2's draft (cross-user salvage path)
#   9. bad names refused              → templates, bad/user/path, unknown option
#  10. bare seal with no session      → refuses, names the prefixed salvage command
#  11. comms-as-git unit (comms-git-01): comms/ a valid repo with history, tracked +
#      active hook copies identical, hook REFUSES a token-shaped commit (names file:line
#      + the --no-verify escape), POSITIVE control: an innocent range passes
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
#
# HERDR ISOLATION (pane-flood fix, 20261015): the gate normally runs inside a
# herdr-managed agent pane, so HERDR_ENV=1 + HERDR_PANE_ID leak into EVERY
# fixture invocation. session-start.sh's preamble-pane hook then opens a REAL
# nvim pane in the operator's workspace per fake user per start — pointing at
# /tmp fixture paths that the EXIT trap then deletes (16 dead panes from 2
# gate runs here). The gate is not herdr: strip the herdr identity markers
# AND set the hook's own opt-out, so a future hook variant keyed on only one
# of them still can't split panes.
run() {
  local want_rc="$1" user="$2"; shift 2
  OUT="$(USER="$user" HOME="$LIFECYCLE_HOME" \
        env -u HERDR_ENV -u HERDR_PANE_ID -u HERDR_TAB_ID -u HERDR_WORKSPACE_ID \
        COMMS_NO_PREAMBLE_PANE=1 bash "$SCRIPTS/$1" "${@:2}" 2>"$LIFECYCLE_HOME/.stderr")"
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

echo "== 1b. empty omp session-slug dir does not kill the intro (glob guard)"
# Found live in shared-agent-research (patdabney/20261015-03): an EMPTY
# ~/.omp/agent/sessions/<cwd-slug>/ made `ls -t "$dir"/*.jsonl` exit 2; under
# set -euo pipefail the intro died (rc 2, no output) after stamping the session
# folder. The fixture HOME has no omp dir at all — seed the EMPTY dir here.
mkdir -p "$LIFECYCLE_HOME/.omp/agent/sessions/-$(printf '%s' "$TARGET" | sed "s|^$LIFECYCLE_HOME||; s|^/||; s|/|-|g")"
run 0 u1 session-start.sh --resume
echo "$OUT" | grep -q "Session id: (unknown" && ok "intro survives empty omp slug dir (Session id unknown)" || fail "empty omp slug dir" "intro did not survive: rc=$RC out=$OUT"

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
if echo "$OUT" | grep -F "u1's newest sealed handoff" >/dev/null \
   && ! echo "$OUT" | grep -F "the canonical state" >/dev/null; then
  ok "seal message names the caller's newest sealed handoff"
else
  fail "seal message" "$OUT"
fi

echo "== 7. caller with no sealed handoff does not inherit another user's"
# u2's folder was removed: u2 has no handoff. u1's today-01 is sealed. Fresh start
# must NOT resume from u1 (that was the cross-user "canonical" claim). u1 stays
# visible as reading.
rm -rf "$(sess_dir u2)"
run 0 u2 session-start.sh
echo "$OUT" | grep -q "No sealed handoff of your own" \
  && ok "brand-new user starts without adopting another user's handoff" \
  || fail "brand-new user" "inherited or unclear: $OUT"
echo "$OUT" | grep -q "comms/u1/$(date +%Y%m%d)-01/session-handoff.md" \
  && ok "other user's newest sealed handoff is listed as reading" \
  || fail "reading list" "u1 missing: $OUT"
if echo "$OUT" | grep -q "Resuming from"; then
  fail "brand-new user resume line" "adopted a resume source: $OUT"
else
  ok "brand-new user has no resume-from line"
fi

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
YESTERDAY="$(date -v -1d +%Y%m%d 2>/dev/null || date -d "@$(( $(date +%s) - 86400 ))" +%Y%m%d)"
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
# Own newest sealed wins over an older other-user handoff. u1's handoff shares
# today's date-seq (a tie the old selector broke by user name). The resume source
# is u2's own file either way — the tie-breaker must not hand u2 someone else's.
# zz/mw are older and must not win.
run 0 u2 session-start.sh
echo "$OUT" | grep -q "Resuming from your sealed handoff: comms/u2/$TODAY-01/session-handoff.md" \
  && ok "own newest sealed wins over older other-user handoff" || fail "own newest" "wrong: $OUT"
# Date-seq order is NOT re-sorted (fence, session-start-own-sealed-01). A user
# with no handoff of their own does not resume from the global maximum. The
# reading list still orders other users' newest sealed handoffs by date-seq,
# user name breaking a tie — so zz (late alphabet, older) sorts BEFORE u2's
# today, which a path sort would get backwards (zz last).
MW_YESTERDAY="$(date -v -2d +%Y%m%d 2>/dev/null || date -d "@$(( $(date +%s) - 172800 ))" +%Y%m%d)"
mkdir -p "$(sess_dir mw/$MW_YESTERDAY-01)"
fill_handoff "$(sess_dir mw/$MW_YESTERDAY-01)/session-handoff.md" mw
run 0 u2 session-end.sh "mw/$MW_YESTERDAY-01" 2>/dev/null || true
# u2's sealed handoff must SURVIVE: copy it to a neutral user ('zz2' would re-sort;
# instead rename u2's session under a fresh user 'u2' -> keep, and just drop u2's
# UNSEALED drafts). The rm target is anew only; u2 keeps its sealed handoff.
rm -rf "$(sess_dir anew)"
run 0 anew session-start.sh
echo "$OUT" | grep -q "No sealed handoff of your own" \
  && ok "user with no handoff does not resume from the global newest date-seq" \
  || fail "anew resume" "wrong: $OUT"
# reading-list order: mw (oldest), zz, u1, u2 (same date-seq, u1 < u2).
# Anchor on the numbered reading item. The intro prose also says "Other users"
# before the list; a looser match exits at "  1. comms/README.md".
ranks="$(echo "$OUT" | awk '
  /^  3\. Other users/ { p = 1; next }
  p && /^  [0-9]+\./ { exit }
  p && /session-handoff.md/ { print }
')"
mw_n="$(echo "$ranks" | grep -n "mw/$MW_YESTERDAY-01/" | head -1 | cut -d: -f1)"
zz_n="$(echo "$ranks" | grep -n "zz/$YESTERDAY-01/" | head -1 | cut -d: -f1)"
u1_n="$(echo "$ranks" | grep -n "u1/$TODAY-01/" | head -1 | cut -d: -f1)"
u2_n="$(echo "$ranks" | grep -n "u2/$TODAY-01/" | head -1 | cut -d: -f1)"
if [ -n "$mw_n" ] && [ -n "$zz_n" ] && [ -n "$u1_n" ] && [ -n "$u2_n" ] \
   && [ "$mw_n" -lt "$zz_n" ] && [ "$zz_n" -lt "$u1_n" ] && [ "$u1_n" -lt "$u2_n" ] \
   && ! echo "$ranks" | grep -q "u2/$TODAY-02/"; then
  ok "reading list keeps date-seq order and user-name tie-break (not path order)"
else
  fail "reading order" "mw=$mw_n zz=$zz_n u1=$u1_n u2=$u2_n list=$ranks"
fi

echo "== 12. own-user sealed history participates (fresh start is not a false bootstrap)"
# The caller's own SEALED handoffs are the resume source. 12a — vz/TODAY-01 is
# sealed; vz's fresh start resumes from that file, not from an earlier user's.
mkdir -p "$(sess_dir vz/"$TODAY"-01)"
fill_handoff "$(sess_dir vz/"$TODAY"-01)/session-handoff.md" vz
run 0 u2 session-end.sh "vz/$TODAY-01" 2>/dev/null || true
grep -qF 'SEAL' "$(sess_dir vz/"$TODAY"-01/session-handoff.md)" && fail "vz seal" "SEAL still present"
ok "vz/$TODAY-01 sealed (own-user fixture)"
if run 0 vz session-start.sh; then
  if echo "$OUT" | grep -q "Resuming from your sealed handoff: comms/vz/$TODAY-01/session-handoff.md"; then
    ok "own newest sealed wins on fresh start (no false first-session)"
  else
    fail "own newest sealed" "own sealed handoff ignored: $OUT"
  fi
else
  fail "own newest sealed" "session-start exited nonzero: $ERR"
fi
# 12b — own newest entry is an UNSEALED draft: strip the fixture to wdr only; wdr's
# newest = yesterday's template draft (SEAL marker present), sealed = 2 days ago.
# Fresh start must warn about the draft AND resume the newest sealed (its own).
rm -rf "$(sess_dir u1)" "$(sess_dir u2)" "$(sess_dir zz)" "$(sess_dir mw)" "$(sess_dir vz)"
mkdir -p "$(sess_dir wdr/"$MW_YESTERDAY"-01)" "$(sess_dir wdr/"$YESTERDAY"-01)"
fill_handoff "$(sess_dir wdr/"$MW_YESTERDAY"-01)/session-handoff.md" wdr
run 0 u2 session-end.sh "wdr/$MW_YESTERDAY-01" 2>/dev/null || true
cp "$SCRIPTS/templates/session-handoff.md" "$(sess_dir wdr/"$YESTERDAY"-01)/session-handoff.md"
if run 0 wdr session-start.sh; then
  if echo "$OUT" | grep -q "Resuming from your sealed handoff: comms/wdr/$MW_YESTERDAY-01/session-handoff.md"; then
    ok "own unsealed draft skipped; newest sealed resumed"
  else
    fail "own draft fallback" "draft ignored or wrong target: $OUT"
  fi
else
  fail "own draft fallback" "session-start exited nonzero: $ERR"
fi
if echo "$ERR" | grep -q "unsealed draft"; then
  ok "draft skipped with a loud warning"
else
  fail "draft warning" "silent fallback: $ERR"
fi

echo "== 13. resume source is the caller's own newest sealed (cases A-D)"
# Date-seq order and the user-name tie-break are not re-sorted here. Each case
# is isolated (session dirs wiped) so one start cannot plant a draft for the next.
# Users patdabney / dustinwarner match the e399eac repro: dustinwarner < patdabney.
wipe_user_sessions() {
  find "$TARGET/comms" -mindepth 1 -maxdepth 1 -type d \
    ! -name templates ! -name hooks ! -name '.git' -exec rm -rf {} +
}
plant_session() {
  local rel="$1" mode="$2"
  local dir="$TARGET/comms/$rel"
  mkdir -p "$dir"
  cp "$SCRIPTS/templates/session-handoff.md" "$dir/session-handoff.md"
  cp "$SCRIPTS/templates/conversation.md" "$dir/conversation.md"
  fill_handoff "$dir/session-handoff.md" "${rel%%/*}"
  if [ "$mode" = draft ]; then
    {
      printf '%s\n' \
        '<!-- SEAL: delete this line when this handoff is final. While present, this file is a' \
        '     draft: session-start.sh will not treat it as canonical, and the folder is unsealed. -->'
      cat "$dir/session-handoff.md"
    } > "$dir/session-handoff.md.tmp" && mv "$dir/session-handoff.md.tmp" "$dir/session-handoff.md"
  fi
}

echo "-- A: same date-seq, earlier name sealed later"
wipe_user_sessions
plant_session "patdabney/$TODAY-01" sealed
plant_session "dustinwarner/$TODAY-01" sealed
touch -d '2020-01-01 00:00:00' "$TARGET/comms/patdabney/$TODAY-01/session-handoff.md"
touch -d '2030-01-01 00:00:00' "$TARGET/comms/dustinwarner/$TODAY-01/session-handoff.md"
if run 0 dustinwarner session-start.sh; then
  if echo "$OUT" | grep -q "Resuming from your sealed handoff: comms/dustinwarner/$TODAY-01/session-handoff.md" \
     && echo "$OUT" | grep -q "comms/patdabney/$TODAY-01/session-handoff.md"; then
    ok "A: earlier-named caller resumes from his own sealed handoff (seal time ignored)"
  else
    fail "A dustin" "wrong: $OUT"
  fi
else
  fail "A dustin" "rc=$RC $ERR"
fi
wipe_user_sessions
plant_session "patdabney/$TODAY-01" sealed
plant_session "dustinwarner/$TODAY-01" sealed
touch -d '2020-01-01 00:00:00' "$TARGET/comms/patdabney/$TODAY-01/session-handoff.md"
touch -d '2030-01-01 00:00:00' "$TARGET/comms/dustinwarner/$TODAY-01/session-handoff.md"
if run 0 patdabney session-start.sh; then
  if echo "$OUT" | grep -q "Resuming from your sealed handoff: comms/patdabney/$TODAY-01/session-handoff.md" \
     && echo "$OUT" | grep -q "comms/dustinwarner/$TODAY-01/session-handoff.md"; then
    ok "A: later-named caller resumes from his own and lists the other user"
  else
    fail "A pat" "wrong: $OUT"
  fi
else
  fail "A pat" "rc=$RC $ERR"
fi

echo "-- B: a higher sequence in someone else's folder is reading, not the resume source"
wipe_user_sessions
plant_session "patdabney/$TODAY-01" sealed
plant_session "patdabney/$TODAY-02" sealed
plant_session "dustinwarner/$TODAY-01" sealed
plant_session "dustinwarner/$TODAY-02" sealed
plant_session "dustinwarner/$TODAY-03" sealed
if run 0 patdabney session-start.sh; then
  if echo "$OUT" | grep -q "Resuming from your sealed handoff: comms/patdabney/$TODAY-02/session-handoff.md" \
     && echo "$OUT" | grep -q "comms/dustinwarner/$TODAY-03/session-handoff.md" \
     && ! echo "$OUT" | grep -q "Resuming from your sealed handoff: comms/dustinwarner/"; then
    ok "B: caller resumes from own newest sealed; other user's newer seq is reading"
  else
    fail "B" "wrong: $OUT"
  fi
else
  fail "B" "rc=$RC $ERR"
fi

echo "-- C: sealing an older own handoff is not global canonical"
wipe_user_sessions
plant_session "patdabney/$TODAY-01" sealed
plant_session "dustinwarner/$YESTERDAY-01" draft
if run 0 dustinwarner session-end.sh "dustinwarner/$YESTERDAY-01"; then
  if echo "$OUT" | grep -F "dustinwarner's newest sealed handoff" >/dev/null \
     && ! echo "$OUT" | grep -F "the canonical state" >/dev/null; then
    ok "C: session-end names the owner's newest sealed handoff, not global canonical"
  else
    fail "C seal message" "untruthful: $OUT"
  fi
else
  fail "C seal" "rc=$RC $ERR"
fi
if run 0 dustinwarner session-start.sh; then
  if echo "$OUT" | grep -q "Resuming from your sealed handoff: comms/dustinwarner/$YESTERDAY-01/session-handoff.md" \
     && echo "$OUT" | grep -q "comms/patdabney/$TODAY-01/session-handoff.md"; then
    ok "C: caller resumes from own older sealed handoff; newer other-user is reading"
  else
    fail "C start" "wrong: $OUT"
  fi
else
  fail "C start" "rc=$RC $ERR"
fi

echo "-- D: another user's unsealed draft does not warn or redirect"
wipe_user_sessions
plant_session "dustinwarner/$YESTERDAY-01" sealed
plant_session "patdabney/$TODAY-01" sealed
plant_session "patdabney/$TODAY-02" draft
if run 0 dustinwarner session-start.sh; then
  if echo "$OUT" | grep -q "Resuming from your sealed handoff: comms/dustinwarner/$YESTERDAY-01/session-handoff.md" \
     && echo "$OUT" | grep -q "comms/patdabney/$TODAY-01/session-handoff.md" \
     && ! echo "$OUT" | grep -q "patdabney/$TODAY-02" \
     && ! echo "$ERR" | grep -q "unsealed draft"; then
    ok "D: other user's draft does not warn or replace the caller's own sealed handoff"
  else
    fail "D" "out=$OUT err=$ERR"
  fi
else
  fail "D" "rc=$RC $ERR"
fi

echo "-- E: own unsealed draft falls back to own sealed, not a colleague's newer sealed"
wipe_user_sessions
plant_session "patdabney/$MW_YESTERDAY-01" sealed
plant_session "patdabney/$YESTERDAY-01" draft
plant_session "dustinwarner/$TODAY-01" sealed
if run 0 patdabney session-start.sh; then
  if echo "$OUT" | grep -q "Resuming from your sealed handoff: comms/patdabney/$MW_YESTERDAY-01/session-handoff.md" \
     && echo "$ERR" | grep -q "unsealed draft" \
     && echo "$OUT" | grep -q "comms/dustinwarner/$TODAY-01/session-handoff.md"; then
    ok "E: own unsealed draft falls back to own sealed, not another user's newer sealed"
  else
    fail "E" "out=$OUT err=$ERR"
  fi
else
  fail "E" "rc=$RC $ERR"
fi

echo "-- sealing an older folder does not claim to be the newest"
wipe_user_sessions
plant_session "patdabney/$TODAY-02" sealed
plant_session "patdabney/$TODAY-01" draft
if run 0 patdabney session-end.sh "patdabney/$TODAY-01"; then
  if echo "$OUT" | grep -F "remains comms/patdabney/$TODAY-02/session-handoff.md" >/dev/null \
     && ! echo "$OUT" | grep -F "the canonical state" >/dev/null \
     && ! echo "$OUT" | grep -F "it is now patdabney's newest" >/dev/null; then
    ok "sealing an older handoff names the newer one that remains"
  else
    fail "older seal message" "$OUT"
  fi
else
  fail "older seal" "rc=$RC $ERR"
fi

echo
echo "== 11. comms-as-git (unit 1): repo valid + credential hook fires (8 assertions)"
# The fixture comms/ was staged byte-wise from the SOURCE scaffold's comms/ — a
# scaffold-stamped folder brings .git, .gitignore, hooks/pre-push with it. A live
# folder also has them (post-unit-1). If the source comms isn't a repo (a
# pre-unit-1 fixture), these assertions still must be HONEST: skip-count them as
# absence proofs, never as green-by-silence.
if [ ! -d "$SCRIPTS/.git" ]; then
  fail "comms-as-git repo present" "source comms/ has no .git — scaffold predates unit 1? re-scaffold or run migrate first"
else
  git -C "$SCRIPTS" rev-parse --is-inside-work-tree >/dev/null 2>&1 \
    && ok "comms/ is a valid git repo" \
    || fail "comms-as-git repo" "git rev-parse failed inside fixture"
  git -C "$SCRIPTS" log --oneline 2>/dev/null | grep -q . \
    && ok "comms repo has history (initial commit)" \
    || fail "comms-as-git history" "no commits"
  [ -x "$SCRIPTS/hooks/pre-push" ] \
    && ok "tracked hook copy present (comms/hooks/pre-push)" \
    || fail "tracked hook" "missing comms/hooks/pre-push"
  [ -x "$SCRIPTS/.git/hooks/pre-push" ] \
    && ok "active hook stamped (.git/hooks/pre-push executable)" \
    || fail "active hook" "missing or non-executable"
  cmp -s "$SCRIPTS/hooks/pre-push" "$SCRIPTS/.git/hooks/pre-push" \
    && ok "hook copies identical (tree vs active)" \
    || fail "hook parity" "tree and .git/hooks copies differ"
  # HOOK-FIRES: drive a real push through the fixture repo. Remote = bare sibling.
  # Invocation mirrors real git: hooks run with CWD = repo root, so the harness
  # subshells into the repo (invoking by absolute path from elsewhere finds no
  # repo and skips every ref — silent-green would be the worst failure mode).
  HOOKFIX="$RUNROOT/hookrepo.git"
  git clone -q --bare "$SCRIPTS" "$HOOKFIX" 2>/dev/null
  # feed a leaky push plan: new commits carrying a fake-but-shaped token
  LEAK_COMMIT_LINE='token = "gate-leak-test-9999"'
  echo "$LEAK_COMMIT_LINE" > "$SCRIPTS/.gate-leak.md"
  git -C "$SCRIPTS" add .gate-leak.md
  git -C "$SCRIPTS" -c user.name=gate -c user.email=gate@gate commit -qm "gate leak probe" >/dev/null 2>&1
  LATEST="$(git -C "$SCRIPTS" rev-parse HEAD)"
  BEFORE="$(git -C "$SCRIPTS" rev-parse HEAD~1 2>/dev/null || git -C "$SCRIPTS" rev-list --max-parents=0 HEAD)"
  if (cd "$SCRIPTS" && echo "refs/heads/master $LATEST refs/heads/master $BEFORE" \
      | bash .git/hooks/pre-push) 2>"$LIFECYCLE_HOME/.hookerr"; then
    fail "hook refuses credential commit" "exit 0 on a token-shaped push"
  else
    ok "hook refuses credential-shaped commit (exit 1)"
    grep -q "credential-shaped" "$LIFECYCLE_HOME/.hookerr" \
      && ok "refusal explains itself" || fail "hook refusal text" "no explanation: $(cat "$LIFECYCLE_HOME/.hookerr")"
    grep -q "gate-leak-test-9999" "$LIFECYCLE_HOME/.hookerr" \
      && ok "refusal names the offending line" || fail "offending line" "not quoted"
    grep -q -- "--no-verify" "$LIFECYCLE_HOME/.hookerr" \
      && ok "refusal names the deliberate escape" || fail "escape hatch" "not named"
  fi
  # POSITIVE CONTROL: a clean push must pass the same hook (same path, same input shape)
  git -C "$SCRIPTS" reset -q --hard "$BEFORE"
  CLEAN="$(git -C "$SCRIPTS" rev-parse HEAD)"
  if (cd "$SCRIPTS" && echo "refs/heads/master $CLEAN refs/heads/master $BEFORE" \
      | bash .git/hooks/pre-push) 2>"$LIFECYCLE_HOME/.hookerr"; then
    ok "positive control: clean range passes the hook"
  else
    fail "clean push blocked" "hook refused an innocent range: $(cat "$LIFECYCLE_HOME/.hookerr" | head -2)"
  fi
fi

echo
echo "== RESULTS: $PASS pass, $FAIL fail (comms-as-git extended set) =="
[ "$FAIL" = 0 ]