# PROOF — shared-comms-01 (user-keyed comms layout, shared-context box)

Mode: inline (no delegation). Single context: comms protocol scripts + scaffold
mirror + one test harness. Operator watching in-session.

## What changed (commit 0748fe8 in work/agent-runbook)
- `scaffold/new-enclosing-folder.sh` heredocs: session-start.sh + session-end.sh
  reworked for `comms/<user>/<YYYYMMDD>-<NN>/`; comms/README.md + AGENTS.md updated.
- `comms-lifecycle-test.sh`: 14-assertion two-fake-user lifecycle harness (new).
- `intent-shared-comms.md`: unit contract (proof obligations, NOT-list).

## Behavior contract now proven
1. Fresh start: guard scopes to the CALLING user; another user's unsealed session
   never blocks (evidence 01 steps 1-3).
2. Resume: own-newest first (same-day, cross-midnight), else newest sealed ACROSS
   users (evidence 01 step 7; real-users artifact 04).
3. Discovery: depth 3, ordered by date-seq across users, never by user name
   (draft-skipping scenario exercised manually + in lifecycle step 7).
4. Seal: bare arg = caller's own newest-today; `<user>/<date-seq>` = cross-user
   salvage hatch (evidence 01 step 8); incomplete handoff still fenced (step 5,
   artifact 04).
5. Byte parity (live canonical ↔ scaffold mirror): session-start.sh, session-end.sh,
   comms/README.md cmp-equal; AGENTS.md body equal after slug heading (02).
6. bash 3.2 (stock macOS interpreter class, bash:3.2 docker): full 14/14 lifecycle
   green from a freshly scaffolded folder (03). No `;&` fallthrough anywhere.
7. Two REAL OS users + shared group + setgid dirs (04): session creation and
   cross-user fencing behave identically to the fake-user runs.

## Gate notes
- Host lifecycle run twice consecutively (rerun-idempotent; state reset in-test).
- A false failure in the harness itself was traced: `find` exits 1 on a missing
  starting point even with stderr suppressed; with pipefail that killed whole
  pipelines under `set -euo pipefail`. Fixed with `{ find ... || true; } | ...` —
  a real portability bug the harness caught in the scripts, now documented in
  the scripts' comments.
- Harness's own handoff-filler is bash-3.2 portable (awk state machine, no python)
  so the same harness proves both interpreters.

## Verdict
PASS. Open item carried (operator-time, not code): artifacts/ sensitivity on the
shared box — group-readable by design; laptop-only material must be named before
first rsync.
