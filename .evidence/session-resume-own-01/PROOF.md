# PROOF — session-resume-own-01

Mode: bugfix. Repro on the pre-fix scripts → failing gate → smallest fix →
gates re-run. Map text that called the cross-user maximum "canonical" is
updated in the same diff.

## The bug

`session-start.sh` resumed from the highest `YYYYMMDD-NN` across every user.
User name broke a date-seq tie. Seal time was not consulted. The header said
"the caller's newest first"; the loop took the last entry of the global sort.
`session-end.sh` then printed "it is now the canonical state" for whatever it
had just sealed.

Pre-fix transcript: `01-red-gate.txt` (the final assertions, pointed at a
scaffold built from main `e399eac` before this diff). `29 pass, 16 fail`.
The four reported cases, in that file:

| Case | Pre-fix result |
| --- | --- |
| A | `dustinwarner` (earlier name, later mtime) resumes from `patdabney/20261021-01`. Pat resumes from his own file and the intro does not list Dustin — the tie-break, not a per-user rule. |
| B | Pat, who has `-01` and `-02`, resumes from `dustinwarner/20261021-03`. |
| C | Sealing `dustinwarner/20261020-01` prints "it is now the canonical state." The next fresh start resumes from `patdabney/20261021-01`. |
| D | Pat's unsealed `20261021-02` warns, and Dustin resumes from `patdabney/20261021-01` instead of his own sealed `20261020-01`. |

Two extra fails in that transcript are the new sentence, not a wrong target:
scenario 12 already resumed from `vz`'s and `wdr`'s own sealed files
(`Resuming from sealed handoff: comms/vz/...` and `.../wdr/20261019-01/...`).
The gate now requires `Resuming from your sealed handoff:`.

## Design

Fresh start resumes from the caller's own newest sealed handoff. Other users'
newest sealed handoffs (one per user) are printed as reading. A caller with
no sealed handoff starts a first session and does not adopt a colleague's
file; those files stay on the reading list. Another user's draft does not
warn. The caller's own newer draft still warns, and the fallback is the
caller's own newest sealed handoff, not a colleague's newer one.

`session-end` names that owner's newest sealed handoff, or names the newer
sealed handoff that remains. It does not say "the canonical state."

`--resume` still opens the same folder it opened before (including the
cross-user continuation when the caller has no session folder at all).

## Fence

`.evidence/session-start-own-sealed-01/INTENT.md` says "No re-sorting of
date-seq ordering or its tie-breaker." This unit respects that. The handoff
sort is still date-seq, then user name. Seal time is still not a key. The
reading-list order check (scenario 11) requires `mw` (oldest), then `zz`,
then `u1`, then `u2` on the same date. A path sort would put `zz` last. What
changed is the resume set: the caller, not every user. The claim this revisits
is "newest sealed anywhere is what the next session resumes from," which is
what made A–D wrong, and which scenario 7 used to require.

## Gates

| Run | Interpreter | Result |
| --- | --- | --- |
| `01-red-gate.txt` | host bash 5.2, pre-fix scripts | 29 pass, 16 fail |
| `02-gate-bash53.txt` | GNU bash 5.3.0, `PATH=/opt/bash-5.3/bin` so the harness's inner `bash` is 5.3 | 45 pass, 0 fail |
| `03-gate-bash32.txt` | GNU bash 3.2.57, same PATH pattern | 45 pass, 0 fail |
| `04-gate-host.txt` | GNU bash 5.2.21 (this machine) | 45 pass, 0 fail |

Versions and `cmp` results: `05-mirrors.txt`. Heredoc extraction matches the
scaffolded `session-start.sh`, `session-end.sh`, and `glow-pane.sh` (also
byte-identical to the repo copy). Enclosing `AGENTS.md` body matches the
heredoc after the slug line. shellcheck on the extracted scripts reports only
the pre-existing `SC2012` (`ls` in the omp-session probe) and `SC2015` (the
old draft-candidate `&&`/`||`).

## Verdict

A–D fail on the old scripts and pass on the new ones, on bash 5.3 and bash
3.2. The date-seq comparator was not re-sorted. `session-end` no longer calls
a sealed file the canonical state for every user.
