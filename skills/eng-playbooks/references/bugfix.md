# Door: bugfix

**Entry condition.** Broken behavior in a running system: a report, a failing test, a
crash. Reproduce first, smallest provable fix, regression net. A bug unit is still a
unit — intent + proofs + gate — but its intent is written from the repro.

## Procedure

1. **Reproduce before touching code.** Drive the real app (verify CLI or the surface
   the report came from) to the broken state; capture command + observed output as
   evidence. No repro, no unit — and "can't reproduce" is a legitimate triage outcome
   (report what was checked: env, version, duplicates; don't guess-fix). Never
   over-claim: verified / partial / failed.
2. **Write the bug unit's intent from the repro:** problem = the repro; proof
   artifacts = the same repro now passing, PLUS the regression net (prior feature docs
   still green); NOT-list = adjacent behavior not touched. State the root cause in the
   intent before any fix — can't state it? The next step is diagnosis, not patching.
3. **Failing test first when a cheap local target exists:** red → smallest fix →
   green. When the path is integration-heavy, CLI repro artifacts are the red/green —
   don't force a unit test where the app surface is the honest check.
4. **Smallest fix you can prove.** Fix root cause, not symptom. A fix that needs a
   workaround is a consult checkpoint — stuck twice → consult (stronger model /
   operator), name the doubtful assumption before attempt 3.
5. **Prove: repro green, prior obligations green, then re-run on main.** Evidence
   bundle like any unit. A regression test earns its place only if a plausible future
   bug would fail it.
6. **If the bug revealed a map lie** (behavior the CONTEXT-MAP/feature docs don't
   match): contract break — fix the map **with proof** in the same diff, never
   silently.

## Gate

Repro passes, regression net green, evidence reviewed at the pass. The gate re-runs the
repro itself — show the failing state and the passing state.

## Escalation

1. Can't reproduce → triage closes it; record in the feature doc so the next agent
   doesn't re-triage.
2. Cause unclear after 2 attempts → consult / adversarial-review the diff before the
   third.
3. Fix ripples beyond one context → stop-and-flag: multi-context unit, write the
   intent with the map change; never expand a bug lane silently.
4. Same bug class, third occurrence → the system's wrong, not the code: escalate to a
   refactor plan note, and encode the lesson as a check, not a memory.

## When NOT to use this door

- The "bug" is intended behavior → triage closes it; document it.
- The fix requires new behavior/decisions → feature unit on the feature flow.
- The system doesn't run at all → existing-codebase, step 1.