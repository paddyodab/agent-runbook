#!/bin/bash
# fresh-box.sh — the one-command box-day bootstrap: everything a bare box needs
# BEFORE `install.sh --machine` can run. Idempotent; re-run is a no-op.
#
#   fresh-box.sh            provision (apt deps, workspace, runbook clone,
#                           ~/.local/bin + PATH, omp, herdr)
#   fresh-box.sh --check    the honest bill: what's missing, ZERO mutation
#   fresh-box.sh --no-omp --no-herdr
#                           skip the two installer steps (flags combine)
#
# Covers the box-day friction (EC2 ssm-user history, 2026-09-29): gh isn't baked
# into bare Ubuntu, ~/Documents/GitHub and ~/.local/bin don't exist, ~/.local/bin
# isn't on PATH — each done by hand Friday, each repeated for the next user.
# Interactive steps (gh auth login, omp login, install.sh --machine) are PRINTED,
# never run — the runbook never answers prompts.
#
# Ordering matters: deps → workspace → runbook clone → ~/.local/bin + PATH →
# omp → herdr → follow-on commands (never executed). Refusals name hatches.
#
# Portable: stock bash 3.2 — set -u with fallbacks, no mapfile, no `;&`.
set -u

DO_CHECK="0"
NO_OMP="0"
NO_HERDR="0"
for arg in "$@"; do
  case "$arg" in
    --check) DO_CHECK="1" ;;
    --no-omp) NO_OMP="1" ;;
    --no-herdr) NO_HERDR="1" ;;
    -h|--help) sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//;s/^#//'; exit 0 ;;
    *) echo "fresh-box.sh: unknown argument '$arg' (try --check, --no-omp, --no-herdr)" >&2; exit 1 ;;
  esac
done

RUNBOOK_REPO="${FRESH_BOX_RUNBOOK_REPO:-paddyodab/agent-runbook}"
RUNBOOK_URL="https://github.com/${RUNBOOK_REPO}.git"
GITHUB_DIR="${HOME}/Documents/GitHub"
RUNBOOK_DIR="${GITHUB_DIR}/agent-runbook"
BIN_DIR="${HOME}/.local/bin"
PROFILE="${HOME}/.bashrc"
# shellcheck disable=SC2016  # deliberate: literal $HOME expansion belongs to the profile, not this process
PATH_LINE='export PATH="$HOME/.local/bin:$PATH"'
PATH_MARKER='# added by agent-runbook fresh-box.sh (so ~/.local/bin tools resolve)'
OMP_HINT_LINE=$(awk '
  /^  omp:/ { inomp = 1; next }
  inomp && /^[a-z_]+:/ { inomp = 0 }
  inomp && /^    install_hint: \|/ { inhint = 1; next }
  inhint && inomp && /^        mise:/ { sub(/^        mise:[ \t]*/, ""); sub(/^[ \t]+/, ""); gsub(/ *#.*/, ""); print; exit }
' "$(dirname "$0")/machine.yml" 2>/dev/null || true)

die() { echo "fresh-box.sh: $*" >&2; exit 1; }
ok()  { echo "  ok: $*"; }
do_() { echo "  did: $*"; }
gap() { echo "  NEEDS WORK: $*"; }

# --- environment contract --------------------------------------------------------
case "$(uname -s)" in
  Linux) : ;;
  *) die "unsupported platform '$(uname -s)' — this bootstrap targets bare Linux
  boxes (apt). On other platforms install omp/herdr per machine.md by hand." ;;
esac
[ "$(id -u)" = "0" ] && die "refusing to run as root — provision per-user sudo, never root's HOME"

have() { command -v "$1" >/dev/null 2>&1; }

# sudo wrapper: SUDO="" when we ARE root (containers), "sudo " when sudo exists,
# refusal naming the hatch otherwise.
SUDO=""
if [ "$(id -u)" != "0" ]; then
  if have sudo; then SUDO="sudo"; else
    die "sudo not found and not root — apt needs escalated privileges.
  Hatch: run as a sudo-capable user, or install sudo as root first."
  fi
fi

apt_run() {
  if have apt-get; then :; else
    die "apt-get not found — non-Debian-class Linux. Hatch: install the apt
  packages by hand per machine.md, then re-run for the remaining steps."
  fi
  "$SUDO" apt-get "$@"
}

# --- the bill --------------------------------------------------------------------
# Every finding: "ok: / NEEDS WORK: / (skip:)" — check mode prints only the bill.
MISSING=""
note() { if [ -n "$MISSING" ]; then MISSING="$MISSING
  $1"; else MISSING="  $1"; fi; }

bill_deps() {
  local d
  for d in git curl gh; do
    if have "$d"; then ok "dep $d present"; else gap "dep $d missing"; note "dep $d missing (apt)"; fi
  done
}

bill_dirs() {
  if [ -d "$GITHUB_DIR" ]; then ok "workspace $GITHUB_DIR"; else gap "workspace $GITHUB_DIR missing"; note "mkdir $GITHUB_DIR"; fi
  if [ -d "$BIN_DIR" ]; then ok "bin dir $BIN_DIR"; else gap "bin dir $BIN_DIR missing"; note "mkdir $BIN_DIR"; fi
}

bill_runbook() {
  if [ -d "$RUNBOOK_DIR/.git" ]; then
    ok "runbook cloned at $RUNBOOK_DIR"
    if have git; then
      if [ -n "$(git -C "$RUNBOOK_DIR" status --porcelain 2>/dev/null)" ]; then
        gap "runbook tree dirty — refresh will be refused; commit/stash first"
      fi
    fi
  elif [ -e "$RUNBOOK_DIR" ]; then
    gap "runbook path exists and is NOT a repo: $RUNBOOK_DIR"
    note "move $RUNBOOK_DIR aside (foreign checkout — refusing to guess)"
  else
    gap "runbook not cloned"; note "git clone $RUNBOOK_URL $RUNBOOK_DIR"
  fi
}

bill_path() {
  case ":$PATH:" in
    *":${BIN_DIR}:"*) ok "$BIN_DIR on PATH" ;;
    *) gap "$BIN_DIR NOT on PATH" ;;
  esac
  # shellcheck disable=SC2016  # deliberate: we match profile text that contains a literal $HOME; it must not expand here
  path_stmt="export PATH=\"$BIN_DIR"
  # shellcheck disable=SC2016
  alt_stmt='export PATH="$HOME/.local/bin'
  if [ -f "$PROFILE" ] && { grep -F "$path_stmt" "$PROFILE" >/dev/null 2>&1 || grep -F "$alt_stmt" "$PROFILE" >/dev/null 2>&1; }; then
    ok "PATH statement present in $PROFILE"
  else
    gap "PATH statement absent in $PROFILE"; note "append PATH marker+line to $PROFILE"
  fi
}

bill_tools() {
  if [ "$NO_OMP" = "1" ]; then
    echo "  skip: omp (--no-omp)"
  elif have omp; then
    ok "omp present"
  else
    gap "omp missing"; note "omp install: $OMP_HINT_LINE (or see machine.yml omp.install_hint)"
  fi
  if [ "$NO_HERDR" = "1" ]; then
    echo "  skip: herdr (--no-herdr)"
  elif have herdr; then
    ok "herdr present"
  else
    gap "herdr missing"; note "herdr install: curl -fsSL https://herdr.dev/install.sh | sh"
  fi
}

bill() {
  echo "fresh-box.sh --check — the box-day bill:"
  bill_deps
  bill_dirs
  bill_runbook
  bill_path
  bill_tools
  if [ -n "$MISSING" ]; then
    echo "gaps (what a full run would do):"
    printf '%s\n' "$MISSING"
    exit 1
  fi
  echo "nothing missing — box ready for the runbook's own install (see follow-ons)."
}

# --- provisioning steps (each: absence-check, then mutate) ------------------------

step_deps() {
  local need_apt="0"
  for d in git curl gh; do
    if have "$d"; then ok "dep $d present"; else need_apt="1"; fi
  done
  [ "$need_apt" = "1" ] || { ok "deps git/curl/gh all present"; return 0; }

  # git+curl are the base image's own contract: missing base tools are a refused
  # state (the installer's machine.yml gate would refuse later anyway) — our job
  # is gh only, the piece the bare Ubuntu image lacks.
  if ! have git || ! have curl; then
    die "git and/or curl missing — those are the base image's contract, not this
  script's install set (refuse-to-guess what else a stripped box lacks).
  Hatch: apt-get install -y git curl, verify, then re-run."
  fi

  if have gh; then return 0; fi
  # gh via the official apt recipe (idempotent: existing keyring/source skip re-adds).
  # The recipe is machine.md's documented block, executed rather than narrated.
  if [ ! -f /usr/share/keyrings/githubcli-archive-keyring.gpg ]; then
    apt_run update >/dev/null
    have dpkg || die "dpkg missing — non-Debian-class; install gh by hand (machine.md)."
    do_ "apt update (before gh install)"
    "$SUDO" install -d /usr/share/keyrings || die "cannot create /usr/share/keyrings (permission denied?)"
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
      | "$SUDO" dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg status=none \
      || die "gh keyring download failed (egress?) — hatch: check egress, re-run.
  machine.md's egress check: curl -sI https://api.github.com | head -1"
    do_ "gh apt keyring staged"
  else
    ok "gh apt keyring already present"
  fi
  local srcfile="/etc/apt/sources.list.d/github-cli.list"
  if [ ! -f "$srcfile" ]; then
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
      | "$SUDO" tee "$srcfile" > /dev/null \
      || die "gh apt source write failed (permission denied?) — hatch: run as a sudo-capable user."
    do_ "gh apt source staged"
  else
    ok "gh apt source already present"
  fi
  apt_run update >/dev/null || die "apt update failed — check egress / apt sources."
  "$SUDO" apt-get install -y gh >/dev/null || die "gh install failed — see apt output above."
  ok "gh installed ($(gh --version 2>/dev/null | head -1))"
}

step_dirs() {
  if [ -d "$GITHUB_DIR" ]; then ok "workspace exists"; else mkdir -p "$GITHUB_DIR" || die "mkdir $GITHUB_DIR failed"; do_ "created $GITHUB_DIR"; fi
  if [ -d "$BIN_DIR" ]; then ok "bin dir exists"; else mkdir -p "$BIN_DIR" || die "mkdir $BIN_DIR failed"; do_ "created $BIN_DIR"; fi
}

step_runbook() {
  if [ -d "$RUNBOOK_DIR/.git" ]; then
    ok "runbook already cloned"
    if [ -n "$(git -C "$RUNBOOK_DIR" status --porcelain 2>/dev/null)" ]; then
      echo "  note: runbook tree dirty — refresh refused (commit/stash first)."
    elif ! git -C "$RUNBOOK_DIR" pull --ff-only >/dev/null 2>&1; then
      echo "  note: runbook refresh (pull --ff-only) failed — offline? diverged? left as-is."
    else
      ok "runbook refreshed (pull --ff-only)"
    fi
  elif [ -e "$RUNBOOK_DIR" ]; then
    die "refusing to guess: $RUNBOOK_DIR exists but is not a git repo.
  Hatch: if it's a stale/foreign checkout, move it aside or diff it, then re-run."
  else
    git clone --quiet "$RUNBOOK_URL" "$RUNBOOK_DIR" || die "runbook clone failed.
  Hatch: check egress (curl -sI https://api.github.com | head -1); private-repo
  auth is NOT needed for the public runbook clone."
    do_ "cloned $RUNBOOK_REPO -> $RUNBOOK_DIR"
  fi
}

step_localbin() {
  if case ":$PATH:" in *":${BIN_DIR}:"*) true ;; *) false ;; esac; then
    ok "$BIN_DIR already on PATH"
  else
    stated="0"
    if [ -f "$PROFILE" ]; then
      # shellcheck disable=SC2016  # literal $HOME must not expand — we match the profile's own text
      if grep -F "export PATH=\"$BIN_DIR" "$PROFILE" >/dev/null 2>&1; then stated="1"; fi
      if [ "$stated" != "1" ]; then
        # shellcheck disable=SC2016  # literal $HOME must not expand — we match the profile's own text
        grep -F 'export PATH="$HOME/.local/bin' "$PROFILE" >/dev/null 2>&1 && stated="1"
      fi
    fi
    if [ "$stated" = "1" ]; then
      # Stated in the profile but not in THIS shell's PATH: export now + tell.
      export PATH="$BIN_DIR:$PATH"
      echo "  note: PATH statement already in $PROFILE; exported for THIS shell — re-run to pick it up."
    else
      printf '\n%s\n%s\n' "$PATH_MARKER" "$PATH_LINE" >> "$PROFILE" || die "appending PATH to $PROFILE failed"
      export PATH="$BIN_DIR:$PATH"
      do_ "PATH statement appended to $PROFILE (exported for this run too; re-run to pick it up everywhere)"
    fi
  fi
}

step_omp() {
  [ "$NO_OMP" = "1" ] && { echo "  skip: omp (--no-omp)"; return 0; }
  if have omp; then
    ok "omp present ($(omp --version 2>/dev/null | head -1))"
  else
    echo "  --: installing omp (machine.yml omp.install_hint): $OMP_HINT_LINE"
    ( eval "$OMP_HINT_LINE" ) || echo "  note: omp install command failed — install by hand per machine.md, then re-run."
    if have omp; then ok "omp installed"; else gap "omp still missing after install attempt"; fi
  fi
}

step_herdr() {
  [ "$NO_HERDR" = "1" ] && { echo "  skip: herdr (--no-herdr)"; return 0; }
  if have herdr; then
    ok "herdr present"
  else
    echo "  --: installing herdr (official installer)"
    curl -fsSL https://herdr.dev/install.sh | sh || echo "  note: herdr installer failed — install by hand (herdr.dev), then re-run."
    if have herdr; then ok "herdr installed"; else gap "herdr still missing after install attempt"; fi
  fi
}

followons() {
  cat <<EOF

follow-ons (deliberate, never automated by us):
  1. re-run fresh-box.sh            # pick up the new PATH in this shell's context
  2. cd $RUNBOOK_DIR && ./install.sh --machine
                                    # runbook: skills, AGENTS block, tools
  3. ./install.sh --doctor --machine   # must end "nothing missing, nothing drifted"
  4. gh auth login                  # device flow; then: gh auth setup-git
  5. omp login github-copilot       # per-user; browser on YOUR laptop
EOF
}

# --- main ------------------------------------------------------------------------
if [ "$DO_CHECK" = "1" ]; then
  bill
else
  echo "fresh-box.sh — box-day bootstrap"
  step_deps
  step_dirs
  step_runbook
  step_localbin
  step_omp
  step_herdr
  echo
  bill
  followons
fi