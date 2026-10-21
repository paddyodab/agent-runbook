# Intent — fresh start resumes from the caller's own newest sealed handoff

Unit: `session-resume-own-01`. Door: bugfix. Map change is in this diff because the
bug is a lie in the protocol text ("newest sealed anywhere is canonical"), not
only in the selector.

## Problem (the repro)

`comms/session-start.sh` (the copy stamped by the heredoc in
`scaffold/new-enclosing-folder.sh`) picks the resume handoff as the highest
`YYYYMMDD-NN` folder name across **all** users. The user name breaks a date-seq
tie, alphabetically. Seal time is ignored. The header comment says "the caller's
newest first"; the code does not do that.

Reproduced on main at `e399eac` (fresh scaffold, no omp), users `patdabney` and
`dustinwarner`:

- **A.** Both have sealed `20261021-01`. Dustin's file is newer by mtime.
  Dustin's fresh start resumes from `patdabney/20261021-01`, because `patdabney`
  sorts after `dustinwarner`. Pat's fresh start resumes from his own handoff
  only because his name sorts later.
- **B.** Pat has `-01` and `-02`, Dustin has `-01` through `-03`, same day, all
  sealed. Pat's fresh start resumes from `dustinwarner/20261021-03`.
- **C.** Pat's `20261021-01` is already sealed. Dustin then seals `20261020-01`.
  `session-end.sh` prints "it is now the canonical state." Dustin's next fresh
  start ignores that handoff and resumes from Pat's `20261021-01`.
- **D.** Pat has sealed `20261021-01` and an unsealed `20261021-02`. Dustin has
  his own sealed `20261020-01`. Dustin's fresh start warns that "the newest
  handoff is an unsealed draft" and resumes from Pat's sealed handoff.

## Root cause

The classification loop sorts every handoff by date-seq then user name and
treats the last entry as the resume source (`ALL_BUT_OWN`, last index). A
draft in that last slot warns and walks backward to the previous sealed entry,
still across users. `session-end.sh` then claims the file just sealed "is now
the canonical state," which that selector does not guarantee (an older date-seq
never becomes the global maximum, whatever the clock says).

## Design

Fresh start resumes from the **calling user's own newest sealed** handoff.
"Newest" stays date-seq order inside that user's folder. Other users' newest
sealed handoffs (one per user, same comparator) are printed in the reading
manifest as shared context. They are not the resume source.

A caller with **no sealed handoff of their own** starts a first session. They
do not adopt a colleague's handoff as prior state. Colleagues' newest sealed
handoffs are still listed as reading, so shared context stays visible. (The
explicit `--resume` hatch, when the caller has no session folder at all, still
opens the newest sealed handoff across users. That is continuation into an
existing folder, not the default fresh start. Its folder choice is unchanged.)

Another user's unsealed draft does not warn and does not change the resume
source. The caller's **own** newer unsealed draft still warns, and the resume
falls back to the caller's own newest sealed handoff — not to a colleague's
newer sealed one.

`session-end.sh` stops saying "the canonical state." After the seal it says
this file is that owner's newest sealed handoff (next session for that owner
resumes from it; other users resume from their own), or, if the owner already
has a newer sealed handoff, it names the one that remains.

## Fence from session-start-own-sealed-01

That unit's NOT-list says "No re-sorting of date-seq ordering or its
tie-breaker." **This unit respects that fence.** `list_sessions` / the handoff
sort stay date-seq primary, user name only after date-seq equality. Seal time
is still not a key. What this unit revisits is the other claim in that intent
and in `comms/README.md`: "newest sealed anywhere wins" as the **resume
source**. That claim is what makes A–D wrong. The comparator still defines
"newest" within a user and the order of the reading list. It no longer elects
one cross-user resume target. Lifecycle scenario 7 (a user with no handoff
resumes from the other user's sealed file) encoded the claim being revisited;
its expected text changes in this diff.

## Proof obligations

1. Cases A–D fail on the pre-fix scripts (saved transcript) and pass after.
2. A caller with no sealed handoff does not resume from anyone; other users'
   newest sealed handoffs appear as reading (scenario 7).
3. Reading-list order is still date-seq, user-name tie-break — a late-alphabet
   older handoff does not sort after a newer one (the path-sort regression).
4. Own newer unsealed draft falls back to own sealed, not to another user's
   newer sealed, and still warns.
5. Mirrors byte-identical: heredoc extraction `cmp`s the scaffolded
   `session-start.sh`, `session-end.sh`, and `glow-pane.sh` (repo copy).
6. Regression: full lifecycle gate green on bash 5.3 and bash 3.2.

## NOT-list

- No change to the date-seq sort or the user-name tie-breaker.
- No ordering by mtime / seal time.
- No change to which folder `--resume` opens (cross-midnight and cross-user
  hatches).
- No change to seal completeness, the ledger, templates, or the SEAL marker.
- No re-sort of scenario 12's single-user "own sealed participates" behavior
  beyond the resume sentence, which now says "your" sealed handoff.
- No edits to prior units' evidence.
