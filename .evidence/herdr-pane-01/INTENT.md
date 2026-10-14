# INTENT — herdr-pane-01

## Problem

The preamble road-test (agent-runbook-next comms 2026-10-14, operator ask in
preamble.txt) proved live: (a) session-start should open the stamped preamble in a
herdr editor pane so composing the ask is typing, not TUI-composing; (b) markdown
assessments/mind-notes should render in a `glow:` pane. The prototype lives in the
enclosing folder's comms/ and dies with that folder unless the product repo
(work/agent-runbook = agent-runbook) ships it — scaffold stamps for every future
enclosing folder, installer/PATH-gate for every deployment, migrator refresh for
existing folders.

## Proposed outcome + invariants

- Scaffold stamps the hook + `comms/glow-pane.sh` + `work/`; byte-parity with the
  live comms is the standing gate (mirror contract: live canonical, scaffold = the
  embedded form; cmp on every build).
- glow-pane.sh installs via the same PATH gate + refuse-fence as its four siblings.
- Migrator refreshes glow-pane (and scripts) for old folders from the installed
  scaffold — the installer's refuse-fence guarantees that scaffold is current.
- Fail-soft everywhere: missing herdr/jq/editor/glow never blocks session start;
  outside herdr glow-pane renders to stdout.
- Idempotency: no duplicate preamble panes on --resume; glow re-render replaces its
  own pane; migrator rerun is a no-op.
- NEVER automatic firing on the prose tier: glow-pane runs only when invoked; the
  preamble pane opens only at session-start.

## Affected systems / bounded contexts

- scaffold/new-enclosing-folder.sh (stamp context)
- glow-pane.sh (new tool), install.sh (install+doctor contexts)
- migrate-user-comms.sh (refresh context)
- README/machine.md/ROADMAP (doc context); AGENTS block (standing behavior)

Proof artifacts before code: this INTENT + ROADMAP unit (written before edits;
PROOF.md completed after the gates ran).

## NOT-list

- No auto-open of arbitrary files (preamble at session-start + explicit glow-pane
  invocations only).
- No session-end changes; no herdr server management; no new editor probe list
  beyond vi/nvim fallback; no comms-sync/artifacts-sync/fresh-box changes.
- No plugin/extension into herdr itself (pane API is the integration surface).

## Constraints

- bash 3.2-safe (no mapfile/assoc arrays/regen params); set -euo pipefail clean.
- Mirror contract: every spliced heredoc extracted mechanically from live, cmp
  verified; scaffold builds must reproduce the live comms byte-for-byte.

## Open questions

- None blocking. (Remote-push of both repos intentionally withheld pending the
  operator's explicit go — standing fence.)

## Next steps

- Lanes: none needed (single-owner mirror unit).
- Future unit candidate (not this one): doctor comms-folder sweep (existing unit 4)
  may add the preamble-pane presence check per enclosing folder.