# Shared comms — multi-user enclosing folder (shared-context server)

## Problem
The enclosing-folder + comms protocol is single-user: one `comms/<YYYYMMDD>-<NN>/`
sequence, one `~/.agent/learnings.md`. The operator is standing up a shared context on
an AWS box hit by two users (pd, dw; more later) over SSH/herdr. A shared enclosing
folder needs per-user session attribution while keeping ONE canonical cross-user state.

Decisions already made with the operator (2026-09-28):
- Layout: `comms/<user>/<YYYYMMDD>-<NN>/` — structural attribution, per-user sequencing,
  mind notes nest for free (`comms/<user>/<sess>/mind/`), zero bro-mode changes.
- Scaffold: unconditional user-keyed layout (single user = degenerate case, one code path).

## Proposed outcome
`comms/session-start.sh` + `comms/session-end.sh` (and their scaffold mirrors in
`work/agent-runbook/scaffold/new-enclosing-folder.sh`) run correctly under two user
identities on one box:

1. Fresh start scopes the "today is still unsealed" guard to the CALLING user's folders;
   another user's open session never blocks.
2. `--resume` falls back within the calling user's own folders first; only when the
   caller has none anywhere does it fall back to the newest sealed handoff ACROSS users
   (cross-user canonical state is the feature).
3. Handoff discovery reads depth 3 (`comms/<user>/<sess>/session-handoff.md`), ignores
   `templates/`, and orders by the DATE-SEQ tail, never by user name (path sort would
   order `dw/20260928-01` after `pd/20260927-01`).
4. `session-end.sh [<user>/<date-seq>]` accepts a user-prefixed name for the
   cross-midnight/cross-user salvage hatch; bare form resolves the calling user's
   newest-today, else refuses naming the exact command (including the caller's user
   prefix).
5. Ledger entries key on the handoff's absolute path (already true) — per-user handoff
   paths keep delta-append semantics correct across users on one shared HOME? NO —
   ledger stays per-user (`~/.agent/learnings.md` is $HOME-scoped); documented, not
   changed.
6. Scaffold stamps user-keyed folders unconditionally; generated `comms/README.md` +
   `AGENTS.md` describe the `<user>/<date-seq>` layout and the shared-group permission
   contract (setgid dirs, umask 002).

## Proof obligations (verify-comms)
Driven by real script runs in a junk enclosing folder under TWO fake users (proven via
docker multi-user container; see SMOKE table), each as structured JSON in
`.evidence/shared-comms-01/`:

- 01-fresh-two-users.json — u1 fresh start creates `comms/u1/<today>-01/`; u2 fresh
  start SUCCEEDS while u1's session is unsealed (guard scoped), creating `comms/u2/<today>-01/`.
- 02-resume-own.json — u1 `--resume` reopens u1's own newest (same-day + cross-midnight).
- 03-resume-cross-user.json — u2 with NO own folders resumes from u1's newest SEALED
  handoff; refuses loudly if none sealed anywhere.
- 04-seal.json — bare seal resolves caller's own newest; explicit `<user>/<date-seq>`
  seals cross-user (that's the shared salvage path); incomplete handoff still refused.
- 05-byte-parity.json — live scripts in THIS folder cmp-equal the scaffold heredoc
  extractions (mirror contract).
- 06-bash32.json — full two-user lifecycle under bash 3.2 (docker).

## Invariants
- Refuse-to-guess preserved: every refusal names its own hatch with the user prefix.
- Newest-sealed-wins is by DATE-SEQ across users, never by user name.
- Templates + SEAL semantics unchanged; sections list unchanged.
- Single-user folders created BEFORE this change keep working with their existing
  (flat) copies — no migration, no dual-layout code path.

## Affected systems
- `work/agent-runbook/scaffold/new-enclosing-folder.sh` (heredocs: session-start,
  session-end, comms/README, AGENTS.md) + live mirrors in THIS folder's `comms/`
  (live canonical; scaffold derives; cmp gate).
- machine.yml gains the shared-box runtime deps (none new: ssh/systemd are OS-level)
  and the runbook references.

## NOT-list
- No herdr config changes, no machine-add automation (operator runs `herdr machine add`
  on each laptop; skill file documents it).
- No S3/IAM/snowflake work; no omp-remote involvement.
- No changes to handoff section contract or SEAL semantics.
- No migration of existing flat-layout folders.

## Open questions
- (resolved 2026-09-28) Layout A vs B → A. Unconditional vs flag → unconditional.
- (open, operator-at-AWS-time) artifacts/ sensitivity: group-readable on the box by
  default; laptop-only material must be named before first rsync. Not blocking code.

## Next steps
1. Edit live `comms/session-start.sh` + `session-end.sh` (canonical).
2. Mirror into scaffold heredocs (byte-parity via extraction + cmp).
3. Extend sandbox-test-style lifecycle with two fake users (junk folder, docker for
   bash-3.2 + multi-user identities).
4. Write .evidence/shared-comms-01 + PROOF.md.
5. AWS runbook (shared-box section in README or machine.md) + finish-line offer.