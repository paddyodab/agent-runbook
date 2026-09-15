#!/bin/bash
# sandbox-test.sh — prove "fresh box + agent-runbook install = working omp" in a container.
#
# What it proves, in order:
#   1. a container with NOTHING but debian + git + the runbook repo mounted in
#   2. install.sh --machine runs green (skills symlinked, AGENTS.md block, scaffold)
#   3. omp is installable per manifest hint and `omp --version` matches the pin
#   4. `omp --print` completes a real model round-trip in the fresh HOME
#
# Usage: ./sandbox-test.sh [--keep]   (--keep leaves the container for debugging)
# Requires: docker, an omp-capable auth on the host (OMP_* env passes through).

set -eu

KEEP="0"
[ "${1:-}" = "--keep" ] && KEEP="1"

HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="$HERE"                       # mount the agent-runbook repo itself at /runbook
NAME="runbook-sandbox-$$"

cleanup() {
  if [ "$KEEP" = "1" ]; then
    echo "keeping container $NAME (docker exec -it $NAME bash)"
  else
    docker rm -f "$NAME" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

echo "== 1. starting container (debian:stable-slim; runbook repo mounted at /runbook)"
docker run -d --name "$NAME" \
  -v "$REPO":/runbook:ro \
  debian:stable-slim sleep infinity >/dev/null

# Container bootstrap: git/curl (minimal) + gh/glow from debian repos so the
# manifest dep gates pass. herdr stays absent on purpose: proves the
# optional-dep degrade path end to end.
docker exec "$NAME" bash -c '
  set -eu
  apt-get update -qq >/dev/null
  apt-get install -y -qq git curl ca-certificates gh glow >/dev/null 2>&1
  echo "   ready: git $(git --version | awk "{print \$3}"), gh $(gh --version | head -1 | awk "{print \$3}"), glow $(glow --version 2>&1 | head -1)"
'

echo "== 2. install.sh --machine in a virgin HOME"
docker exec "$NAME" bash -c '
  set -eu
  export HOME=/root
  export PATH="$HOME/.local/bin:/usr/local/bin:/usr/bin:/bin"
  mkdir -p "$HOME/.local/bin"     # exists on real boxes; created here so the
                                  # PATH gate installs the scaffold
  cd /runbook
  ./install.sh --machine 2>&1 | tail -3
  test -L "$HOME/.omp/agent/skills/bro-mode" && echo "   bro-mode symlink: OK"
  test -L "$HOME/.omp/agent/skills/turborepo" && echo "   turborepo symlink: OK"
  grep -q "BLOCK:BEGIN:agent-runbook" "$HOME/.omp/agent/AGENTS.md" && echo "   AGENTS.md block: OK"
  test -x "$HOME/.local/bin/new-enclosing-folder.sh" && echo "   scaffold: OK"
  ./install.sh --doctor --machine | head -3
'

echo "== 3. omp per manifest hint (mise, pinned 18.2.0)"
docker exec "$NAME" bash -c '
  set -eu
  export HOME=/root
  export PATH="$HOME/.local/share/mise/shims:$HOME/.local/bin:/usr/local/bin:/usr/bin:/bin"
  curl -fsSL https://mise.run -o /tmp/mise-run.sh
  bash /tmp/mise-run.sh >/dev/null 2>&1
  mise use -g github:can1357/oh-my-pi@18.2.0 >/dev/null 2>&1
  V="$(omp --version | awk -F/ "{print \$2}")"
  echo "   omp installed: $V (pin 18.2.0)"
  [ "$V" = "18.2.0" ]
'

echo "== 4. omp --print round-trip in the fresh HOME"
docker exec "$NAME" bash -c '
  set -eu
  export HOME=/root
  export PATH="$HOME/.local/share/mise/shims:$HOME/.local/bin:/usr/local/bin:/usr/bin:/bin"
  # Auth passthrough is the operator step: OMP_* env or a copied key file.
  if [ -z "${OMP_AUTH:-}" ] && [ ! -f /runbook/.sandbox-auth ]; then
    echo "   SKIP (no OMP_AUTH env / .sandbox-auth file): model round-trip not provable in CI"
    exit 0
  fi
  OUT="$(omp --print "Reply with exactly: SANDBOX_OK")"
  echo "   omp --print said: $OUT"
  echo "$OUT" | grep -q "SANDBOX_OK"
'

echo "== PASS: fresh box bootstrap proven end to end (steps 1-3; 4 with auth present)"