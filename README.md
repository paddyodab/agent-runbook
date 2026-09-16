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
  new-enclosing-folder.sh — one idea, one folder: comms/ + prior-art/ (read-only) +
                     artifacts/ + built repos
machine.yml       — the declarative machine: omp version pin, runtime deps, skill
                     list, ticketing adapter slot (none | gh-issues | shortcut)
machine.md        — fresh-box sequence: turn any box (laptop, VPS, docker sandbox)
                     into a working omp with all the extras, reproducibly
install.sh        — classic (this tree) and --machine (manifest-driven) modes,
                     plus --doctor (read-only what's-missing/drifted report)
sandbox-test.sh   — the proof: docker + fresh HOME + machine install + pinned omp
```

- **Bro-mode** — the agent's standing register: answer first, lists ≤5, no preamble or
  recaps, one next action. Depth goes to mind notes (numbered markdown files), cited in
  chat as `m:NNN`. Say "mind" (or "mind 3") to open one in a herdr pane; "bro" to get a
  plain restate; "explain" to break the register upward.
- **Fan-out lanes** — after a sealed intent and `verify-<app>`, the foreman canaries,
 then opens git worktrees + herdr panes, waits with `herdr agent wait`, re-proves via
 the gate, and returns one verdict. Lane workers leave `HANDOFF.md` + `.evidence/`;
 sealed `comms/` stays operator ↔ foreman only.

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
what's missing or drifted without touching anything. [machine.md](machine.md) carries
the full sequence; [sandbox-test.sh](sandbox-test.sh) proves it in a docker container
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
machine checks in [machine.md](machine.md).

## Conventions

- This repo is self-contained by rule. Improvements land here first, then re-install.
- Unproven mechanisms (advisor checkpoints, spec-ID addressability, the eval harness...)
  are deliberately NOT installed skills yet — they live in
  `skills/eng-playbooks/references/stack.md` as "adopt when friction demands." Forge
  before abstract.
- Conversation history and handoffs are machine-local (comms protocol); this repo is the
  portable soul.