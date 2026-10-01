# PROOF — session-start-own-sealed-01

Mode: bugfix door (skill://eng-playbooks/references/bugfix.md), single lane, no
delegation. Repro → intent → red test → smallest fix → gate → real-box analog.

## The bug

`session-start.sh` fresh start (no `--resume`) ignored the calling user's own SEALED
handoffs. Classification loop line `[[ "$rel" == "$USER_NAME/"* ]] && continue`
skipped every own-user handoff, sealed or not, contradicting its own comment
("our own folder's *drafts* never count") and the script header ("the caller's newest
first"). On a single-user box (every prior session is yours), `PREV_SEALED` was
always empty → every fresh start falsely bootstrapped "No prior handoff — first
session". Fired on the real box 2026-10-01: `comms/patdabney/` held three sealed
handoffs; the intro claimed none existed (operator-visible, this session's start).

A second defect in the same loop: the preceding exclusion compared `$rel`
(`<user>/<date-seq>`) against absolute `.../session-handoff.md` paths — dead code —
so the buggy USER skip was doing the current-session exclusion too.

## The fix (scaffold/new-enclosing-folder.sh, embedded session-start.sh heredoc)

- Skip by the actual REL shape: `[[ "$rel" == "$SESS" ]] && continue` — this
  session's own freshly-created handoff only.
- Deleted the dead absolute-path comparison and the `$USER_NAME/*` skip; own-user
  SEALED handoffs now participate as canonical candidates, per comms/README.md
  ("newest sealed handoff anywhere wins").
- +5 net lines, comments explaining why the fold-back happened.

## Artifacts

| File | What it proves |
| --- | --- |
| `INTENT.md` | problem=repro, root cause at line level, proof obligations, NOT-list (sealed pre-fix) |
| `01-repro-before.txt` | pre-fix transcript: junk fixture with own sealed `20260929-01` → intro printed "No prior handoff" (real box analog, byte-shape identical to live 2026-10-01 intro) |
| `02-gate-host.txt` | full lifecycle suite host bash: 32 pass / 0 fail (28 prior + scenario 12) |
| `03-gate-bash32.txt` | same suite under docker `bash:3.2` (GNU bash 3.2.57): 32/0 — portable |
| `04-real-box-analog-final.txt` | post-fix same fixture: "Resuming from sealed handoff: comms/patdabney/20260929-01/session-handoff.md" — repro gone |

## Red → green

- Red: pre-fix script, scenario 12a — `vz` fresh start resumed from `u2`'s handoff
  while `vz`'s own equally-new sealed handoff existed ("own sealed handoff ignored").
- Green: same suite post-fix, host + bash:3.2, `== RESULTS: 32 pass, 0 fail`.
- shellcheck: `scaffold/new-enclosing-folder.sh` rc=0 (was and stays clean);
  `comms-lifecycle-test.sh` warning-set byte-diffed against pre-change baseline —
  delta zero (new lines written to the suite's existing bar; pre-existing 61
  warnings untouched, out of scope per NOT-list).

## Migration to installed copies

`scaffold/new-enclosing-folder.sh` is canonical (repo README: "This repo's copy is
canonical; ~/.local/bin/new-enclosing-folder.sh becomes an installation of it").
This enclosing folder's live `comms/session-start.sh` refreshed via the sanctioned
path: `migrate-user-comms.sh <folder>` (extracts from the scaffold heredoc, cmp +
bash -n gates) → `cmp` against extraction = byte-identical. Not touched this unit:
`~/.local/bin/` installed copies on other boxes (re-migrate on next install re-run;
doctor's scaffold-parity sweep will flag the drift).

## Gate notes

- Baseline before fix: 28/0 on the same fixture (`.git` + hook stamped into the
  fixture comms/ as a real post-scaffold folder has; the comms-as-git assertions
  then run for real rather than skip-counting).
- The gate's own fixture-construction steps use `u2 session-end.sh` to seal fixture
  handoffs (cross-user seal hatch, scenario 8's proven path) — no seal semantics
  changed.

## Verdict

Fix proven: repro-before (01) shows the false bootstrap; repro-after (04) shows
correct canonical resume; regression net 32/0 host + bash:3.2. Scenarios 1–11
unchanged and green (cross-user resume, per-user guard, cross-midnight, seal
refusals, hook fires). Prior unit obligations re-proved by the same run
(regression duty).