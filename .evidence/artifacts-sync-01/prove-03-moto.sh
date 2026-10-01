#!/usr/bin/env bash
# artifacts-sync-01 obligation 03: S3 API semantics over a REAL aws-s3-API server
# (moto in docker — no real credentials needed). The wrapper's actual s3 plumbing
# end-to-end: wire (trailing-slash verify), export, import, fence on s3-side
# delete, --force reconciliation, prefix-boundary isolation, bare-bucket
# ambiguity refusal (aws present), env-target mode. Fixtures live INSIDE the
# node container (root-owned dirs on the host are avoided entirely).
set -u
REPO="$(cd "$(dirname "$0")/../.." && pwd)"
PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); echo "PASS: $1"; }
bad() { FAIL=$((FAIL+1)); echo "FAIL: $1"; }

# node image: python slim + aws CLI (host may lack aws entirely)
if ! docker image inspect artifactsync-awsnode >/dev/null 2>&1; then
  HERE="$(mktemp -d)"
  printf 'FROM python:3.12-slim\nRUN pip install --no-cache-dir awscli\n' > "$HERE/Dockerfile"
  docker build -q -t artifactsync-awsnode "$HERE" >/dev/null && rm -rf "$HERE"
fi
docker image inspect artifactsync-awsnode >/dev/null 2>&1 || { echo "FAIL: node image"; exit 1; }

docker rm -f artifacts-sync-moto >/dev/null 2>&1
docker run -d --rm --name artifacts-sync-moto -p 127.0.0.1:15000:5000 motoserver/moto:5.0.26 >/dev/null
UP=0
while [ $UP -lt 30 ]; do curl -sf http://127.0.0.1:15000/ >/dev/null 2>&1 && break; UP=$((UP+1)); sleep 1; done
[ $UP -lt 30 ] || { echo "FAIL: moto never ready"; exit 1; }
echo "moto up (${UP}s)"

# NODE = one bash inside the fixture container (its own / fixture tree per call
# would die with --rm; so the fixture container is a long-lived name).
docker rm -f asm-node >/dev/null 2>&1
docker run -d --name asm-node --network host \
  -e AWS_ACCESS_KEY_ID=test -e AWS_SECRET_ACCESS_KEY=test \
  -e AWS_DEFAULT_REGION=us-east-1 -e AWS_ENDPOINT_URL=http://127.0.0.1:15000 \
  -v "$REPO":/repo:ro -w /fixture artifactsync-awsnode sleep 600 >/dev/null
docker exec asm-node mkdir -p /fixture
NODE() { docker exec asm-node bash -c "$1"; }

NODE 'aws s3 mb s3://bkt --endpoint-url $AWS_ENDPOINT_URL' >/dev/null 2>&1 \
  && ok "03 moto: bucket created (real S3 API)" || bad "03 moto bucket"

# nodeA fixture: subdirs + spaces
NODE 'mkdir -p nodeA/data "nodeA/data/sub dir" \
  && printf "alpha\n" > "nodeA/data/top file.txt" \
  && printf "beta\n"  > "nodeA/data/sub dir/leaf with space.txt"'

NODE '/repo/artifacts-sync remote s3://bkt/prefix/ nodeA/data > 03-wire.out 2>&1; echo rc=$?' | grep -q "rc=0" \
  && ok "03 wire: s3://bkt/prefix/ verified via real ListObjects" || bad "03 wire"
NODE 'cat nodeA/data/.sync-target' | grep -qx "s3://bkt/prefix/" \
  && ok "03 wire: exact URI stored verbatim (trailing slash, no endpoint pollution)" || bad "03 wire file"

NODE '/repo/artifacts-sync export nodeA/data > 03-export.out 2>&1; echo rc=$?' | grep -q "rc=0" \
  && ok "03 export: leaf files to the s3 prefix" || bad "03 export"
NODE 'aws s3 ls s3://bkt/prefix/ --recursive --endpoint-url $AWS_ENDPOINT_URL | grep -c "leaf with space.txt"' | grep -q 1 \
  && ok "03 s3-list: wrapper parses keys with spaces correctly" || bad "03 s3-list parse"

# import into nodeB
NODE 'mkdir -p nodeB && /repo/artifacts-sync import --target s3://bkt/prefix/ nodeB/data > 03-import.out 2>&1; echo rc=$?' | grep -q "rc=0" \
  && ok "03 import: one-shot s3 -> nodeB" || bad "03 import"
NODE 'diff -r --exclude .sync-target nodeA/data nodeB/data && echo CONVERGED' | grep -q CONVERGED \
  && ok "03 converge: nodeA == nodeB over the S3 round trip" || bad "03 converge"

# fence: delete an object on s3 directly; ALSO nodeB gains a new file -> both-side accounting
NODE 'aws s3 rm "s3://bkt/prefix/top file.txt" --endpoint-url $AWS_ENDPOINT_URL >/dev/null'
NODE 'printf "new\n" > nodeB/data/anewfile.txt'
NODE '/repo/artifacts-sync import --target s3://bkt/prefix/ nodeB/data > 03-fence.out 2>&1; echo rc=$?' | grep -q "rc=1" \
  && ok "03 fence: s3-side deletion refuses the import" || bad "03 fence rc"
NODE 'grep -q "top file.txt" 03-fence.out' \
  && ok "03 fence: s3-deleted victim named (quote-safe)" || bad "03 victim naming"
NODE 'grep -q "anewfile.txt" 03-fence.out' \
  && ok "03 fence: dir-side new file in the SAME refusal (both-side accounting)" || bad "03 dir-side accounting"
NODE 'grep -q -- "--force .* --target s3://bkt/prefix/" 03-fence.out' \
  && ok "03 fence: recipe carries --target (paste-clean from a one-shot node)" || bad "03 recipe paste-clean"

# --force export (lift anewfile) then --force import (accept the s3 delete)
NODE '/repo/artifacts-sync --force anewfile.txt export --target s3://bkt/prefix/ nodeB/data > 03-force-out.out 2>&1; echo rc=$?' | grep -q "rc=0" \
  && ok "03 force: scoped export to s3" || bad "03 force export"
NODE 'aws s3 ls s3://bkt/prefix/ --recursive --endpoint-url $AWS_ENDPOINT_URL | grep -q anewfile.txt' \
  && ok "03 force: new file really on s3" || bad "03 force upload"
NODE 'cmp -s "nodeA/data/sub dir/leaf with space.txt" "nodeB/data/sub dir/leaf with space.txt" && echo SAME' | grep -q SAME \
  && ok "03 survivor: spaces file untouched by the scoped force" || bad "03 survivor"
NODE '/repo/artifacts-sync --force "top file.txt" import --target s3://bkt/prefix/ nodeB/data >/dev/null 2>&1; [ ! -f "nodeB/data/top file.txt" ] && echo GONE' | grep -q GONE \
  && ok "03 force: s3-canonical delete mirrored down locally" || bad "03 force delete"

# prefix boundary: a peer prefix in the SAME bucket is never touched
NODE 'printf "peer\n" > peer.txt && aws s3 cp peer.txt s3://bkt/other-prefix/peer.txt --endpoint-url $AWS_ENDPOINT_URL >/dev/null'
B=$(NODE 'aws s3 ls s3://bkt/other-prefix/ --recursive --endpoint-url $AWS_ENDPOINT_URL | grep -c peer.txt')
NODE '/repo/artifacts-sync export nodeA/data >/dev/null 2>&1; echo rc=$?' | grep -q "rc=0"
A=$(NODE 'aws s3 ls s3://bkt/other-prefix/ --recursive --endpoint-url $AWS_ENDPOINT_URL | grep -c peer.txt')
[ "$B" = "$A" ] && [ "$A" = "1" ] \
  && ok "03 prefix boundary: peer-prefix object untouched by the wired prefix's sync" || bad "03 prefix boundary ($B->$A)"

# bare-bucket ambiguity (04's re-assertion, now where aws EXISTS) — fresh dir
NODE 'mkdir -p freshA && /repo/artifacts-sync remote s3://justabucket freshA/nd > 03-bare.out 2>&1; echo rc=$?' | grep -q "rc=1" \
  && ok "03 bare bucket: refused (aws present, so ambiguity is the firing fence)" || bad "03 bare bucket"
NODE 'grep -q ambiguous 03-bare.out' \
  && ok "03 bare bucket: refusal names the trailing-slash re-wire" || bad "03 bare naming"

# env-target mode in s3 — on a CONVERGED nodeB (any divergence would legitimately
# fence before the env resolution is even under test); reconcile via the recipes first
NODE '/repo/artifacts-sync --force anewfile.txt import --target s3://bkt/prefix/ nodeB/data >/dev/null 2>&1; echo recon=$?' | grep -q "recon=0" \
  && ok "03 pre-env: nodeB reconciled via its own recipe" || true
NODE 'ARTIFACTS_SYNC_TARGET=s3://bkt/prefix/ /repo/artifacts-sync import nodeB/data > 03-env.out 2>&1; echo rc=$?' | grep -q "rc=0" \
  && ok "03 env: ARTIFACTS_SYNC_TARGET drives s3 mode" || {
  docker exec asm-node sh -c 'tail -4 /fixture/03-env.out' 2>/dev/null | sed 's/^/    /'
  bad "03 env"
}

docker rm -f asm-node artifacts-sync-moto >/dev/null 2>&1
echo "=== obligation 03: $PASS pass, $FAIL fail"
[ $FAIL -eq 0 ]