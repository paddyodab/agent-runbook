#!/usr/bin/env bash
# artifacts-sync-01 obligations 01/02/04: local roundtrip, mirror fences + --force
# victim accounting, refusal hatches. Structured JSON evidence into .evidence/.
# Disposable fixtures under /tmp; the wrapper under test is $REPO/artifacts-sync.
set -u
REPO="$(cd "$(dirname "$0")/../.." && pwd)"
SYNC="$REPO/artifacts-sync"
OUT="$REPO/.evidence/artifacts-sync-01"
RUN="$(mktemp -d /tmp/artifactsync-proof.XXXXXX)"
trap 'rm -rf "$RUN"' EXIT
PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); echo "PASS: $1"; }
bad() { FAIL=$((FAIL+1)); echo "FAIL: $1"; }
J="python3"
json_esc() { $J -c 'import json,sys; print(json.dumps(sys.stdin.read()))'; }

# ============ obligation 01: two nodes + target roundtrip, subdirs + spaces ========
FIX="$RUN/01"; mkdir -p "$FIX/nodeA/data" "$FIX/target" "$FIX/nodeB"
printf 'alpha\n' > "$FIX/nodeA/data/top file.txt"
mkdir -p "$FIX/nodeA/data/nested dir/deeper"
printf 'beta\n' > "$FIX/nodeA/data/nested dir/deeper/leaf two.txt"
printf 'gamma\n' > "$FIX/nodeA/data/ugly name (v2).md"

"$SYNC" remote "$FIX/target" "$FIX/nodeA/data" >"$RUN/01-wire.out" 2>&1 \
  && ok "01 wire: remote wires target (trailing slash enforced)" \
  || bad "01 wire refused"
grep -q "normalized" "$RUN/01-wire.out" && ok "01 wire: trailing slash normalized loudly" || bad "01 wire: no normalization note"
"$SYNC" export "$FIX/nodeA/data" >"$RUN/01-export.out" 2>&1 \
  && ok "01 export: nodeA -> target" || bad "01 export failed"
"$SYNC" import --target "$FIX/target/" "$FIX/nodeB/data" >"$RUN/01-import.out" 2>&1 \
  && ok "01 import: one-shot target -> nodeB" || bad "01 import failed"
if diff -r --exclude=.sync-target "$FIX/nodeA/data" "$FIX/nodeB/data" >/dev/null 2>&1; then
  ok "01 converge: nodeA == nodeB (incl. 'nested dir', spaces)"
else
  bad "01 converge: trees differ"
fi
# wire file absent on nodeB (one-shot import shouldn't write one)
[ ! -f "$FIX/nodeB/data/.sync-target" ] && ok "01 import: one-shot writes no wire file" || bad "01 import wrote a wire file"
# content hashes
"$SYNC" status "$FIX/nodeA/data" > "$RUN/01-status.out" 2>&1
grep -q "name parity: CLEAN" "$RUN/01-status.out" && ok "01 status: CLEAN after export" || bad "01 status not CLEAN"

# ============ obligation 02: fences + --force victim accounting =====================
FIX="$RUN/02"; mkdir -p "$FIX/nodeA/data" "$FIX/target" "$FIX/nodeB/data"
printf 'a\n' > "$FIX/nodeA/data/keep.txt"
printf 'b\n' > "$FIX/nodeA/data/victim.txt"
printf 'shared\n' > "$FIX/nodeA/data/shared.txt"
"$SYNC" remote "$FIX/target" "$FIX/nodeA/data" >/dev/null 2>&1
"$SYNC" export "$FIX/nodeA/data" >/dev/null 2>&1
"$SYNC" import --target "$FIX/target/" "$FIX/nodeB/data" >/dev/null 2>&1
# nodeA deletes victim.txt (nodeB keeps it)
rm "$FIX/nodeA/data/victim.txt"
"$SYNC" export "$FIX/nodeA/data" > "$RUN/02-fence.out" 2>&1
RC=$?
[ $RC -eq 1 ] && ok "02 fence: export refuses (rc=1) on target-victim" || bad "02 fence rc=$RC"
grep -q "fence fired; nothing moved" "$RUN/02-fence.out" && ok "02 fence: 'nothing moved' declared" || bad "02 fence: no nothing-moved line"
grep -q -- "--force victim.txt export" "$RUN/02-fence.out" && ok "02 fence: recipe names the victim + exact command" || bad "02 fence recipe malformed"
cmp -s "$FIX/target/victim.txt" <(printf 'b\n') && ok "02 fence: target untouched (victim still there)" || bad "02 fence: target was mutated"
# nodeB's copy diverges -> its export fences on a DIFFERENT victim (dir-side)
rm "$FIX/nodeB/data/shared.txt"
"$SYNC" export "$FIX/nodeB/data" --target "$FIX/target/" > "$RUN/02-fence-b.out" 2>&1
grep -q "shared.txt" "$RUN/02-fence-b.out" && ok "02 fence: dir-side victim named too (per-direction)" || bad "02 fence dir-side missing"
# reconcile via the printed recipe, THEN test overwrite semantics on a clean field
"$SYNC" --force shared.txt export "$FIX/nodeB/data" --target "$FIX/target/" >/dev/null 2>&1 \
  && [ ! -f "$FIX/target/shared.txt" ] && ok "02 fence-b: own recipe reconciles dir-side victim" || bad "02 fence-b recipe failed"
printf 'changed\n' > "$FIX/nodeB/data/keep.txt"
"$SYNC" export "$FIX/nodeB/data" --target "$FIX/target/" >> "$RUN/02-overwrite.out" 2>&1
cmp -s "$FIX/target/keep.txt" <(printf 'changed\n') && ok "02 semantics: same-name-diff-content overwrites (not a fence)" || bad "02 overwrite semantics broke"
# --force no names
"$SYNC" --force export "$FIX/nodeB/data" --target "$FIX/target/" > "$RUN/02-noforcednames.out" 2>&1
[ $? -eq 1 ] && grep -q "needs at least one name" "$RUN/02-noforcednames.out" \
  && ok "02 force: zero names refuses" || bad "02 force zero-names"
# --force unknown name
"$SYNC" --force typo.txt export "$FIX/nodeB/data" --target "$FIX/target/" > "$RUN/02-unknown.out" 2>&1
[ $? -eq 1 ] && grep -q "no such name" "$RUN/02-unknown.out" \
  && ok "02 force: unknown name refuses (typo protection)" || bad "02 force unknown-name"
# the real recipe from nodeA's fence: mirror up, deleting victim from target
"$SYNC" --force victim.txt export "$FIX/nodeA/data" > "$RUN/02-force.out" 2>&1 \
  && ok "02 force: victims-only run completes" || bad "02 force failed"
[ ! -f "$FIX/target/victim.txt" ] && ok "02 force: victim deleted at target" || bad "02 force: victim survived"
cmp -s "$FIX/target/keep.txt" <(printf 'changed\n') && ok "02 force: non-victims untouched (nodeB's overwrite pre-force stands; scoped, exact)" || bad "02 force: scope leak"
[ -f "$FIX/target/shared.txt" ] || [ -f "$FIX/nodeA/data/shared.txt" ] && ok "02 force: shared side untouched" || bad "02 force: shared lost"
# re-run mirror now clean
"$SYNC" export "$FIX/nodeA/data" > "$RUN/02-export2.out" 2>&1 && ok "02 export: clean after reconcile" || bad "02 post-force export failed"
"$SYNC" import --target "$FIX/target/" "$FIX/nodeB/data" >/dev/null 2>&1
# import-direction fence: nodeB creates a local-only file
printf 'localonly\n' > "$FIX/nodeB/data/localonly.txt"
# TWO victims now fence nodeB's imports: localonly.txt (this block) AND victim.txt
# (nodeA's reconciliation deleted it at target; nodeB still carries it) — the
# refusal must account for both; recipes paste clean.
"$SYNC" import --target "$FIX/target/" "$FIX/nodeB/data" > "$RUN/02-import-fence.out" 2>&1
grep -q "localonly.txt" "$RUN/02-import-fence.out" \
  && grep -q "or lift the local" "$RUN/02-import-fence.out" \
  && ok "02 import fence: BOTH recipes offered (delete-local vs lift)" || bad "02 import fence recipes"
grep -q "victim.txt" "$RUN/02-import-fence.out" \
  && ok "02 fence accounting: nodeB's stale victim.txt named in the same refusal" || bad "02 victim accounting"
"$SYNC" --force localonly.txt victim.txt import --target "$FIX/target/" "$FIX/nodeB/data" >/dev/null 2>&1 \
  && ! [ -f "$FIX/nodeB/data/localonly.txt" ] && ! [ -f "$FIX/nodeB/data/victim.txt" ] \
  && ! [ -f "$FIX/target/localonly.txt" ] \
  && ok "02 import fence: target-canonical recipe deletes ONLY the local copies (target unchanged)" || bad "02 import delete path"
"$SYNC" import --target "$FIX/target/" "$FIX/nodeB/data" >/dev/null 2>&1 \
  && "$SYNC" status "$FIX/nodeB/data" --target "$FIX/target/" | grep -q "CLEAN" \
  && ok "02 import: clean import after reconciliation" || bad "02 import post-recipe clean"

# ============ obligation 04: refusal hatches ========================================
FIX="$RUN/04"; mkdir -p "$FIX/arts"
# unwired export/import/status (fresh dir, nothing wired yet, no env)
for cmd in export import status; do
  OUT4="$RUN/04-unwired-$cmd.out"
  "$SYNC" $cmd "$FIX/arts" > "$OUT4" 2>&1
  RC=$?
  if [ "$cmd" = "status" ]; then
    [ $RC -eq 0 ] && grep -q "UNWIRED" "$OUT4" && grep -q "artifacts-sync remote" "$OUT4" \
      && ok "04 status: UNWIRED is a state, names the wire command" || bad "04 status unwired"
  else
    [ $RC -eq 1 ] && grep -q "artifacts-sync remote" "$OUT4" \
      && ok "04 $cmd: unwired refusal names the remote hatch" || bad "04 $cmd unwired rc=$RC"
  fi
done
# env-var target honored
export ARTIFACTS_SYNC_TARGET="$FIX/envtarget"
mkdir -p "$FIX/envtarget"
printf 'e\n' > "$FIX/arts/e.txt"
"$SYNC" export "$FIX/arts" > "$RUN/04-env.out" 2>&1 \
  && [ -f "$FIX/envtarget/e.txt" ] && ok "04 env: ARTIFACTS_SYNC_TARGET honored" || bad "04 env target"
unset ARTIFACTS_SYNC_TARGET
# bad scheme
"$SYNC" remote ftp://nope/ "$FIX/arts" > "$RUN/04-scheme.out" 2>&1
[ $? -eq 1 ] && grep -q "unsupported scheme" "$RUN/04-scheme.out" \
  && ok "04 scheme: ftp:// refused with the corrected form" || bad "04 scheme"
# bare bucket (fresh dir — nothing wired before this point). NOTE: on a box
# without the aws CLI the aws-hatch fires first (equally a refusal); the
# prefix-ambiguity refusal itself is asserted in the moto flow (obligation 03)
# where the CLI exists.
mkdir -p "$FIX/arts2"
"$SYNC" remote s3://justabucket "$FIX/arts2" > "$RUN/04-bare.out" 2>&1
[ $? -eq 1 ] && { grep -q "ambiguous" "$RUN/04-bare.out" \
  && ok "04 bare bucket: refused (prefix boundary ambiguity)" \
  || grep -q "aws CLI not on PATH" "$RUN/04-bare.out" \
  && ok "04 bare bucket: refused via aws-hatch (ambiguity re-asserted in 03)"; } || bad "04 bare bucket"
# re-wire refusal + forced re-wire (fresh dir)
mkdir -p "$FIX/arts3"
"$SYNC" remote "$FIX/envtarget/" "$FIX/arts3" >/dev/null 2>&1
"$SYNC" remote "$RUN/04/other-place/" "$FIX/arts3" > "$RUN/04-rewire.out" 2>&1
[ $? -eq 1 ] && grep -q "re-wiring is deliberate" "$RUN/04-rewire.out" \
  && ok "04 rewire: different-uri refused, names the deliberate command" || bad "04 rewire"
"$SYNC" remote --force "$RUN/04/other-place/" "$FIX/arts3" > "$RUN/04-forcewire.out" 2>&1 \
  && grep -q "nothing deleted at the old target" "$RUN/04-forcewire.out" \
  && ok "04 rewire --force: allowed, LOUD, unwires only" || bad "04 force wire"
# electivity
mkdir -p "$FIX/prior-art" "$FIX/comms" "$FIX/work"
"$SYNC" export "$FIX/prior-art" > "$RUN/04-elect1.out" 2>&1; R1=$?
"$SYNC" export "$FIX/comms" > "$RUN/04-elect2.out" 2>&1; R2=$?
"$SYNC" export "$FIX/work" > "$RUN/04-elect3.out" 2>&1; R3=$?
[ $R1 -eq 1 ] && [ $R2 -eq 1 ] && [ $R3 -eq 1 ] \
  && grep -q "read-only reference" "$RUN/04-elect1.out" \
  && grep -q "comms-sync" "$RUN/04-elect2.out" \
  && ok "04 electivity: prior-art/comms/work refused, each with the tier reason" || bad "04 electivity"

echo "=== obligation 01/02/04: $PASS pass, $FAIL fail"
[ $FAIL -eq 0 ]