# INTENT — prior-art-refresh-01 (20261014-02)

## Problem
`prior-art/` repos go stale between sessions; an agent referencing one reads
last-fetch state, not the latest. Operator ask (preamble.txt 20261014-02):
session-start should fetch/git-pull each prior-art repo from origin so references
land on the latest and greatest.

## Proposed outcome
Live `comms/session-start.sh` gains a fail-soft prior-art refresh before the intro
print. Per prior-art repo that is a git repo:
- no `origin` remote → status line "no origin remote — left as-is", skip
- fetch origin (output captured, never printed raw)
- dirty working tree → "DIRTY — fetch done, pull skipped"
- ff-only pull `origin HEAD` OK → "refreshed (<head oneline>)"
- else → "DIVERGED from origin — fetch done, ff-pull refused"
No repo is mutated beyond a fast-forward; divergence is named, never resolved, by
the script. Prior-art remains read-only reference.

## Proof obligations
1. refreshed arm: behind clone fast-forwards, head == origin head after run
2. diverged arm: local head kept; refusal line printed; rc still 0
3. dirty arm: fetch only; tree + head untouched; DIRTY line printed
4. no-remote arm: left as-is line; no fetch attempt
5. empty prior-art / no non-repo dirs: intro unchanged; rc=0; non-repo dir skipped
6. regression duty: comms lifecycle gate 32/32 host + bash:3.2 docker
7. mirror: scaffold session-start heredoc == live script, byte-parity (cmp)
8. doc duty: comms/README.md + scaffold README heredoc carry the refresh bullet

## Invariants
- prior-art files never modified except by git ff
- session-start never fails or exits nonzero because of prior-art state
- every skip names why in the intro (loud, not silent)

## Affected systems
- live comms/session-start.sh (this enclosing folder)
- scaffold/new-enclosing-folder.sh session-start heredoc + README heredoc
- comms/README.md (live + scaffold mirror)

## NOT-list
- No rebase/force/merge resolution of divergence (named, never auto-fixed)
- No push of any kind from prior-art clones
- No non-git prior-art content sync (rsync etc.)
- No skip flag for session-start (fail-soft covers every failure class)
- No session-end changes
- No doctor changes

## Open questions
None — resolved: pull pinned to `origin HEAD` (tracking upstream may be unset;
found live in the diverged-repo fixture test, fixed in-unit).