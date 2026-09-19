---
name: fan-out-lanes
description: 'Herdr coordinator for 1:N after a sealed intent and verify-<app> exist. Use when the operator asks to fan out, dispatch lanes, run 1:N, spawn parallel omp workers, or escape 1:1 ride-along: canary → worktrees/panes → herdr agent wait → gate → one consolidated verdict. Refuse if intent is unsealed or verify-<app> is missing.'
---

# fan-out-lanes

Foreman loop for eng-playbooks **1:N**. You are the coordinator in the operator's
herdr session. Coder agents work in lane panes/worktrees. They never write
`comms/<session>/` — that channel is operator ↔ foreman only.

## Preconditions (hard refuse)

Do **not** spawn lanes until all of these hold:

1. A sealed unit intent exists (`intent/N.md` or the operator names an accepted intent
   path) with proof obligations + NOT-list + pinned contexts.
2. `verify-<app>` exists and has been proved once (real-app control CLI, JSON outcomes).
3. CONTEXT-MAP (or equivalent) shows lanes touch **disjoint** files/contexts.
4. You are inside herdr (`HERDR_ENV=1`) **or** the operator accepts degraded mode
   (manual terminals + they run wait themselves). Prefer herdr.

If any precondition fails: say which one, one next action, stop. Do not improvise
ride-along coding in this skill.

## Bounded outcome

Done means: gate-accepted `.evidence/` for each lane (or a single gate bundle) +
`PROOF.md` verdict + one short chat line (+ `m:NNN` mind note if depth). Not
"workers said finished."

## Sequence

### 0. Canary (before any real unit)

Spawn one short-lived pane that only prints a known token (e.g. `pong`) and exits.
`herdr agent wait` (or read the pane) until done. If canary fails, stop — fix herdr
before depending on delegation.

### 1. Open lanes

For each lane id from the intent / ROADMAP:

```bash
# from the built repo root (not prior-art/)
git worktree add "../$(basename "$PWD")-lane-<N>" -b "lane/<unit>-<N>"
```

Use the enclosing-folder convention when present:
`git worktree add ../<repo>-lane-N`.

Then (herdr; parse IDs from JSON, never guess):

```bash
herdr pane split --current --direction right --ratio 0.5 --cwd "<lane-worktree>" --no-focus
# → .result.pane.pane_id
herdr pane run <pane_id> "omp"   # or the operator's usual omp launch
```

Brief each worker **only** with: path to `intent/N.md`, path to
`skills/fan-out-lanes/references/HANDOFF.template.md` (or the copy in-repo),
verify-<app> command names, and "write HANDOFF.md + .evidence/; do not touch
comms/; do not expand CONTEXT-MAP."

### 2. Wait

```bash
herdr agent wait --until done   # or blocked — then stop-and-flag the blocked lane
```

Do not steer lane turns in chat. If blocked: one chat line naming the lane +
blocker; operator decides.

### 3. Collect worker returns

Each lane must leave in its worktree (or agreed evidence root):

- `.evidence/unitN/` (or lane-scoped evidence) with numbered JSON + notes
- `HANDOFF.md` filled from the template (Branch / Verification / Failure Mode /
  Measurements / Files touched)

Reject missing HANDOFF or `Verification: not-verified` — send that lane back or
fail the fan-out.

### 4. Gate (foreman or dedicated gate pane)

Re-run verify-<app> claims yourself. Never trust worker self-reports. Write
`PROOF.md` (mode, lanes, artifacts cited, verdict). Regression duty: re-prove
priors when the playbook requires it.

### 5. Report to the operator

Bro-mode chat: one consolidated verdict (accepted / rejected + why). Cite evidence
paths and `m:NNN` if needed. **Do not merge** unless the operator says merge.
Promote only durable conclusions into the sealed session handoff if a comms
session is open — workers still never write there.

## Status lines (optional, file-only)

If ROADMAP/intent use a status field, update: `ready` → `running` → `blocked` |
`gated` → `done`. No DAG engine.

## Degraded mode (no herdr)

Tell the operator the exact worktree paths and omp cwd commands. They run wait.
You still own gate + consolidated verdict when they say lanes finished.

## Never

- Spawn without sealed intent + verify-<app>
- Let workers edit CONTEXT-MAP or sealed `comms/`
- Auto-merge
- Third solo attempt on the same error (escalation ladder from eng-playbooks)
