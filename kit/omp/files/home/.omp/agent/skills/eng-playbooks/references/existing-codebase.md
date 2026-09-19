# Door: existing-codebase (Mode B — legacy intake)

**Entry condition.** Pre-existing repo, someone else's design (usually fleshed out in
tickets). You do not author the design — you **recover** it. The running system is the
author; you transcribe. Recovered artifacts then vet every incoming unit exactly as in
Mode A.

## Procedure

1. **Get it running first.** Stack up, smoke the entry points, capture how it's driven
   (existing scripts, docs, what the tickets assume). A system you can't run cannot be
   recovered, only guessed at. If it won't run, "make it run" is a legitimate first
   unit with proof artifacts (entry points smoke green).
2. **Forge verify-<app> against the existing system** — same skill pack, same contract.
   This is *more* valuable in Mode B: the CLI becomes the instrument that recovers the
   design. Rejection paths and error shapes are discovered here, not designed.
3. **Recover CONTEXT-MAP.md by probing, not by reading alone.** Propose 3–5
   *fundamentally different* clusterings (data flow / user-facing capability / domain
   concept / behavioral boundary). Explicitly excluded as lenses: frontend-vs-backend
   splits, deploy-together, team ownership, generic-utils. The operator's choice of
   lens is the edge detection. Then drive the real system through each hypothesized
   boundary (the verify CLI) and write contracts as observed behavior: "from → to,
   what crosses, mechanism." Where tickets and behavior disagree, record the
   disagreement — that gap is the repo's real design debt. Don't "fix" it silently.
4. **Recover ROADMAP.md backward from the ticket queue.** Each backlog item becomes a
   unit when it has: problem → outcome → proof obligations (written against the verify
   CLI) → contexts touched → NOT-list. A ticket that can't produce proof obligations
   stays a ticket.
5. **Regression duty is the superpower.** Every incoming ticket is vetted against the
   recovered map: does it touch contexts it doesn't list? Does it silently add a
   contract? Prove each unit against the recovered feature docs.

## Gate

Same as Mode A, plus one rule: **no delegation until the map is recovered** —
delegating against an unrecovered map multiplies legacy chaos instead of containing it.

## Escalation

1. System won't run → that's the first unit.
2. Probe contradicts ticket intent → record as design debt in the map; a later unit
   decides.
3. No tickets exist (design lives only in heads/code) → the recovered map + feature
   docs *are* the product of the first stretch; units come after.

## When NOT to use this door

- You're the author and the repo is greenfield-shaped → new-codebase.
- Behavior must change and the change is cross-context shape → refactor (after the map
  exists).
- The bug is localized and understood → bugfix directly; the recovered map improves its
  regression net but full recovery isn't a prerequisite.