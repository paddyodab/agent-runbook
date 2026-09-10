# The artifact stack (all four doors)

One stack, proven in forge #1 (study-dev-tooling/coffee-shop: units 1–4.5 gate-proven,
three 1:N delegation units, zero lane violations). The doors change who authors the
artifacts and when; the artifacts themselves never change shape.

```text
comms protocol (if an enclosing folder exists)  → session continuity between days
engineering half (this stack)                  → how work happens inside a session:
   ROADMAP.md        unit sequencing + governance + regression duty
   intent/N.md       one unit's contract: problem, outcome, proofs, NOT-list
   CONTEXT-MAP.md    bounded contexts + contracts + documented coupling points
   verify-<app>      the acceptance gate: real-app control CLI, evidence bundles
   .evidence/        numbered JSON artifacts + PROOF.md per unit
   1:N pattern       inline seed unit → parallel lanes on disjoint files → gate re-proof
```

## ROADMAP.md

Units as the atomic unit of work: **problem → outcome → proof obligations → context
contracts → done**. A fresh worker picks up a unit cold and knows what "done" looks like.

Governance (held under three delegation units):

- The context map changes at **intent time**, never at code time — workers never add
  contexts or contracts.
- A unit touches only its intent-listed contexts; a needed extra touch is a
  stop-and-flag, not a silent expand.
- **Proof artifacts written before implementation** — no obligations, no delegation.
- Units must be cheaply verifiable; decompose until the verify skill can observe "done."
- Lanes are parallelization boundaries: units touching disjoint contexts run simultaneously.
- **Regression duty:** every unit's proof run re-proves the priors. Feature docs are the
  regression index. A later unit invalidating a doc is a contract break, proven, not
  silently edited.

## intent/N.md (the unit contract)

Sections: Problem → Proposed outcome → What "good" looks like (proof artifacts) →
Invariants the verification will check → Affected users/systems → Bounded contexts →
Boundary contracts → Context-split rationale (only when creating contexts) → Constraints
→ Open questions → What this unit is NOT → Next steps.

Rules that earned their place:

- Every artifact must be checkable by **driving the real app**, not reading code.
- Rejection paths count as proof.
- Open questions block implementation; resolving them is a deliberate operator act.
  Mark unknowns explicitly rather than hiding assumptions — at most 3 open markers at
  a time.
- NOT-list is load-bearing: everything adjacent a worker might plausibly build anyway.
- Boundary contracts are what make the middle delegatable: workers can't collide if
  contracts are pinned first.
- Document deliberate coupling points with their revisit triggers ("if inventory gets
  its own database, this becomes an explicit API — the change starts here, not in code").
- Next steps each end in something verifiable; if a step can't be verified on completion,
  split it.

## CONTEXT-MAP.md

Contexts table (context / owns / service / schema), contracts table (from → to /
contract / mechanism), and documented coupling points with revisit triggers. The map is
the collision-avoidance artifact: delegation safety comes from pinned contracts, not from
workers coordinating.

## verify-<app> (the acceptance gate)

Forge with `create-verification-skill` **before** writing the first unit's intent —
proof artifacts must name commands that exist. Contract:

- Real-app **control CLI** (doctor + product commands), structured **JSON outcomes** —
  a 409 refusal is an observable outcome, not a transport error.
- Feature docs are the regression index: user-POV how-to-reach + how-to-drive + gotchas.
- Workers self-prove before handoff; the gate re-proves every claim — evidence, not
  self-reports. When evidence looks wrong, trace the system's actual history before
  claiming a bug (evidence labels are written by humans and can be wrong).
- Isolation for parallel verification: stock `docker compose -p <project>` gives
  per-lane networks/volumes/ports; parameterize the whole path (ports AND service URLs)
  or you build cross-talk in on purpose.

## .evidence/

One folder per unit: numbered JSON artifacts (`01-…`, `02-…`), a PROOF.md (mode, lane
review, artifacts with artifact-number citations, gate notes, verdict). Rejection paths
and regression re-proofs get their own numbered artifacts.

## 1:N delegation

**Seed unit inline first** (shared prerequisite), then **parallel lanes on disjoint
files**, then the **gate**. Canons that held:

- Contract design is collision avoidance: if a lane needs shared territory, give it a
  self-contained alternative in its own files, or re-slice the lanes.
- Brief every lane with "verify-first" — "no diff, here's the evidence" is a
  first-class deliverable.
- Canary-spawn a one-word test agent before any unit depends on delegation.
- Mechanical contract-to-code lanes run fine on cheap/fast models; the strong model
  spends tokens on intent + gate. The intent's quality sets the ceiling on worker tier.
- Known escalation: parallel workers on a shared runtime stack mutate each other's
  state — per-lane isolated stacks (above) or serialized lane proofs.

## Mode A / Mode B

**Mode A greenfield** (new-codebase door): the engineer authors artifacts; code obeys;
artifacts before code.
**Mode B legacy intake** (existing-codebase door): the running system authors the
artifacts; the engineer transcribes. Run it first; forge verify-<app> as the recovery
instrument; recover CONTEXT-MAP by probing real boundaries; recover ROADMAP backward
from tickets (a ticket becomes a unit when it can produce proof obligations); regression
duty vets every incoming ticket. Delegating against an unrecovered map multiplies chaos.

## UNFORGED fills (adopt only when friction demands)

Provenance: sharpened against prior-art (pstack, lid, spec-kit, turborepo, i-have-adhd)
but **not yet exercised in omp**. Each becomes real only when a forge unit proves it:

- **Playbook routing steps verbatim into the todo list** (pstack poteto-mode).
- **Delegation handoff contract + verification enum**: workers return Branch /
  Verification (live-ui-verified / unit-test-verified / type-check-only /
  verifier-blocked / verifier-failed / not-verified) / Failure Mode / Measurements;
  gate parses and rejects `not-verified` (orchestrate).
- **Measurement re-verification**: gate re-runs quantitative claims post-handoff
  (tolerance, unit-aware) (orchestrate).
- **Strong-model consult checkpoints**: before major decisions, when stuck twice,
  before declaring done (advisor).
- **Spec-ID addressability**: path-concatenated IDs (e.g. `ORD-CANCEL-002`) so one
  grep returns intent + feature doc + evidence; light @spec annotations at entry
  points only (lid).
- **Cross-artifact consistency pre-gate** before implementation (spec-kit analyze).
- **Diff-scope gate teeth**: gate script checks a unit's diff touches only
  intent-listed lanes (turborepo review-gate pattern).
- **One-command regression replay** of all feature docs' obligations (turborepo
  aggregate-gate pattern).
- **Paired eval harness with blind judge** for proving workflow changes beat baseline
  (i-have-adhd).
- **Learning routing**: mine sessions → Accepted/Rejected/Backlog → operator approves
  → structural enforcement (pstack reflect).

## What's refused outright

- Four frameworks where one stack + four doors suffice.
- Formal-verification overlays (lid's own research program: 10 experiments, 1 survivor).
- @spec-everywhere ceremony — annotate entry points, never chase every helper.
- Docs as disposable output — docs are the permanent intent record; code is the
  disposable layer ("delete all code, regenerate from intent" is the bar, not the
  reverse).