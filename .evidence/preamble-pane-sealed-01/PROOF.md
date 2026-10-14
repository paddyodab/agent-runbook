# PROOF — preamble-pane-sealed-01

Mode: inline (single context edit: `herdr_preamble_pane_setup` in live
comms/session-start.sh + scaffold heredoc re-splice). No lanes.

## Root cause (verified live)

The duplicate guard matched `pane list` output for `.label == "preamble vi"`.
This herdr build does NOT surface labels: `pane list` panes carry 12 keys
(agent, agent_status, cwd, focused, foreground_cwd, pane_id, revision, scroll,
tab_id, terminal_id, terminal_title, terminal_title_stripped) — no `label`,
no way to query renames. The jq filter matched nothing every time → blind
guard (re-runs always split a duplicate). Reproduced this session: a single
`--resume` verification run opened an unexpected preamble pane (operator saw
it right after session-end).

## What was changed (live canonical, then scaffold mirror)

1. **Sealed-skip (operator rule):** `herdr_preamble_pane_setup` returns 0 when
   the resolved session folder's `session-handoff.md` exists and carries no
   SEAL marker — a sealed session never re-opens the preamble pane; resume of
   sealed history is append mode, not ask-composition.
2. **Real duplicate guard:** label filter → cwd match
   (`.result.panes[] | select(.cwd? == $SESS_DIR)`), which herdr DOES surface.
3. Fail-soft behavior, opt-out (`COMMS_NO_PREAMBLE_PANE=1`), foreground-editor
   skip: unchanged.

## Artifacts

- `01-guard-arms.json` — arms in a real herdr environment (agent pane is the
  invoker; panes verified by id+cwd after each run):
  - ARM1 fresh draft → pane opens (behavior unchanged): 3 → 4 PASS
  - ARM2 same-draft re-run → NO duplicate (cwd guard fires): 4 → 4 PASS
    (note: TWO different draft folders legitimately get one pane each —
    per-folder ask; that is not a duplicate)
  - ARM3 sealed resume → no pane: 3 → 3 PASS (first ARM3 attempt ran the
    pre-fix junk script — script-version trip, re-run with the fixed script)
  - live sealed session (`--resume` on agent-runbook-next): 3 → 3 PASS
- `02-mirror-byte-parity.json` — scaffold session-start heredoc re-spliced
  from live canonical; cmp exact (anchor `cat>` line → `SCRIPT_EOF`);
  heredoc body 18299 bytes == live 18299 bytes.
- Regression: `comms-lifecycle-test.sh` **32/32 host + 32/32 bash:3.2 docker**
  (alpine:3.19, git+grep+bash provisioned; fixture staged by a fresh junk
  build from the FIXED scaffold).

## Gate notes

- `herdr pane close` takes a bare pane id (positional), not `--pane` — probe
  before scripting fixture teardown (the earlier `--pane` form failed silently).
- The heredoc body parity assertion must compare against live content WITHOUT
  forcing a trailing newline (the heredoc terminator supplies the closing \n).
- Script-version trips in junk fixtures: junk folders carry the scaffold-era
  scripts; when testing LIVE behavior, copy the live script into the fixture
  and say so in the evidence — never conclude "fix failed" from a stale script
  (first ARM3 did exactly that before the trace showed the old code).

## Verdict

PASS. Sealed sessions never re-open the preamble pane; draft sessions open
exactly one pane (cwd guard, real this time); mirror is byte-parity; gate
green both interpreters.