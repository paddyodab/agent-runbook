# Door: refactor

**Entry condition.** A lived-in repo whose behavior must be preserved while its shape
changes. Not a bug, not a feature: a deliberate re-architecture (extract a context,
untangle a coupling point, swap a storage model). The stack treats it as a sequence of
behavior-preserving units; the plan note is the first artifact.

## Procedure

1. **Write the plan note:** Problem → Current implementation (with tables) → Proposed
   target model → Migration path (numbered, each step verifiable) → **When to do this**
   (trigger conditions, not "someday") → Related files → Open questions. The NOT-list
   names everything adjacent a refactor might eat: migrations, API surface, test
   rewrites.
2. **Prove the behavior net BEFORE moving anything.** The verify CLI must be able to
   observe the behavior that must survive. If it can't, the first unit is: grow the
   feature docs/CLI to cover it. Do not refactor against a thin net.
3. **Sequence as migration units, each ending verifiable:** behavior net green →
   introduce target shape alongside → migrate callers → **delete the legacy path in
   the same diff** (the half-migrated state is the failure mode) → net green again.
4. **Update the CONTEXT-MAP in the first unit's intent, not along the way.** The map
   change is part of the refactor's contract. A refactor that "discovers" a new context
   mid-flight stops and flags.
5. **Gate per unit** with regression duty re-proving the whole feature-doc index. A
   refactor's acceptance is *nothing observed changed except the shape*.

## Gate

Behavior net green pre-move and post-move, every step. Feature-invisible acceptance
for infra-shaped steps. Done = legacy path deleted AND the map tells the new truth —
not when both paths coexist.

## Escalation

1. Behavior net too thin to prove preservation → grow it first.
2. Migration step not independently verifiable → split it.
3. Legacy path has unknown callers → probe first (blast-radius), or stop-and-flag.
4. Refactor fights a documented coupling point → that's the revisit trigger firing;
   redesign the contract deliberately in intent, don't tunnel through.

## When NOT to use this door

- No behavior worth preserving (prototype/throwaway) → just rewrite: new-codebase with
  a short roadmap.
- The "refactor" is really a feature in disguise → it's a unit on the feature flow.
- No trigger condition can be named → not ready. Record the trigger in the plan note and
  wait. Restless refactoring against a working system is ceremony.