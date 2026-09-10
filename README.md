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
scaffold/
  new-enclosing-folder.sh — one idea, one folder: comms/ + prior-art/ + built repos
```

- **Bro-mode** — the agent's standing register: answer first, lists ≤5, no preamble or
  recaps, one next action. Depth goes to mind notes (numbered markdown files), cited in
  chat as `m:NNN`. Say "mind" (or "mind 3") to open one in a herdr pane; "bro" to get a
  plain restate; "explain" to break the register upward.
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
templates, sealed handoffs), `prior-art/` for reference repos, built repos at the root.
It builds atomically (stages, then moves into place) and is bash-3.2/BSD-safe — works on
stock macOS. This repo's copy is canonical; `~/.local/bin/new-enclosing-folder.sh`
becomes an installation of it (below).

## Install

```bash
./install.sh    # skills → ~/.omp/agent/skills/ + ~/.agents/skills/ (symlinks)
                # marked behavior block → ~/.omp/agent/AGENTS.md (idempotent append)
                # scaffold → ~/.local/bin/ (if it exists and is on PATH; skips otherwise)
```

Idempotent — rerun after pulling. Uninstall: remove the marked block, the two skill
symlinks, and `~/.local/bin/new-enclosing-folder.sh` (all paths printed at the end of
install).

## Hit the ground running

After install, run the [SMOKE.md](SMOKE.md) checklist — checks that prove the toolkit is
live in a fresh session. If all pass, the agent behaves; no prior context needed.

## Conventions

- This repo is self-contained by rule. Improvements land here first, then re-install.
- Unproven mechanisms (advisor checkpoints, spec-ID addressability, the eval harness...)
  are deliberately NOT installed skills yet — they live in
  `skills/eng-playbooks/references/stack.md` as "adopt when friction demands." Forge
  before abstract.
- Conversation history and handoffs are machine-local (comms protocol); this repo is the
  portable soul.