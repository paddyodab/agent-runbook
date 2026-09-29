# PROOF — comms-git-02 (comms-sync: import/export/remote/status + hook self-heal)

Mode: inline (single context: one new script + installer tool loop + docs).
Session patdabney/20260929-02 (reopened). Predecessor bundle: comms-git-01 (hook, bff5be1).

## What changed (this commit, work/agent-runbook)
- `comms-sync` (new, runbook root): import (pull --ff-only + hook self-heal; divergence
  → refuse with the 4-step rename recipe), export (self-heal → commit-if-needed →
  push --atomic), remote (wire after ls-remote reachability; refuses an existing
  different URL), status (branch/ahead-behind/dirty/hook parity).
- `install.sh`: comms-sync rides the SAME PATH gate as scaffold/migrator; doctor's
  tool-parity loop now covers it.

## Proof obligations vs artifacts
| Obligation | Artifact | Result |
| --- | --- | --- |
| two clones, export from A, import into B, converge | 01-export-import.json | PASS (+ real GitHub round-trip b663cfe) |
| same date-seq divergence → refuse with recipe; recipe reconciles | 02-divergence.json + diverge.out | PASS (v2 recipe) |
| clone w/o hook self-heals on import AND export; healed node still refuses leaks | 03-self-heal.json | PASS host + bash 3.2 |
| status accurate; remote refuses diff URL / unreachable; import names hatch | 04-status-remote.json | PASS |
| bash 3.2 flow | 05-bash32-docker.json + unit2-bash32.txt | PASS (CONVERGED_a74a2a6) |
| regression: 28-assertion gate green host + b32 | run post-commit | (run below) |

## Gate notes / design deltas vs the map
- The rename recipe grew a step the map's sketch lacked: after moving the colliding
  folder aside, the node's own divergent COMMIT must be dropped (`reset --hard
  origin/master`) before the ff-pull — otherwise the push still fails with the commit
  stranded in history. Validated end-to-end both orders; the refusal prints the
  corrected 4-step recipe and never executes it.
- `--resume` pairing requires the enclosing layout (comms/ inside its folder): a
  standalone transport clone refuses the resume step (import itself completed) with
  honest instructions. session-start.sh anchors its root at comms/..; standalone
  clones are transport artifacts, moved into the folder before resuming.
- comms-sync's hook self-heal resolves the source like unit-1's migrator: scaffold
  heredoc if bundled, else the comms tree's tracked hooks/pre-push (one resolver).
- Intentional firing held: no automatic behavior anywhere; refusals name hatches.

## NOT done (per intent NOT-list)
- No `clone` subcommand (documented recipe: git clone + migrate; build on second-node onboarding).
- No doctor changes beyond the tool loop entry; no merge/rewrite tooling.

## Verdict
PASS. Regression gates re-run post-commit below; push offer to operator per finish line.