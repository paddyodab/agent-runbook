# PROOF — session-tie-01

Mode: inline (single-owner mirror unit, no lanes). All claims executed live this session.

## Artifacts

- `01-template-stamp.json` — scaffold build from the feature-branch scaffold into a
  junk parent stamps `0. omp agent session id:` into the stamped handoff template
  (grep hit, line 22); intro prints `Session id:` line.
- `02-session-tie.json` — LIVE session stamped: this session's handoff carries the
  real omp UUID `01a13bae-5c59-7762-ab14-cf832b3c02d3` + transcript path; the
  transcript JSONL's session record carries the same id (grep-verifiable one line).
- `03-seal-fence.json` — three junk arms, all rc-asserted:
  - ARM A untouched stamped template → `session-end: handoff incomplete:
    ## How to resume (empty)` rc=1 (fence holds).
  - ARM B everything filled EXCEPT How-to-resume left as id-line-only → still
    `## How to resume (empty)` rc=1 — the id line alone cannot satisfy the fence.
  - ARM C id line stamped with a real UUID + filled steps → seals rc=0.
- Mirror gate: scaffold heredocs session-start.sh / session-end.sh /
  templates/session-handoff.md → byte-match vs live (anchored bounds:
  cat> line → terminator line, body+implicit trailing newline == live bytes).
  All three: BYTE-MATCH (see below for the bounds lesson).
- Regression: `comms-lifecycle-test.sh` 32/32 host AND bash:3.2 docker (alpine:3.19,
  `apk add git grep bash`, fixture mounted at /fix — comms-git-01 precedent).

## Found by the unit (fence bug in the intent's design)

The first draft of the slot used TWO lines (`0. omp agent session id: (none…)` /
wrapped continuation `overwatch derives it…`). The continuation line matched
neither the comment exclusion nor its own text → an untouched stamped template
would SATISFY the fence (silent content). Proven by manual awk count before
shipping: post-edit fence rc=0 on the two-line slot (want 1). Fix: slot is
exactly ONE line; the session-end exclusion matches the whole slot
(`0\. omp agent session id`). Both directions proven (untouched rc=1, filled rc=0).

## Notes

- omp's session dir slug rule (reverse-engineered across all 18 populated dirs,
  18/18): `"-"<cwd with $HOME prefix stripped, "/"→"-">`. Session-start uses it.
- The (unknown) fallback is deliberate: on a box with no omp session dir the tie
  derives from cwd-slug + folder time; never a failure (fail-soft).
- Junk cleanup: junk parent's session-end appended junk entries to the live
  ledger — proof runs must set HOME inside the run root (comms-lifecycle gate
  already does; the manual ARMs didn't). Cleaned manually; fixture deleted after.