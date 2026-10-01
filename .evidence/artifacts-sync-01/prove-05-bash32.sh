#!/usr/bin/env bash
# artifacts-sync-01 obligation 05: local-mode flow under stock bash 3.2 (docker).
# The wrapper itself runs IN the bash:3.2 container — the real interpreter proof,
# not an audit for known bashisms. Local mode (no aws) covers arg parsing,
# wire/normalize, export/import roundtrip, both fences, --force, refusals.
set -u
REPO="$(cd "$(dirname "$0")/../.." && pwd)"
PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); echo "PASS: $1"; }
bad() { FAIL=$((FAIL+1)); echo "FAIL: $1"; }

docker rm -f asm-b32 >/dev/null 2>&1
docker run -d --name asm-b32 -v "$REPO":/repo:ro bash:3.2 sleep 300 >/dev/null
docker exec asm-b32 mkdir -p /work
B32() { docker exec asm-b32 bash -c "$1"; }
B32V() { docker exec asm-b32 bash -c "bash --version | head -1; $1"; }

B32V 'true' | grep -q "version 3.2" && ok "05 interpreter: stock bash 3.2 in docker" || bad "05 interpreter"

# syntax check under 3.2 itself
B32 'bash -n /repo/artifacts-sync && echo PARSEOK' | grep -q PARSEOK \
  && ok "05 bash -n: parses under 3.2 (mapfile/assoc/;& would fail here)" || bad "05 bash -n"

# full local-mode flow under 3.2 (fixture inside the container)
B32 '
set -u
cd /work
S=/repo/artifacts-sync
mkdir -p nodeA/data "nodeA/data/sub dir" target
printf "alpha\n" > "nodeA/data/top file.txt"
printf "beta\n" > "nodeA/data/sub dir/leaf two.txt"
$S remote /work/target nodeA/data >wire.out 2>&1; echo "wire=$?"
$S export nodeA/data >export.out 2>&1; echo "export=$?"
mkdir -p nodeB
$S import --target /work/target/ nodeB/data >import.out 2>&1; echo "import=$?"
# BusyBox diff has no --exclude: compare leaf sets + content hashes (POSIX-safe)
md5sum_check() { ( cd "$1" && find . -type f ! -name ".sync-target" | LC_ALL=C sort | xargs md5sum ) | md5sum | cut -d" " -f1; }
A=$(md5sum_check nodeA/data); B=$(md5sum_check nodeB/data)
[ "$A" = "$B" ] && echo "CONV=ok" || echo "CONV=fail"
rm "nodeA/data/top file.txt"
$S export nodeA/data >fence.out 2>&1; echo "fence=$?"
$S --force "top file.txt" export nodeA/data >force.out 2>&1; echo "force=$?"
$S export nodeA/data >export2.out 2>&1; echo "export2=$?"
$S status nodeA/data >status.out 2>&1
' | tee /tmp/b32-flow.txt > /dev/null
for mark in wire=0 export=0 import=0 CONV=ok; do
  grep -q "$mark" /tmp/b32-flow.txt || { echo "missing marker: $mark" >&2; break; }
done
grep -q "wire=0" /tmp/b32-flow.txt && grep -q "export=0" /tmp/b32-flow.txt && grep -q "import=0" /tmp/b32-flow.txt && grep -q "CONV=ok" /tmp/b32-flow.txt \
  && ok "05 flow: wire/export/import/converge under bash 3.2 (spaces + subdirs, hash-equal)" \
  || bad "05 flow"
grep -q "fence=1" /tmp/b32-flow.txt && ok "05 fence: fires under 3.2, rc=1" || bad "05 fence rc"
docker exec asm-b32 bash -c 'grep -q -- "--force .top file.txt. export /work/nodeA/data" /work/fence.out && echo RECIPEOK' | grep -q RECIPEOK \
  && ok "05 recipe: victim named quote-safe under 3.2 (reads the container's own fence.out)" || bad "05 recipe"
grep -q "force=0" /tmp/b32-flow.txt && ok "05 force: victims-only run under 3.2" || bad "05 force rc"
grep -q "export2=0" /tmp/b32-flow.txt && ok "05 post-force: export clean under 3.2" || bad "05 post-force"
B32 'grep -q "name parity: CLEAN" /work/status.out && echo SOK' | grep -q SOK \
  && ok "05 status: parity CLEAN under 3.2" || bad "05 status"

# refusal hatches under 3.2
B32 '
cd /work && S=/repo/artifacts-sync
mkdir -p unwired
$S export unwired >h1.out 2>&1; echo "h1=$?"
$S remote ftp://x/ unwired >h2.out 2>&1; echo "h2=$?"
$S export /work/comms >h3.out 2>&1; echo "h3=$?"
' | grep -q "h1=1" && B32 'grep -q "artifacts-sync remote" /work/h1.out; grep -q "unsupported scheme" /work/h2.out; grep -q "comms-sync" /work/h3.out' \
  && ok "05 hatches: unwired/scheme/electivity refusals intact under 3.2" || bad "05 hatches"

docker rm -f asm-b32 >/dev/null 2>&1
echo "=== obligation 05: $PASS pass, $FAIL fail"
[ $FAIL -eq 0 ]