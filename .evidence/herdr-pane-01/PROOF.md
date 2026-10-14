# PROOF — herdr-pane-01 (herdr pane surfaces: preamble editor pane + glow viewer)

## Mode

Inline unit (mirror contract: live prototype → product repo); no delegation. Prototype
was road-tested live first (session patdabney/20261014-01, agent-runbook-next comms @
3a8ad3e), then spliced mechanically into the scaffold heredocs.

## What was changed

- `glow-pane.sh` (new tool, runbook root): byte-copy of the live prototype, PATH-gated
  install exactly like comms-sync/fresh-box/artifacts-sync (refuse-fence, mktemp-mv,
  exec bit).
- `scaffold/new-enclosing-folder.sh`: session-start heredoc + comms/README heredoc
  spliced from the LIVE files (python extract, not transcription); new glow-pane heredoc
  placed mechanically from the live file; scaffold stamps `work/` (edit-copies tier);
  final echo lines mention glow-pane + work.
- `install.sh`: §3 PATH-gate block (GLOWSRC/GLOWDST), doctor dexec entry, uninstall line.
- `migrate-user-comms.sh`: three fixes/extensions —
  1. `resolve_scaffold_source` gained the installed-copy arm (`$HERE/new-enclosing-folder.sh`):
     on a deployed box (~/.local/bin, no scaffold/ sibling) the installed scaffold IS the
     current mirror; old folders now get refreshed scripts too.
  2. `extract()` terminators made parametric (`SCRIPT_EOF` per script, `GLOW_EOF` for
     glow heredoc) + glow extraction cmp-verified against the repo's glow-pane.sh.
  3. install loop covers glow-pane (byte-refresh when the tree's own copy is absent).
- runbook `AGENTS.md` marked block + enclosing AGENTS heredoc: mind-notes display line
  (`glow-pane.sh`); live ~/.omp/agent/AGENTS.md carried it since the road test — installer
  cutover now makes installed == repo byte-equal.
- Doc duty: README tool list (glow-pane entry), machine.md scaffold row, ROADMAP unit.

## Proof obligations vs results

| Obligation | Result |
| --- | --- |
| junk-parent scaffold build → ALL protocol files + glow-pane.sh byte-identical | PASS ×3 builds (hp2, hp3, hp4); AGENTS modulo slug PASS; work/ created PASS |
| lifecycle gate (regression duty) | 32/32 host (hp2, hp3, hp4); 32/32 docker bash:3.2 (hp3, hp4; git+grep provisioned per comms-git-01) |
| glow-pane stdout fallback outside herdr | PASS (env -u HERDR_ENV → rendered markdown) |
| glow-pane live pane mechanics | PASS (road test: pane split/rename/run/close, idempotent re-render, process-info editor check) |
| migrator glow refresh, old folder | PASS scaffold-mode + installed-copy mode: byte-identical; idempotent rerun "already current" |
| installer cutover on this box | PASS: glow-pane + migrator + scaffold refreshed, AGENTS block refreshed; doctor then reported "nothing missing, nothing drifted" |
| shellcheck | glow-pane.sh rc=0 clean; install.sh clean; migrator/scaffold findings == pre-existing count (3, unchanged by this unit) |

## Gate notes (real bugs caught by the proof, both fixed in-unit)

1. **Migrator over-extraction** (found by byte-compare of the migrator-refreshed copy):
   `extract()` terminated only on `SCRIPT_EOF`; the glow heredoc ends `GLOW_EOF`, so the
   extraction ran to end-of-file and swallowed the hook comment block + AGENTS heredoc
   (11289 bytes vs 2334). Fixed: terminator is a parameter; extraction additionally
   cmp-verified against the repo's glow-pane.sh so future scaffold-format drift refuses
   loudly instead of installing a junk copy.
2. **`set -u` unbound in pipeline-in-function**: `awk -v t="$t"` in the second arm of the
   extract pipeline expanded shell var `t` (unbound) instead of the function's `$2` —
   only visible under `set -u` + `set -euo pipefail` (the migrator's standing flags).
   Fixed: pass `"$2"` directly. Lesson: a parametric value must not re-reference itself
   through the shell; a pipeline inside a function with `set -u` is a trap — test the
   actual invocation shape.
3. **Comms-tree fallback blind spot** (design gap, found by test): installed migrator on
   a deployed box resolved "comms-tree mode = nothing newer locally," which stopped being
   true once the installer started refreshing `~/.local/bin/new-enclosing-folder.sh`.
   The installed-copy arm closes it.
4. **Live glow-pane.sh had no trailing newline** — byte-parity gate surfaced it (same
   class as the 20260908-01 cmp finding #9); fixed both live and product copies.

## Evidence locations

- Junk builds: /tmp/junk-hp{2,3,4} (ephemeral; results recorded here).
- Cutover state on this box: ~/.local/bin/glow-pane.sh == work/agent-runbook/glow-pane.sh
  (cmp clean); installed migrator == worktree; doctor green.
- Prior live proof (prototype): the operator ASK thread + commit 3a8ad3e in
  agent-runbook-next/comms.