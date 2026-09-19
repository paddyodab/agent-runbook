# Door: new-codebase (Mode A)

**Entry condition.** Your design, empty (or throwaway) repo. You author the artifacts;
code obeys. "Webapp / CLI / other" is decided here — it fixes the verify surface, not
the flow.

## Procedure

1. **Draft the first unit's intent by hand, conversationally** — problem, outcome,
   proof artifacts, bounded contexts, NOT-list. No code yet. Mark unknowns explicitly
   (at most 3 open markers).
2. **Resolve open questions with the operator.** Blocking, deliberate. The unit is not
   accepted until questions are answered — this is the conversation-before-
   implementation rule.
3. **Scaffold the repo** (local-first layout: compose or equivalent, per-context
   schemas/CONTEXT.md, monorepo only if genuinely multi-package) and **hand-implement
   the first unit** — the hand-do unit. You (with the operator) learn what "good" looks
   like and what signals matter.
4. **Forge verify-<app>** via `create-verification-skill` against the running app:
   real-app control CLI, JSON outcomes, feature map. **Prove the skill once** by
   driving one full feature with evidence. The lever must exist before the first
   delegated unit.
5. **Run units on the loop:** intent (with proof artifacts written first) → implement
   (inline seed unit, then 1:N lanes on disjoint files) → gate re-proves → merge only
   on accepted proof. Every unit's gate re-proves the priors (regression duty).

## Gate

Per unit: proof artifacts observed via the real app (rejection paths count), evidence
bundle in `.evidence/unitN/`, regression re-proof, gate re-proves worker claims.

## Escalation

1. Unit too big to verify cheaply → decompose until the verify skill can observe done.
2. Lane needs a file outside its contract → stop-and-flag; intent gains the map change.
3. First 1:N unit → seed inline first; canary-spawn a test agent before depending on
   delegation.
4. Shared-runtime interference between parallel workers → per-lane isolated stacks
   (`docker compose -p`) or serialized lane proofs.

## When NOT to use this door

- Repo already runs someone else's design → existing-codebase.
- Changing shape, not birthing a system → refactor.
- Can't name one unit you'd hand-do first → the idea isn't ready; stay in conversation.
  Never scaffold in the abstract.