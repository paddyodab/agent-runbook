---
name: eng-playbooks
description: 'Engineering workflows for agentic coding with omp. Use when starting engineering work of any kind: a new app, an existing repo, a refactor, or a bug fix. Classifies the work into one of four doors (new-codebase, existing-codebase, refactor, bugfix) and follows the matching named procedure over one shared artifact stack (ROADMAP units, intent contracts, CONTEXT-MAP, verify-<app> control CLI, evidence bundles, 1:N delegation).'
---

# eng-playbooks

Work walks in through one of four doors. Classify the door, follow its procedure. All
four share one artifact stack (references/stack.md). App type (web / CLI / API /
desktop) changes the verify surface, not the door.

## 0. Classify the door

```text
Door                Entry condition
new-codebase        your design, empty (or throwaway) repo
existing-codebase   someone else's design, running code, design lives in tickets/heads
refactor            lived-in repo, shape must change, behavior preserved
bugfix              broken behavior in a running system
```

Unsure between two doors? Read the "When NOT to use" section of the closer candidate
first (references/new-codebase.md, existing-codebase.md, refactor.md, bugfix.md) —
each names its own exits.

## 1. Non-negotiables (all doors)

- **Conversation before implementation.** Open questions get resolved with the operator
  deliberately; unresolved questions block implementation — that is their job.
- **Proof artifacts are written before the code they prove.** If you can't describe how
  "done" will be observed, the unit isn't ready.
- **Rejection paths count as proof.** A unit that only verifies the happy path proves
  the wrong thing.
- **The map changes at intent time, never at code time.** A worker never adds a context
  or contract silently; a needed extra touch is a stop-and-flag.
- **The gate re-proves everything.** Workers self-prove before handoff; the gate
  re-runs every claim. "I fixed it" is worthless — show the failing state and the
  passing state.
- **NOT-lists fence scope.** Everything adjacent a worker might plausibly build anyway.
- **Doc duty lands in the same diff** as the code it documents.

## 2. The doors (procedures)

Read the reference for the chosen door and follow it in order:

- [references/new-codebase.md](references/new-codebase.md) — Mode A: intent by hand →
  resolve open questions → scaffold + hand-do unit 1 → forge verify-<app> → then units
  (and 1:N delegation) run on the loop.
- [references/existing-codebase.md](references/existing-codebase.md) — Mode B: run it
  first → forge verify-<app> as the recovery instrument → recover CONTEXT-MAP by probing
  real boundaries → recover ROADMAP backward from tickets → regression duty vets every
  incoming ticket. No delegation until the map is recovered.
- [references/refactor.md](references/refactor.md) — plan note first → prove the
  behavior net BEFORE moving anything → migration units, each verifiable → migrate
  callers, delete the legacy path in the same diff → map updated in the first unit's
  intent.
- [references/bugfix.md](references/bugfix.md) — reproduce before touching code (no
  repro = legitimate triage outcome) → intent from the repro → failing test when a
  cheap local target exists → smallest provable fix → gate re-runs the repro.

## 3. The stack under all four doors

[references/stack.md](references/stack.md) — the artifact stack in full: ROADMAP.md
unit pattern + governance, intent contract template rules, CONTEXT-MAP pattern,
verify-<app> skill contract, .evidence/ convention, the 1:N delegation sequence, Mode
A/B distinction, and the UNFORGED fills (adopt only when friction demands).

## 4. Verify-surface modifiers

- **Web** → browser drive + screenshots (the harness's browser, not HTML snapshots).
- **CLI** → run the real binary; exit codes + captured output are the artifacts.
- **API** → curl/httpx against the real server; JSON outcomes, refusal-as-outcome.
- **Desktop** → platform driver; if none exists, the first unit grows one.

Pick the surface when verify-<app> is forged; the door doesn't change.

## 5. Escalation ladder (all doors)

1. Unit can't be verified cheaply → decompose until the verify skill can observe done.
2. Lane needs a file outside its contract → stop-and-flag; intent gains the map change.
3. Stuck after 2 attempts on the same error → consult (stronger model / operator), name
   the doubtful assumption — don't try attempt 3 alone.
4. Same failure class third occurrence → the system's wrong, not the code: encode the
   lesson as a check (lint/script/gate), not a memory.