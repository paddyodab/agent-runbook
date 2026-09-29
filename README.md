# agent-runbook

Engineering workflows + agent behavior for omp, proven in real forges — portable as one repo.

**What this is:** the method that survived — a four-door playbook system (new codebase /
existing codebase / refactor / bug fix), the artifact stack underneath it (ROADMAP, intent,
CONTEXT-MAP, verify-<app>, evidence, 1:N delegation), a conversational contract
(bro-mode + mind notes) that keeps the operator in the loop without drowning them, and the
enclosing-folder scaffold that gives every idea its own comms-protocol workspace.

**Provenance:** distilled from [study-dev-tooling / coffee-shop](https://github.com/paddyodab/coffee-shop)
(forge #1: units 1–4.5 gate-proven, three 1:N delegation units, zero lane violations) and
sharpened against prior-art (pstack, lid, spec-kit, turborepo, i-have-adhd). Everything here
is written to be read cold — you do not need those sources; they are cited for trust, not
dependency.

## What's inside

```text
skills/
  bro-mode/        — the conversational contract: chat stays conversational, depth
                     lives in mind notes, drill-in via herdr pane (or paths in chat)
  eng-playbooks/   — the four doors + the artifact stack they share
  fan-out-lanes/   — Herdr 1:N coordinator: canary → worktrees/panes → wait → gate;
                     workers return HANDOFF.md + evidence; never write sealed comms/
  turborepo/       — vendored vercel/turborepo skill (canary.4): the monorepo build
                     system, so monorepo work walks the doors with turbo knowledge
scaffold/
  new-enclosing-folder.sh — one idea, one folder: comms/ (a git repo from day one:
                     credential-scanning pre-push hook guards every push) +
                     prior-art/ (read-only) + artifacts/ + built repos
machine.yml       — the declarative machine: omp version pin, runtime deps, skill
                     list, ticketing adapter slot (none | gh-issues | shortcut)
machine.md        — fresh-box sequence: turn any box (laptop, VPS, docker sandbox)
                     into a working omp with all the extras, reproducibly
template/         — Dockerfile for paddyodab/sbx-omp:<pin>: the omp sandbox image
                     (extends docker/sandbox-templates:shell-docker; mise + omp baked)
kit/omp/          — Docker Sandboxes kit (kind: sandbox, schema v2): the sandbox
                     rendering of machine.yml — entrypoint omp, proxy-managed
                     credentials, network allow-list, skills + AGENTS block as files;
                     domain mixins land under kit/mixins/<domain>/ when forged
install.sh        — classic (this tree) and --machine (manifest-driven) modes,
                     plus --doctor (read-only: deps/adapter/secrets in machine
                     mode; skills×2 roots, AGENTS block parity, scaffold/migrator
                     parity + everything above in machine mode — both modes)
comms-lifecycle-test.sh — the comms gate: 28-assertion two-fake-user run in a
                     disposable /tmp fixture staged from the named folder's comms/
                     scaffold (live enclosing folders are safe to point at); §11
                     proves the comms-as-git tier (valid repo + credential pre-push
                     hook refuses a leaky push, passes an innocent one)
migrate-user-comms.sh — one-command migration of pre-multi-user enclosing folders;
                     also init's comms/ as a git repo + stamps the credential hook
                     on old folders (idempotent)
SMOKE.md          — post-install checklist: prove the toolkit is live in a fresh session
AGENTS.md         — the marked standing-behavior block install.sh appends to ~/.omp/agent/AGENTS.md
intent-shared-comms.md — the multi-user comms unit's contract (sealed intent);
                     units comms-git-01/02's contracts live at
                     `.evidence/comms-git-0N/INTENT.md`
comms-sync         — the comms-as-git plumbing: import (pull --ff-only + hook
                     self-heal; divergence → named rename recipe), export
                     (self-heal → commit-if-needed → push --atomic), remote
                     <url>, status; intentional firing only (unit comms-git-02)
sandbox-test.sh   — the proof: docker container + fresh HOME + machine install + pinned omp
sbx-test.sh       — the same proof in a real Docker Sandbox microVM (sbx create shell)
.evidence/        — numbered JSON artifacts + PROOF.md per proven unit
```

- **Bro-mode** — the agent's standing register: answer first, lists ≤5, no preamble or
  recaps, one next action. Depth goes to mind notes (numbered markdown files), cited in
  chat as `m:NNN`. Say "mind" (or "mind 3") to open one in a herdr pane; "bro" to get a
  plain restate; "explain" to break the register upward.
- **Fan-out lanes** — after a sealed intent and `verify-<app>`, the foreman canaries,
 then opens git worktrees + herdr panes, waits with `herdr agent wait`, re-proves via
 the gate, and returns one verdict. Lane workers leave `HANDOFF.md` + `.evidence/`;
 sealed `comms/` stays operator ↔ foreman only.

Note on mind-note locations: inside an enclosing folder they land in the CURRENT
session folder, `comms/<user>/<YYYYMMDD>-<NN>/mind/` (the multi-user layout);
without a session folder, `.mind/` in the repo (gitignore it).

- **Eng playbooks** — classify how work walks in the door, then follow one named procedure:
  new-codebase (Mode A: artifacts before code), existing-codebase (Mode B: recover the
  design from the running system), refactor (behavior net first, migrate-and-delete),
  bugfix (reproduce first, smallest provable fix). One artifact stack under all four.
- **The enclosing-folder scaffold** — the comms protocol (session handoffs, sealing,
  cross-session continuity) that surrounds all of this work:

```bash
./scaffold/new-enclosing-folder.sh    # interactive: name, purpose, parent dir
```

One idea, one folder: `comms/` for conversation continuity (session-start/end scripts,
templates, sealed handoffs), `prior-art/` for reference repos (clones made read-only on
arrival — reference, never a work target; the copy we edit lives at the root; parallel
agent work uses git worktrees), `artifacts/` for operator-dropped reference material
(PDFs, decks — named-file access only, never scanned), built repos at the root.
It builds atomically (stages, then moves into place) and is bash-3.2/BSD-safe — works on
stock macOS. This repo's copy is canonical; `~/.local/bin/new-enclosing-folder.sh`
becomes an installation of it (below).

## The fresh box (machine mode)

Your global omp area is a build output, not the agent. `machine.yml` declares what a box
needs — omp version pin, deps, skills, one ticketing adapter (workplace-owned, not
repo-owned) — and `install.sh --machine` builds it on any box. `--doctor` reports
what's missing or drifted without touching anything: machine mode checks omp pin +
runtime deps + adapter + secrets; BOTH modes also check installed state (skills in
both discovery roots, the AGENTS.md marked block's byte-parity, scaffold + migrator
parity under ~/.local/bin). [machine.md](machine.md) carries
the full sequence; [sandbox-test.sh](sandbox-test.sh) proves it in a docker container, and [sbx-test.sh](sbx-test.sh) proves it in a real Docker Sandbox microVM
before you trust it on real hardware.

## Install

```bash
./install.sh             # classic: skills (incl. turborepo) symlinked from this tree,
                         # marked behavior block → ~/.omp/agent/AGENTS.md,
                         # scaffold → ~/.local/bin/ (if on PATH; skips otherwise)
./install.sh --machine   # fresh box: manifest-driven (machine.yml); omp version check,
                         # dep gates, adapter clone + omp plugin link, secrets gated
./install.sh --doctor    # read-only report: missing/drifted; writes nothing
```

Idempotent — rerun after pulling. Uninstall: remove the marked block, the skill
symlinks, and `~/.local/bin/new-enclosing-folder.sh` (all paths printed at the end of
install; adapter clones live under `~/.omp/adapters/`).

## Hit the ground running

After install, run the [SMOKE.md](SMOKE.md) checklist — checks that prove the toolkit is
live in a fresh session. If all pass, the agent behaves; no prior context needed.
For the machine/fresh-box path, the equivalent is `./sandbox-test.sh` (docker) plus the
machine checks in [machine.md](machine.md). Existing enclosing folders predating the
multi-user layout migrate with `./migrate-user-comms.sh <folder>` (idempotent); the
comms protocol's own gate is `./comms-lifecycle-test.sh <folder>` — 28 assertions in
a disposable /tmp fixture (green on bash 5.3 and stock bash 3.2); pointing it at a
live enclosing folder is safe by construction, it never mutates what you name.

## Shared-context box (multi-user)

For one box shared by several users over SSH/herdr (AWS or any Linux server): the comms
protocol is **user-keyed** — `comms/<user>/<YYYYMMDD>-<NN>/` — with a cross-user
canonical state (newest sealed handoff anywhere wins). Deployment runbook: the
"Shared-context box" section of [machine.md](machine.md). Protocol proofs:
`./comms-lifecycle-test.sh <enclosing-folder>` (two fake users, 28 assertions, run
in a disposable /tmp fixture — the named folder is only read; green on bash 5.3 and
stock bash 3.2), evidence in `.evidence/shared-comms-01/`.

## Comms-as-git (transport tier)

`comms/` is a small git repo from the day the scaffold creates it. History moves
between nodes ONLY deliberately (session boundaries or grab-and-go):
`comms-sync import | export | remote <url> | status` wraps exactly that plumbing
(import = `pull --ff-only` + hook self-heal + optional `--resume`; export =
self-heal → commit-if-needed → `push --atomic`; raw git works too). The
**credential pre-push hook** ships stamped on every
scaffold and is re-stamped by the migrator — a push whose added lines carry
credential-shaped material is refused with file+line; the escape is
`git push --no-verify`, deliberately. Evidence: `.evidence/comms-git-01/`
(hook + repo-at-scaffold) and `.evidence/comms-git-02/` (comms-sync;
INTENT.md in each = the unit contract). Remote naming: one GitHub repo per
enclosing folder's comms/, `<slug>-comms`, private (owner decision, 2026-09-29).

## Conventions

- This repo is self-contained by rule. Improvements land here first, then re-install.
- Unproven mechanisms (advisor checkpoints, spec-ID addressability, the eval harness...)
  are deliberately NOT installed skills yet — they live in
  `skills/eng-playbooks/references/stack.md` as "adopt when friction demands." Forge
  before abstract.
- Conversation history and handoffs are machine-local (comms protocol); this repo is the
  portable soul.