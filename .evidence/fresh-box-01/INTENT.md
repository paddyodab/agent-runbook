# intent-fresh-box-01 — fresh-box.sh: the one-command box-day bootstrap

Unit 5 of ROADMAP.md. Sealed 2026-09-30, session patdabney/20260930-01. Predecessors:
`.evidence/comms-git-01/` (hook + repo-at-scaffold, bff5be1), `.evidence/comms-git-02/`
(comms-sync, 968d20c/3e6d56d).

## Problem

Friday's EC2 box-day (ssm-user, `comms/patdabney/20260930-01/intro.txt` history) ran
~10 anomalous manual steps before `install.sh --machine` could possibly run:
`mkdir -p ~/Documents/GitHub`, clone the runbook, `sudo apt install gh` (bare Ubuntu
image), `mkdir -p ~/.local/bin`, `export PATH=…` + `~/.bashrc` append (not even
needed — install refused), omp's curl installer, herdr's curl installer. Every step
is a remember-it-again cost for the operator, and dw's onboarding repeats all of it.
machine.md narrates the box-day, but nothing executes its mechanical core — the
session scripts and comms-sync got built precisely so the agent doesn't re-derive
protocol prose; the box-day deserves the same.

What stays OUT (unchanged): git+ssh+curl base image surface, sudo, per-user gh
device-flow auth, `omp login`, herdr machine-add, VPN/SSM transport, `install.sh
--machine` itself (deps gate, skills, adapter) — already owned by machine.md's
sequence or unbuildable-interactive by policy.

## Proposed outcome

One script, `fresh-box.sh`, in the runbook root, installed via the SAME PATH gate as
scaffold/comms-sync/migrator (install.sh §3 pattern):

- `fresh-box.sh` — the provisioning idempotent bootstrap, in dependency order:
  1. **Deps:** git, curl, gh via apt (Debian-class only; sudo required, refusal
     names the hatch). gh added only when the base install lacks it: keyring +
     `sources.list.d` staged first (idempotent re-adds), then `apt-get install gh`.
     Existing gh never touched. Base apt tools never installed by us (`apt-get
     update` runs once when we install gh; git/curl missing → REFUSED, they are the
     base image's own contract).
  2. **Workspace:** `~/Documents/GitHub` mkdir -p (consistency with the laptop).
  3. **Runbook clone:** clone the runbook into it (`paddyodab/agent-runbook`);
     refuses to guess over an existing non-repo checkout; `git pull --ff-only`
     refresh on an existing repo; reports an unclean tree and refreshes nothing.
  4. **`~/.local/bin`:** mkdir -p (the installer gate wants it pre-existing).
  5. **PATH discipline:** `$HOME/.local/bin` already on PATH → nothing; absent →
     append (marker comment + export line, idempotent, re-run never duplicates),
     `PATH="$HOME/.local/bin:$PATH"` exported for the caller's CURRENT invocation
     too, plus the "run again" note. `--check` reports either state, changes
     nothing.
  6. **omp:** run the machine.yml `omp.install_hint` line ONLY when the binary is
     missing (`--machine` dep-gates it later, but a box-day wants the binary there
     NOW). Present → skip (version drift is doctor/machine.yml business).
  7. **herdr:** official installer when missing (best-effort install, then verify);
     present → skip.
  8. **Prints follow-ons it never runs:** `install.sh --machine`, `--doctor
     --machine`, `gh auth login` (+ `gh auth setup-git`), `omp login
     github-copilot` — interactive or browser-flow, by policy never automated.
- `fresh-box.sh --check` — the honest bill (doctor style), ZERO mutation:
  deps present/missing, workspace dirs present/missing, runbook
  present/clean/behind, ~/.local/bin on PATH or not, PATH statement present in
  `~/.bashrc`, omp/herdr present. Exit 0 healthy / 1 gaps (the doctor bill shape).

Standing decisions carried: refusals name hatches; `$HOME/.bashrc` is the profile
of record for bash boxes (the PATH check honors `$PATH`, never assumes bashrc);
never installs a version pin for gh/omp/herdr (reproducibility lives in machine.yml
pins + doctor); never clones, edits, or configures anything except its own list.

## Proof obligations (.evidence/fresh-box-01/, real runs, structured JSON)

1. **01-check-no-mutation.json** — clean box, junk HOME: `--check` exits 1, prints
   the honest missing-list, `find -newer` + git-status snapshots show zero
   mutations (junk-HOME variant of the doctor-is-provably-read-only rule).
2. **02-idempotent-run.json** — full run on a scratch HOME (no-repo checkout
   + missing bins paths exercised with fakes where needed): dirs created, runbook
   cloned, PATH line appended EXACTLY ONCE, re-run → NO-OP (byte-true), `--check`
   green after; a foreign `$HOME/Documents/GitHub/agent-runbook` (non-repo) →
   REFUSED naming the hatch, never clobbered.
3. **03-docker-e2e.json** — debian:stable-slim, fresh user, REAL network: gh
   missing → keyring + source + install land, `gh --version` OK; runbook cloned;
   `install.sh --machine` preconditions green (git/gh/gh auth-check list);
   `--check` before = honest gaps / after = green. (omp install_hint needs mise —
   sandbox-proofed already; container proof uses `--no-omp --no-herdr` flags.)
4. **04-regression.json** — 28-assertion comms gate green HOST + bash-3.2 docker
   after the change; installer doctor `nothing missing, nothing drifted` on this
   box post-install; shellcheck zero errors.

## Invariants

- Idempotent by construction: every state-mutation is preceded by its
  absence-check; a completed run re-run is a no-op; `--check` mutates nothing.
- Refuses to guess: existing non-repo runbook dir → refuse naming the hatch;
  diverged/pulled-not-ff runbook → report, don't reset; non-apt platform → print
  + name the manual hatch; missing sudo → name it, don't try.
- bash-3.2 portable (`set -u`, no mapfile, `|| true` on find, `${VAR:-fallback}`
  fallbacks).
- Never interactive: no prompts, no editors; interactive steps PRINTED.
- No version pin enforcement for gh/omp/herdr (machine.yml owns pins; doctor
  owns version drift).

## Affected systems

- New `fresh-box.sh` (runbook root)
- `install.sh`: §3d install block (same PATH gate + cmp fence as §3/§3b),
  §2b doctor `for dexec` loop entry, uninstall line update, and the §3 note
  UX fix: when `~/.local/bin` is NOT on PATH, print "re-run after exporting
  PATH" (today it prints a NOTE and moves on — Friday's friction).
- README (tree line + fresh-box paragraph) + machine.md (§ Shared-context box
  step 5b: "the box-day bootstrap" replaces the narrated steps; the gh recipe
  block stays documented as the script's proven logic).
- machine.yml: NO change (no new deps — the script reads `omp.install_hint`
  from the manifest at runtime, awk-parse the pinned `version:` line only).

## NOT-list

- No sudo-less assumption; no root-run.
- No apt alternatives on non-Debian platforms (macOS/BSD: echo + named hatch).
- No gh/omp/herdr version pins, no version upgrade logic (drift is doctor's).
- No shell-profile editing beyond the missing-PATH statement (no aliases, no
  `umask`, no omp/herdr PATH lines — those installers append their own).
- No VPN/SSM/proxy/egress-verification, no herdr machine-add wiring (unit 3's
  VERIFY items stay docs).
- Not called from install.sh — the box-day order is fresh-box.sh → install.sh;
  install.sh stays the runbook's OWN provisioner (skills/skills-block/scripts).
- No `--machine`-mode coupling: fresh-box.sh runs BEFORE install.sh, never
  wraps it (separation: box vs runbook).

## Open questions

- (none) PATH statement = `export PATH="$HOME/.local/bin:$PATH"` (the exact
  line from Friday's history, idempotent, marker comment above it). Documents
  folder location fixed as `$HOME/Documents/GitHub` (consistency with laptops).

## Next steps

1. Write `fresh-box.sh` (bash-3.2 portable; refusals name hatches).
2. install.sh: §3d block + doctor loop entry + uninstall line + PATH note UX.
3. Proofs: junk-HOME no-mutation + scratch-HOME idempotency + docker e2e.
4. README/machine.md doc duty; commit (push = explicit operator go).