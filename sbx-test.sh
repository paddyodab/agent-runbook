#!/bin/bash
# sbx-test.sh — prove "fresh microVM + agent-runbook install = working omp" in a
# real Docker Sandbox (sbx), not a normal docker container.
#
# Sibling of sandbox-test.sh:
#   sandbox-test.sh  →  docker run debian:stable-slim  (container proof)
#   sbx-test.sh      →  sbx create shell               (microVM proof)
#
# What it proves, in order:
#   1. an sbx shell sandbox with a writable host workspace + the runbook mounted :ro
#   2. install.sh --machine runs green in a virgin HOME inside the microVM
#   3. omp is installable per manifest hint and `omp --version` matches the pin
#   4. `omp --print` completes a real model round-trip when auth is present
#
# Usage: ./sbx-test.sh [--keep]   (--keep leaves the sandbox for debugging)
# Requires: sbx (Docker Sandboxes CLI), authenticated (`sbx diagnose` → Authentication OK).
# Optional: OMP_* env or .sandbox-auth for step 5 (same contract as sandbox-test.sh).
# mise is bootstrapped from GitHub releases (not mise.run) because the installer CDN
# 403s linux-arm64 from inside some sbx microVMs.
#
# Notes:
#   - The host workspace directory must already exist; sbx prompts interactively
#     otherwise. This script mkdir's under ~/sandbox-agents/.
#   - Uses a virgin HOME inside the sandbox (/tmp/runbook-virgin-home) so /home/agent
#     skill mounts from sbx itself do not pollute the install proof.

set -eu

KEEP="0"
[ "${1:-}" = "--keep" ] && KEEP="1"

HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="$HERE"
NAME="runbook-sbx-$$"
WS="${HOME}/sandbox-agents/${NAME}"

cleanup() {
  if [ "$KEEP" = "1" ]; then
    echo "keeping sandbox $NAME (sbx exec -it $NAME bash; workspace $WS)"
  else
    sbx rm -f "$NAME" >/dev/null 2>&1 || true
    rm -rf "$WS" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

if ! command -v sbx >/dev/null 2>&1; then
  echo "REFUSED: sbx not on PATH (install Docker Sandboxes: https://docs.docker.com/ai/sandboxes/install/)" >&2
  exit 1
fi

echo "== 0. preflight (sbx present + workspace dir)"
mkdir -p "$WS"
# Drop a breadcrumb so the writable workspace is not empty / easy to spot.
echo "sbx-test workspace for $NAME" >"$WS/README.sbx-test"

echo "== 1. creating sbx shell sandbox (runbook mounted :ro)"
sbx create --name "$NAME" --quiet shell "$WS" "${REPO}:ro" >/dev/null
sbx exec "$NAME" bash -c '
  set -eu
  echo "   microVM: $(uname -s) $(uname -m) kernel $(uname -r)"
  echo "   home default: $HOME  user: $(whoami)"
  if [ -f '"$REPO"'/install.sh ]; then
    echo "   runbook mount: '"$REPO"' OK"
  else
    echo "REFUSED: runbook not visible inside sandbox at '"$REPO"'" >&2
    exit 1
  fi
'

echo "== 2. bootstrap runtime deps (gh, glow) inside the microVM"
# Mirror sandbox-test.sh: herdr stays absent on purpose (optional-dep degrade path).
# Fresh sbx images often run apt on first boot — wait out the lists lock.
sbx exec "$NAME" bash -c '
  set -eu
  export DEBIAN_FRONTEND=noninteractive
  for i in $(seq 1 60); do
    if sudo apt-get update -qq >/dev/null 2>/tmp/apt-update.err; then
      break
    fi
    if grep -q "Could not get lock" /tmp/apt-update.err; then
      sleep 2
      continue
    fi
    cat /tmp/apt-update.err >&2
    exit 1
  done
  for i in $(seq 1 60); do
    if sudo apt-get install -y -qq git curl ca-certificates gh glow >/dev/null 2>/tmp/apt-install.err; then
      break
    fi
    if grep -q "Could not get lock" /tmp/apt-install.err; then
      sleep 2
      continue
    fi
    cat /tmp/apt-install.err >&2
    exit 1
  done
  echo "   ready: git $(git --version | awk "{print \$3}"), gh $(gh --version | head -1 | awk "{print \$3}"), glow $(glow --version 2>&1 | head -1)"
'

echo "== 3. install.sh --machine in a virgin HOME"
sbx exec "$NAME" bash -c '
  set -eu
  export HOME=/tmp/runbook-virgin-home
  export PATH="$HOME/.local/bin:/usr/local/bin:/usr/bin:/bin"
  mkdir -p "$HOME/.local/bin"
  cd '"$REPO"'
  ./install.sh --machine 2>&1 | tail -5
  test -L "$HOME/.omp/agent/skills/bro-mode" && echo "   bro-mode symlink: OK"
  test -L "$HOME/.omp/agent/skills/eng-playbooks" && echo "   eng-playbooks symlink: OK"
  test -L "$HOME/.omp/agent/skills/fan-out-lanes" && echo "   fan-out-lanes symlink: OK"
  test -L "$HOME/.omp/agent/skills/turborepo" && echo "   turborepo symlink: OK"
  grep -q "BLOCK:BEGIN:agent-runbook" "$HOME/.omp/agent/AGENTS.md" && echo "   AGENTS.md block: OK"
  test -x "$HOME/.local/bin/new-enclosing-folder.sh" && echo "   scaffold: OK"
  ./install.sh --doctor --machine | head -5
'

echo "== 4. omp per manifest hint (mise, pinned 18.2.0)"
# Prefer GitHub release tarball over https://mise.run — the installer CDN
# returns 403 for linux-arm64 from inside some sbx microVMs.
sbx exec "$NAME" bash -c '
  set -eu
  export HOME=/tmp/runbook-virgin-home
  mkdir -p "$HOME/.local/bin"
  export PATH="$HOME/.local/share/mise/shims:$HOME/.local/bin:/usr/local/bin:/usr/bin:/bin"
  if ! command -v mise >/dev/null 2>&1; then
    ARCH="$(uname -m)"
    case "$ARCH" in
      aarch64|arm64) MISE_ARCH=linux-arm64 ;;
      x86_64|amd64)  MISE_ARCH=linux-x64 ;;
      *) echo "REFUSED: unsupported arch $ARCH for mise bootstrap" >&2; exit 1 ;;
    esac
    TAG="$(curl -fsSLI -o /dev/null -w "%{url_effective}" https://github.com/jdx/mise/releases/latest | sed "s#.*/##")"
    curl -fsSL "https://github.com/jdx/mise/releases/download/${TAG}/mise-${TAG}-${MISE_ARCH}.tar.gz" -o /tmp/mise.tgz
    tar -xzf /tmp/mise.tgz -C /tmp
    install -m 755 /tmp/mise/bin/mise "$HOME/.local/bin/mise"
  fi
  mise use -g github:can1357/oh-my-pi@18.2.0 >/dev/null
  export PATH="$HOME/.local/share/mise/shims:$PATH"
  V="$(omp --version | awk -F/ "{print \$2}")"
  echo "   omp installed: $V (pin 18.2.0)"
  [ "$V" = "18.2.0" ]
'

echo "== 5. omp --print round-trip in the virgin HOME"
sbx exec -e OMP_AUTH -e OMP_API_KEY -e OMP_MODEL "$NAME" bash -c '
  set -eu
  export HOME=/tmp/runbook-virgin-home
  export PATH="$HOME/.local/share/mise/shims:$HOME/.local/bin:/usr/local/bin:/usr/bin:/bin"
  if [ -z "${OMP_AUTH:-}" ] && [ -z "${OMP_API_KEY:-}" ] && [ ! -f '"$REPO"'/.sandbox-auth ]; then
    echo "   SKIP (no OMP_AUTH / OMP_API_KEY / .sandbox-auth): model round-trip not provable"
    exit 0
  fi
  if [ -f '"$REPO"'/.sandbox-auth ] && [ -z "${OMP_AUTH:-}" ]; then
    # shellcheck disable=SC1090
    . '"$REPO"'/.sandbox-auth
  fi
  OUT="$(omp --print "Reply with exactly: SBX_OK")"
  echo "   omp --print said: $OUT"
  echo "$OUT" | grep -q "SBX_OK"
'

echo "== PASS: sbx microVM bootstrap proven end to end (steps 1-4; 5 with auth present)"
