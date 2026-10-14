# INTENT — preamble-pane-sealed-01

## Problem

Operator-visible this session (patdabney/20261014-03, post-seal): re-running
`comms/session-start.sh --resume` re-opened the "preamble vi" editor pane.
Root cause: the idempotency guard matches `pane list` output for
`.label == "preamble vi"`, but this herdr build does NOT surface a `label`
field in pane list/get (verified: 9 keys, none label — renames show nowhere
queryable). The guard is blind → no duplicate detection ever fires.
Additionally the operator's preference: once the session is SEALED, resuming
it should not open a preamble window at all (the ask was consumed at session
start; a sealed session resumes into append mode, not ask-composition mode).

## Proposed outcome + invariants

In `herdr_preamble_pane_setup` (live comms/session-start.sh canonical; scaffold
session-start heredoc mirrors byte-parity):

1. **Sealed-session skip (the operator's rule):** when the resolved session
   folder's handoff exists and is already sealed (no SEAL marker), return 0
   BEFORE any pane work — a sealed session never opens the preamble pane.
2. **Duplicate guard made real:** replace the label-based jq filter with a
   cwd-based match — `pane list` → for each pane, `cwd == <the session folder>`
   (bash 3.2-safe: no jq map loops; a plain grep on the pane's own cwd path
   shape) → if any pane's cwd is the session folder, skip (a pane already sits
   on this folder; a second split would duplicate).
3. Fail-soft everywhere preserved (missing herdr/jq/pane → silent skip); the
   explicit opt-out `COMMS_NO_PREAMBLE_PANE=1` and foreground-editor skip stay.

## What "good" looks like (proof artifacts)

`.evidence/preamble-pane-sealed-01/`:

1. `01-guard-arms.json` — in a junk parent inside herdr (or equivalent
   observable stub): DRAFT session + hook → pane opens (unchanged behavior);
   SEALED session + hook → no pane; duplicate-panes arm via cwd-match stub.
2. `02-mirror-byte-parity.json` — scaffold session-start heredoc re-spliced
   from live, cmp at anchored bounds.
3. PROOF.md — verdict + regression (lifecycle 32/32 host + bash:3.2).

## Bounded contexts

- live `comms/session-start.sh` (herdr_preamble_pane_setup body only)
- scaffold `new-enclosing-folder.sh` (session-start heredoc + comms/README
  heredoc bullet IF text changes — otherwise NOT touched)
- ROADMAP unit record; this INTENT.

## Constraints

- bash 3.2-safe; herdr pane API only (no new herdr server coupling).
- Mirror contract: live canonical; scaffold splice cmp-verified.

## Open questions

- None blocking. (Operator preference recorded: prefers NEW conversations over
  resume generally — the sealed-skip respects this: sealed resume gets NO pane.)

## NOT-list

- No glow-pane changes; no session-end changes; no `--resume` flow changes
  beyond the pane hook; no label/report-metadata usage (fields absent in this
  build — cwd-match is the real guard); no COMMS_NO_PREAMBLE_PANE semantics
  change; no scaffold README edits (hook bullet already describes behavior at
  the level that stays true: "opens in a pane when the session starts").

## Next steps

- Edit live hook → junk-parent arms → splice + cmp → lifecycle gate host +
  bash:3.2 → commit (no push; operator PR gate per standing fence).