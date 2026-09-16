# HANDOFF — lane worker return

Copy to the lane worktree as `HANDOFF.md` before claiming done. The foreman/gate
parses this; chat claims are ignored.

## Identity

- **Unit:** (e.g. `intent/4.md` / ROADMAP unit id)
- **Lane:** (e.g. `4` / `lane/unit-4-a`)
- **Branch:** (exact branch name in this worktree)
- **Worktree path:**

## Verification (pick exactly one)

- `live-ui-verified` — drove the real app / verify-<app> surface; evidence attached
- `unit-test-verified` — automated tests are the proof; name commands + results
- `type-check-only` — types/lint only (not enough for product units unless intent says so)
- `verifier-blocked` — could not run verify; name the blocker
- `verifier-failed` — verify ran and failed; evidence shows failure
- `not-verified` — **gate must reject**

**Verification:**

## Evidence

- **Evidence dir:** `.evidence/...`
- **Artifact list:** (numbered files + one-line each)
- **Verify commands run:** (exact)

## Failure Mode

- **None** / **description** (what broke, what you tried, what you did *not* change)

## Measurements (if intent claimed any)

- Claim → observed value → how re-checked

## Files touched

- Paths only (must stay inside intent-listed contexts)

## NOT-list respect

- Confirm no NOT-list items were built: yes / no + notes

## Foreman-only

_(leave blank — foreman fills gate verdict)_

- **Gate verdict:** accepted / rejected
- **Gate notes:**
