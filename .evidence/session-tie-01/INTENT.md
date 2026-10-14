# INTENT — session-tie-01

## Problem

The operator's overwatch question (preamble, patdabney/20261014-03): can a comms
session folder be tied to (a) the agentic session that produced it and (b) the
commits in the WORK repo it advanced — not the comms transport commits. Feasibility
was probe-proven live this session: omp transcripts live at
`~/.omp/agent/sessions/<cwd-slug>/<timestamp>_<uuid>.jsonl` with an in-band session
record (id, cwd, ISO timestamps); `history.db` indexes session_id→title; the
archive device lists sessions as JSON. Today the tie is only DERIVED (cwd-slug +
time-window containment). Nothing in comms/ is stamped with the session id, and the
work-repo commit ties live only in handoff prose — an overwatch process has to
re-derive everything by convention.

## Proposed outcome + invariants

- **Live canonical change:** `comms/templates/session-handoff.md` gains a
  "How to resume" slot-0 line — `0. omp agent session id: <uuid or "(none —
  agent-cooperative stamp, best effort)">` — and session-start.sh's printed intro
  gains a `Session id: <current>` line so the operator can paste it into the
  preamble/handoff without asking the agent. Template comment explains WHERE the
  id comes from (omp transcript JSONL under ~/.omp/agent/sessions/<slug>/) and
  that overwatch can also derive it from cwd-slug + the session start time in the
  folder name when unset.
- **Current session stamped:** this session's handoff (20261014-03) carries its
  real id `01a13bae-5c59-7762-ab14-cf832b3c02d3`.
- **conversation.md Threads + Decisions** record the corrected feasible-tie set:
  work-repo commit ids are the load-bearing tie; comms-repo commits are transport.
- **Mirror contract honored:** scaffold templates heredoc re-spliced from live
  templates, cmp byte-parity at exact heredoc bounds; session-start heredoc
  re-spliced from live session-start.sh, cmp at exact bounds (373–681 was the
  prior-art-unit bounds — re-grep after splice; grep `cat >` line and terminator).
- Invariants: intro line appears on both fresh and --resume paths; template stamp
  never breaks session-end's section-completeness (the awk fence ignores lines
  after `0.`? NO — the section line "0. omp agent session id: …" is content; it
  does NOT count as "How to resume" content because it starts with `0.` not a
  word? CHECK: the completeness awk requires a non-blank, non-comment line NOT
  matching the boilerplate (path/to/file|ONLY these:|Evidence dirs). A stamped
  template would then still fail "How to resume" as empty — GOOD: the id line is
  not boilerplate exclusion, it is real content, but the fence treats presence of
  ANY non-boilerplate line as content, which would make "0. omp agent session
  id: …" satisfy the empty-fence. That is WRONG for an untouched template — so the
  exclusions list must grow `0\. omp agent session id` … but a FILLED handoff
  still needs more than the id. Decision: the session-id line is added to
  section-end boilerplate excluders in session-end.sh, so an untouched "How to
  resume" still refuses to seal.

## What "good" looks like (proof artifacts)

`.evidence/session-tie-01/`:

1. `01-template-stamp.json` — live template stamped (grep id slot), scaffold
   heredoc cmp byte-parity both bounds, junk-build stamps the id slot.
2. `02-session-tie.json` — this session's handoff carries the real UUID;
   transcript at ~/.omp/agent/sessions/..._<uuid>.jsonl contains that session
   record; the tie handoff→transcript is grep-verifiable one-line.
3. `03-seal-fence.json` — untouched stamped template HANDOFF still refuses to
   seal ("How to resume (empty)"); filled handoff seals (existing suite also
   covers: 32/32 must stay green).
4. `PROOF.md` — verdict + regression duty (lifecycle gate 32/32 host + bash:3.2).

## Bounded contexts

- live comms/templates/session-handoff.md (this enclosing folder)
- live comms/session-start.sh (intro print only)
- live comms/session-end.sh (boilerplate-exclusion list only)
- scaffold/new-enclosing-folder.sh: templates heredoc (session-handoff) +
  session-start heredoc mirror
- comms/README.md heredocs? NO — README documents what goes where; the id-line
  is a handoff-internal convention. README heredoc is NOT touched (NOT-list).
- ROADMAP.md (unit record), this INTENT.

## Constraints

- bash 3.2-safe in all shipped scripts (no mapfile/negative-index/in-place sed).
- Never automatic on the prose tier (map-level fence): the session id is STAMPED
  where the agent cooperates, and DERIVED where it doesn't; overwatch never needs
  agent cooperation to exist.
- Mirror contract: live canonical; scaffold extracts mechanically, cmp gate.

## Open questions

- None blocking. (Work-repo commit ids recorded in handoff prose remain the
  work-repo tie; no new tooling ties them — overwatch reads what's already there.)

## NOT-list

- No overwatch agent/tool design or build (operator explicitly deferred).
- No session-end auto-fill of the uuid (agent-cooperative, best-effort by hand);
  no history.db/schema changes; no agent.db changes; no omp config changes.
- No comms/README.md changes (doc duty lands in the template comment itself).
- No comms-sync/artifacts-sync/fresh-box/sandbox changes; no install.sh/doctor
  changes (scaffold ships via the PATH-gated refuse-fence already).
- No ROADMAP governance changes.

## Next steps

- Live edits (template, session-start, session-end) → splice scaffold heredocs →
  cmp gates → junk-build stamp check → seal-fence arm → lifecycle 32/32 host +
  bash:3.2 → commit on feature/session-tie-01.