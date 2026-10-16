# INTENT — migration-enclosing-01 (20261016-01)

## Problem
`new-enclosing-folder.sh` stamps current protocol artifacts only at CREATION. Every
enclosing folder scaffolded at an older runbook evolution drifts silently: standing
rules (AGENTS.md), folder conventions (README.md), comms protocol scripts, the comms
README, templates, session-start's prior-art refresh + preamble pane + overwatch
hooks, and the comms/.gitignore rules — all evolve, and nothing reconciles live
folders that predate the change. `migrate-user-comms.sh` covers the comms tier
(layout + scripts + templates + hook) but: (a) not the enclosing root (AGENTS.md,
README.md), (b) it mutates immediately with no report mode, (c) no drift verdict
names WHAT is stale. Operator ask (20261016-01 conversation): a migration tool for
existing enclosing folders, full treatment.

## Proposed outcome
`migrate-enclosing-folder.sh` at the runbook root (PATH-gate installed, sibling to
the other dexecs):

1. **Report-first (default).** Render the scaffold's heredocs with the LIVE folder's
   identity — FOLDER from `basename $TARGET`, PURPOSE from live README line 3,
   CONVENTION from the scaffold var — then per artifact, one verdict:
   `current` | `drift (what)` | `missing` | `operator-modified (review)`.
   The live scaffold's dexec sibling (migrate-user-comms.sh) is delegated to, never
   forked — this tool orchestrates; the comms-tier init/hook logic stays there.
2. **`--apply`** mutates only with explicit per-class scope
   (`--only agents|readme|comms-protocol|comms-readme|templates|hook|.gitignore|all`):
   - versioned homes (anything under comms/): apply + `git -C comms` commit whose
     message names the source scaffold version — comms history IS the rollback; no
     .bak files in comms.
   - unversioned homes (root AGENTS.md, README.md): sibling `.bak-<ts>` before
     overwrite; AGENTS refresh preserves the live slug heading line (migrate-
     user-comms pattern); README render keeps live PURPOSE line 3. NEVER overwrite
     text that cannot be derived from the render (operator hand-edits to standing
     sections are a hard stop: verdict `operator-modified`, apply REFUSES that
     section unless `--force-section`).
3. **Refuse-to-guess everywhere**: non-enclosing folder (no comms/session-start.sh)
   → rc 1 with the hatch named; unsealed draft in comms → refuse apply (session
   folders are append-only state, never touched); scaffold heredoc markers missing
   → refuse (format-drift fence, migrate-user-comms pattern); unknown --only class
   → usage, rc 1. Missing prior-art/artifacts/work dirs are STAMPED as dirs (cheap,
   harmless) with a verdict line.
4. **Installed-copy resolution**: same ladder as migrate-user-comms — (a) repo-tree
   scaffold/ sibling; (b) ~/.local/bin sibling installed copies (cmp doctor's dexec
   parity guards those); (c) comms-tree fallback = report only (`current-est source
   is the tree itself`), apply refused loudly rather than mis-migrated.

## Proof obligations (.evidence/migration-enclosing-01/)
1. **all-current arm**: junk scaffold build (current runbook) → report says every
   artifact `current`, rc 0, zero mutations (byte-compare the fixture tree before/
   after; .evidence commit only in runbook repo, not fixtures).
2. **stale arm**: /tmp fixture with a DELIBERATELY outdated AGENTS.md/README/
   comms script (e.g. clause removed) → report names drift per artifact; `--apply`
   with explicit classes fixes; comms changes land as a comms/ commit naming the
   scaffold source.
3. **operator-modified arm**: hand-edit a standing AGENTS paragraph → report flags
   `operator-modified`; `--apply --only agents` REFUSES that section (rc 1) and
   leaves the file untouched; --force-section flips it with the .bak present.
4. **non-enclosing arm**: bare dir, dir without comms/ → refusal names the hatch.
5. **unsealed-refusal arm**: fixture with an unsealed draft → apply refuses (report
   mode still works).
6. **regression duty**: comms lifecycle gate 33/33 host + bash:3.2 (syntax checks
   on the new script + unaffected scaffold); installer doctor includes the new
   dexec parity row (cmp) after cutover.
7. **mirror contract**: migrate-enclosing-folder.sh lives at runbook root; the
   installer PATH-gate block + doctor dexec list extend mechanically (same pattern
   as migrate-user-comms.sh); no heredoc re-splice needed (script is not stamped
   into folders).

## Invariants
- Session folders (comms/<user>/<date>/) are NEVER mutated, moved, or read for
  content beyond existence checks (append-only history stays closed).
- Report mode NEVER mutates (proven by before/after tree hashes).
- Every apply writes its rollback trail (.bak siblings outside comms; comms commits
  inside comms).
- The tool never pushes (standing fence) and never wires remotes (migrate-user-comms
  already refuses; this tool must not either).

## Affected systems
- new runbook-root script; install.sh (classic + doctor dexec rows, uninstall line);
  README.md (tool tree line); ROADMAP unit row. NO changes to scaffold heredocs,
  session scripts, comms tier logic, kit, machine.yml.

## NOT-list
- No remote wiring, no push, no comms-sync calls (transport stays deliberate).
- No ledger migration, no herdr/omp config changes.
- No session-end/session-start logic changes; no scaffold heredoc edits.
- No retroactive auto-migration of ALL folders (per-folder, operator-driven runs).
- No merge/diff assist UI (a named refusal + .bak is the recovery path).
- No --only `all` implicit classes beyond the named list.

## Open questions
None blocking. Render divergence nuance (FOLDER line / PURPOSE line vs live) is
settled by the proven eval-render parity technique from work-clone-source-01 — the
scaffold's own substitution method IS the comparison baseline; anything not
derivable is operator-modified by definition.