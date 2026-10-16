#!/bin/bash
# proof-migration-enclosing-01.sh — the .evidence/migration-enclosing-01 proof arms,
# driven end-to-end. Every assertion: observed rc + filesystem effect, no self-report.
# Usage: bash .evidence/migration-enclosing-01/proof.sh <runbook-repo> ; artifacts in ./
set -u
RUNBOOK="$(cd "$1" && pwd)"
TOOL="$RUNBOOK/migrate-enclosing-folder.sh"
SCAFFOLD="$RUNBOOK/scaffold/new-enclosing-folder.sh"
E="$PWD"
PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); echo "PASS: $1"; }
bad() { FAIL=$((FAIL+1)); echo "FAIL: $1 — $2" >&2; }

build_scaffold() { # <name> — a fresh enclosing folder via the real scaffold
  local n="$1"
  rm -rf "/tmp/$n"
  printf '%s\n%s\n/tmp\n' "$n" "$n fixture for migration-enclosing-01" \
    | bash "$SCAFFOLD" >/dev/null 2>&1
  mkdir -p "/tmp/$n/prior-art" "/tmp/$n/artifacts" "/tmp/$n/work"
  echo "/tmp/$n"
}

treehash() { find "$1" -type f | sort | xargs md5sum 2>/dev/null | md5sum | cut -d' ' -f1; }

report_of() { bash "$TOOL" "$1" 2>/dev/null; }

echo "=== 1. all-current: every verdict current, rc 0, zero mutation"
F1="$(build_scaffold mig-all-current)"
H1="$(treehash "$F1")"
OUT1="$(report_of "$F1")"; RC1=$?
[ "$RC1" = 0 ] && ok "1a all-current report rc 0" || bad "1a rc" "$RC1"
echo "$OUT1" | grep -q 'operator-modified\|\[drift\]\|\[missing\]' \
  && bad "1b verdicts" "unexpected non-current verdict" || ok "1b all verdicts current"
[ "$(treehash "$F1")" = "$H1" ] && ok "1c report mutated nothing (tree hash stable)" \
  || bad "1c mutation" "tree changed in report mode"
bash "$TOOL" "$F1" --apply >/dev/null 2>&1; RC=$?
[ "$RC" = 0 ] && ok "1d all-current apply rc 0 (no-op apply)" || bad "1d rc" "$RC"
[ "$(treehash "$F1")" = "$H1" ] && ok "1e all-current apply mutated nothing" \
  || bad "1e mutation" "no-op apply changed files"

echo "=== 2. stale: degraded AGENTS + README + removed hook → named verdicts; apply restores"
F2="$(build_scaffold mig-stale)"
python3 - "$F2" <<'PYEOF'
import sys, re
f2 = sys.argv[1]
ag = open(f2+"/AGENTS.md").read()
open(f2+"/AGENTS.md","w").write(re.sub(r"\*\*Branch policy[^\n]*\n(.*?\n)*?\n", "", ag, count=1))
rd = open(f2+"/README.md").read()
open(f2+"/README.md","w").write(rd.replace(" The work copy is always a fresh git clone from its origin (GitHub), never a copy of or a clone from the prior-art checkout.",""))
PYEOF
rm -f "$F2/comms/hooks/pre-push"
python3 - "$F2" <<'PYEOF'
import sys
f2=sys.argv[1]
p=f2+"/comms/session-start.sh"
s=open(p).read()
s=s.replace('prior-art refresh (fail-soft)','STALE-REFRESH')
open(p,'w').write(s)
PYEOF
# the fixture's comms/ tracks its protocol files; degrading them leaves the tree
# dirty — the tool's mixed-state gate REFUSES that (correctly: unrollbackable).
# Commit the degraded state first: the gate then sees a clean tree to fix.
git -C "$F2/comms" add -A && git -C "$F2/comms" -c user.name=tester -c user.email=t@l commit -qm "degraded fixture (proof)"
OUT2="$(report_of "$F2")"
echo "$OUT2" | grep -qF '[drift]' && ok "2a report flags drift" || bad "2a drift verdict" "$OUT2"
echo "$OUT2" | grep -qF 'missing' && ok "2b report flags missing hook" || bad "2b missing" "$OUT2"
# apply all
bash "$TOOL" "$F2" --apply > "$E/02-apply.out" 2>&1; RC=$?
[ "$RC" = 0 ] && ok "2c apply restored (rc 0)" || bad "2c apply rc" "rc=$RC $(tail -3 "$E/02-apply.out")"
grep -q "Branch policy" "$F2/AGENTS.md" && ok "2d AGENTS paragraph restored" || bad "2d agents" "clause still missing"
grep -qF 'The work copy is always a fresh `git clone` from the repo'"'"'s source (origin on GitHub)' "$F2/README.md" \
  && ok "2e README scaffold prose intact (tree lines live-owned by design)" \
  || bad "2e readme" "scaffold prose disturbed"
[ -x "$F2/comms/hooks/pre-push" ] && ok "2f hook re-stamped executable" || bad "2f hook" "missing after apply"
grep -q "reconcile committed\|nothing to commit" "$E/02-apply.out" \
  && ok "2g comms commit trail mentioned" || bad "2g commit" "no commit note in apply output"

echo "=== 3. operator-modified AGENTS: apply refuses; --force-section flips with .bak"
F3="$(build_scaffold mig-opmod)"
python3 - "$F3" <<'PYEOF'
import sys
f3=sys.argv[1]
p=f3+"/AGENTS.md"
s=open(p).read()
open(p,"w").write(s + "\n**Operator's own rule.** Hand-written paragraph.\n")
PYEOF
OUT3="$(report_of "$F3")"
echo "$OUT3" | grep -qF 'operator-modified' && ok "3a report flags operator-modified" || bad "3a verdict" "$OUT3"
bash "$TOOL" "$F3" --apply --only agents > "$E/03-refusal.out" 2>&1; RC3=$?
[ "$RC3" = 1 ] && ok "3b apply refuses operator-modified (rc 1)" || bad "3b rc" "$RC3"
grep -q "REFUSED" "$E/03-refusal.out" && ok "3c refusal names the hatch" || bad "3c text" "$(cat "$E/03-refusal.out")"
grep -qF "Operator's own rule" "$F3/AGENTS.md" && ok "3d live content untouched" || bad "3d" "live file changed on refusal"
ls "$F3"/AGENTS.md.bak-* >/dev/null 2>&1 || true
bash "$TOOL" "$F3" --apply --only agents --force-section > "$E/03-force.out" 2>&1; RC=$?
[ "$RC" = 0 ] && ok "3e --force-section applies (rc 0)" || bad "3e rc" "rc=$RC $(tail -2 "$E/03-force.out")"
ls "$F3"/AGENTS.md.bak-* >/dev/null 2>&1 && ok "3f .bak sibling written" || bad "3f bak" "missing"
echo "NOTE: force-apply preserves live heading + stamps scaffold body (operator para lives in .bak)" \
  > "$E/03-force-note.txt"

echo "=== 4. refusals: non-enclosing folder, unknown class"
mkdir -p /tmp/mig-notenc && rm -rf /tmp/mig-notenc/comms
bash "$TOOL" /tmp/mig-notenc > "$E/04-notenc.out" 2>&1; RC=$?
[ "$RC" = 1 ] && ok "4a non-enclosing refused rc 1" || bad "4a rc" "$RC"
grep -q "not an enclosing folder" "$E/04-notenc.out" && ok "4b refusal names the hatch" || bad "4b text" "$(cat "$E/04-notenc.out")"
bash "$TOOL" "$F1" --apply --only nonsense > "$E/04-badclass.out" 2>&1; RC=$?
[ "$RC" = 1 ] && ok "4c unknown class refused rc 1" || bad "4c rc" "$RC"
grep -q "unknown class" "$E/04-badclass.out" && ok "4d unknown class named" || bad "4d text" "$(cat "$E/04-badclass.out")"

echo "=== 5. unsealed-draft refusal (apply), report still works"
F5="$(build_scaffold mig-unsealed)"
python3 - "$F5" <<'PYEOF'
import sys, os, datetime
f5=sys.argv[1]
u=os.environ.get("USER","tester")
d=datetime.date.today().strftime("%Y%m%d")+"-99"
os.makedirs(f"{f5}/comms/{u}/{d}", exist_ok=True)
open(f"{f5}/comms/{u}/{d}/session-handoff.md","w").write("<!-- SEAL: delete this line -->\n## What this session did\nx\n")
PYEOF
bash "$TOOL" "$F5" > "$E/05-report.out" 2>&1; RC=$?
[ "$RC" = 0 ] && ok "5a report works with unsealed draft" || bad "5a rc" "$RC"
bash "$TOOL" "$F5" --apply --only agents > "$E/05-apply.out" 2>&1; RC=$?
[ "$RC" = 1 ] && ok "5b apply refuses mid-flight session (rc 1)" || bad "5b rc" "$RC"
grep -q "seal first" "$E/05-apply.out" && ok "5c refusal names seal hatch" || bad "5c text" "$(cat "$E/05-apply.out")"

echo "=== 6. dirs class stamps missing tree dirs"
F6="$(build_scaffold mig-dirs)"; rm -rf "$F6/prior-art" "$F6/work"
bash "$TOOL" "$F6" --apply --only dirs > "$E/06-dirs.out" 2>&1; RC=$?
[ "$RC" = 0 ] && ok "6a dirs apply rc 0" || bad "6a rc" "$RC"
[ -d "$F6/prior-art" ] && [ -d "$F6/work" ] && ok "6b missing dirs stamped" || bad "6b" "dirs still missing"

echo "=== 7. comms rollback commit: apply on stale folder produces a named commit in comms/"
F7="$(build_scaffold mig-rollback)"
python3 - "$F7" <<'PYEOF'
import sys
f7=sys.argv[1]
p=f7+"/comms/session-start.sh"
s=open(p).read()
s=s.replace('prior-art refresh (fail-soft)','STALE-REFRESH')
open(p,'w').write(s)
PYEOF
git -C "$F7/comms" add -A && git -C "$F7/comms" -c user.name=tester -c user.email=t@l commit -qm "degraded fixture (proof)"
before="$(git -C "$F7/comms" rev-parse --short HEAD 2>/dev/null)"
bash "$TOOL" "$F7" --apply --only comms-protocol > "$E/07-commit.out" 2>&1; RC=$?
after="$(git -C "$F7/comms" rev-parse --short HEAD 2>/dev/null)"
[ "$RC" = 0 ] && [ "$after" != "$before" ] \
  && ok "7a comms reconcile committed (${before} -> ${after})" \
  || bad "7a commit" "rc=$RC before=$before after=$after $(tail -2 "$E/07-commit.out")"
git -C "$F7/comms" log --format='%s' -1 | grep -q "scaffold@" \
  && ok "7b commit names scaffold source" || bad "7b" "no scaffold@ in message"
git -C "$F7/comms" show --stat HEAD | grep -q session-start.sh \
  && ok "7c commit carries the reconciled file" || bad "7c" "missing from commit"

echo
echo "== RESULTS: $PASS pass, $FAIL fail =="
[ "$FAIL" = 0 ]