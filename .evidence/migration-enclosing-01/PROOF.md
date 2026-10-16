# PROOF — migration-enclosing-01 (2026-10-16)

Mode: inline unit, no delegation. Report-first reconcile tool + installer wiring.

## Result: PASS — 30/30 proof arms (proof.sh in this dir), gate 33/33 ×2, bash:3.2 ×3

| # | Obligation | Result |
| --- | --- | --- |
| 1 | junk all-current: every verdict `current`, rc 0, zero mutation | PASS — scaffold-built fixture, report (tree md5 stable) + `--apply` no-op (tree md5 stable) |
| 2 | stale fixture → named verdicts; apply restores | PASS — degraded AGENTS paragraph → `[drift]` + apply restored (Branch policy back, heading preserved, .bak written); rm'd hook → `[missing]` + re-stamped executable; stale session-start.sh → `[drift]` + replaced; README `[current]` (tree = live-owned per design decision below) |
| 3 | operator-modified AGENTS: refuse / force / .bak | PASS — live-added paragraph → `operator-modified`; `--apply --only agents` rc 1, REFUSED names hatch, live file untouched; `--force-section` rc 0 with .bak sibling |
| 4 | refusals name hatches | PASS — non-enclosing dir rc 1 + "not an enclosing folder"; unknown class rc 1 + name |
| 5 | unsealed-draft: report works, apply refuses | PASS — rc 0 report; apply rc 1 "seal first (…/session-end.sh …)" |
| 6 | dirs class stamps missing tree dirs | PASS — prior-art + work stamped |
| 7 | comms rollback commit | PASS — reconcile commit `fd54e96 → 98bd814`-class on degraded fixture; message names `scaffold@<sha>`; carries session-start.sh |
| 8 | gate regression | PASS — 33/33 live agent-runbook-next root; 33/33 junk scaffold build |
| 9 | bash 3.2 | PASS — `bash -n` clean: migrate-enclosing-folder.sh, install.sh, scaffold |
| 10 | installer + doctor | PASS — classic install stamps `~/.local/bin/migrate-enclosing-folder.sh`; doctor "nothing missing, nothing drifted"; installed copy smokes green against the live folder (resolves the installed scaffold sibling per the ladder) |

## Design decisions made during implementation (recorded, not re-litigated)

1. **README class = live-owned identity.** Rendering the README with the live
   folder's own tree/PURPOSE makes the render identical to a curated README by
   construction — tree drift is indistinguishable from curation. Boring choice,
   per INTENT's refuse-to-guess: verdict is only `current` (render-equal) or
   `operator-modified` (`--force-section` gate); the tool NEVER clobbers README.
2. **AGENTS class = scaffold-owned body.** Only the slug heading is live-owned.
   Verdict split: live lost scaffold lines → `drift` (apply restores); live has
   non-derivable additions → `operator-modified` (`--force-section`).
3. **Heredoc rendering is TOKEN REPLACEMENT, not eval.** `eval` on a rendered
   heredoc EXECUTES backticks/$(…) inside the body (proven live: `` `./comms/…
   ran `` in this session). AGENTS tpl: one `<folder-slug>` token. README tpl:
   three tokens via -v/awk with octal-built strings (no shell quote ladders).
4. **extract() = single awk pass.** The 2-stage `awk | awk` SIGPIPEs (rc 141)
   under pipefail when the right side exits at the terminator — killed applies.
   Also: `-v` assignments must precede the program (they evaluate at file-open,
   AFTER BEGIN — the null-string getline failure this produced).
5. **Fixed-string markers via index() everywhere.** awk `-v`/ENVIRON munge
   backslash escapes (`\$` → `$` + warning) — regex ladders die there; index()
   needs the literal bytes only.
6. **Unsealed check glob must skip `comms/templates/`** — the template carries
   the SEAL boilerplate; the first fixture run died on its own template.
7. **Fixture honesty:** degrading a fixture's comms tree leaves it dirty vs its
   own git; the tool's mixed-state gate REFUSES by design — the proof commits
   the degraded state first.

## Files touched
- migrate-enclosing-folder.sh (new, runbook root)
- install.sh (2c PATH-gate block, doctor dexec row, uninstall line)
- README.md (tool-tree row), ROADMAP.md (unit row)
- .evidence/migration-enclosing-01/ (INTENT.md, PROOF.md, proof.sh, run outputs)

## NOT done (per intent NOT-list)
- No scaffold/session-script logic changes (byte-parity untouched — gate green).
- No remote wiring/pushes; no auto-migration sweep; no session-folder mutation.