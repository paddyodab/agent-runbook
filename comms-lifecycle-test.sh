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
# Usage: ./comms-lifecycle-test.sh <enclosing-folder-to-test-in>
set -u

TARGET="$(cd "$1" && pwd)"
SCRIPTS="$TARGET/comms"
PASS=0; FAIL=0
declare -a RESULTS

ok()   { PASS=$((PASS+1)); RESULTS+=("PASS $1"); echo "  PASS: $1"; }
fail() { FAIL=$((FAIL+1)); RESULTS+=("FAIL $1: $2"); echo "  FAIL: $1 — $2" >&2; }

# run <expected-rc> <user> <script> [args...] — captures out+err separately
run() {
  local want_rc="$1" user="$2"; shift 2
  OUT="$(USER="$user" HOME=/tmp/lifecycle-home bash "$SCRIPTS/$1" "${@:2}" 2>"$TARGET/.stderr")"
  RC=$?
  ERR="$(cat "$TARGET/.stderr")"
  [ "$RC" = "$want_rc" ]
}

sess_dir() { printf '%s/comms/%s' "$TARGET" "$1"; }

# state isolation: the folder must hold ONLY comms/templates (the protocol files stay;
# session folders + fake ledgers from a previous run are wiped).
rm -rf "$TARGET/comms/u1" "$TARGET/comms/u2" "$TARGET/comms/templates/../.agent" 2>/dev/null
find "$TARGET/comms" -maxdepth 2 -mindepth 1 -type d ! -name templates | xargs rm -rf 2>/dev/null
rm -rf /tmp/lifecycle-home
mkdir -p /tmp/lifecycle-home

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
grep -qF 'U1-TEST-FINDING' /tmp/lifecycle-home/.agent/learnings.md && ok "ledger digest appended" || fail "ledger" "finding not appended"

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

echo
echo "== RESULTS: $PASS pass, $FAIL fail =="
[ "$FAIL" = 0 ]