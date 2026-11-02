# Review notes — agent-runbook (2026-11-02)

An outside read of the repo: what's working, and what to redo later.
Summary: the method is the strongest part; the weakest part is the engineering
underneath it, where the same text is copied into several places by hand and
nothing re-checks the proofs once a unit is done.

## What's good (keep)

1. **Proof before code, and a gate that doesn't trust the agent.** INTENT files
   with proof obligations + NOT-lists, and `.evidence/` that gets re-run. The
   NOT-lists help most: they name the nearby work an agent would otherwise drift into.
2. **The four doors.** Sorting work into new codebase / existing codebase /
   refactor / bugfix before starting catches real mistakes ("no repro is a
   legitimate triage outcome"; "recover the map before delegating").
3. **Honest safety rules.** No daemons, nothing syncs unless you run it, refusals
   name the exact override (`--force <names>`, `--no-verify`), `--doctor` /
   `--check` only read.
4. **The enclosing-folder layout.** `comms/` / `prior-art/` / `work/` /
   `artifacts/` give each kind of data its own sync method and trust level. The
   credential pre-push hook on `comms/` is a cheap guard against a real risk.
5. **Bro-mode plus mind notes.** Chat stays short; depth goes into numbered,
   citable files instead of being thrown away.

## What to redo (in priority order)

### 1. Pull the scripts out of the scaffold's heredocs (highest leverage)
`scaffold/new-enclosing-folder.sh` is a 1,412-line generator with 12 heredocs:
`comms/session-start.sh` (~400 lines), `session-end.sh`, the templates,
`glow-pane.sh`, the pre-push hook, `AGENTS.md`, the READMEs.
- You can't lint, test or diff those scripts as real files.
- `glow-pane.sh` exists both at the repo top level and as a heredoc copy.
- Bash parsing rules leak into prose (the bash 3.2 apostrophe problem in
  `.evidence/work-clone-source-01/PROOF.md`).

**Plan:** move them to real files under `scaffold/files/`; the scaffold copies
them and uses `sed` for the few placeholders (FOLDER / PURPOSE / CONVENTION /
slug). Keep the stage-then-move atomic build.

### 2. One source for the agent rules text
The AGENTS rules live in the runbook block (`AGENTS.md`), the scaffold heredoc,
`kit/omp/files/home/.omp/agent/AGENTS.md`, and each live enclosing folder. 14
PROOFs spend obligations on byte-parity checks, which is per-unit work covering
for a structural problem.

**Plan:** keep one source and generate the rest; a single parity check
(e.g. `make check-parity`) instead of a parity obligation in every unit.

### 3. Add CI
There's no `.github/`, so the gates only run when someone remembers.

**Plan:** a GitHub Actions workflow that runs:
- `comms-lifecycle-test.sh` on bash 5 and inside a `bash:3.2` container
- `shellcheck` on every script
- (optional) `sandbox-test.sh` on a schedule or manual trigger

### 4. Limit bash 3.2 to the bootstrap path
Supporting stock macOS bash is reasonable for what ends up on every box
(`fresh-box.sh`, the scaffold, the session scripts). It's expensive for
`overwatch` (709 lines joining git, SQLite, JSONL and transcripts) and the sync tools.

**Plan:** port `overwatch` (and maybe `comms-sync` / `artifacts-sync`) to Python
(already an optional dependency) or Go, with real unit tests.

### 5. Slim the docs
- `README.md` is ~18KB of one-line summaries packed with jargon ("fences,"
  "hatches," "tiers," "firing points"), which works against the "read cold" goal.
- `ROADMAP.md` is ~38KB and mostly finished units, so it reads like a changelog.

**Plan:** README = one screen of what / why / install, with links to the rest.
Move done units to `docs/history/` (or let `.evidence/<unit>/` be the record);
ROADMAP keeps only open and next units plus the standing fences.

## Smaller items
- `machine.yml` omp pin drift: `version: "18.4.3"` but the bun install hint
  installs `17.4.2`.
- `.evidence/` (~520KB) lives in git and will grow without limit; consider a
  pruning or archiving policy.

## Suggested order
1 → 3 → 2 → 5 → 4. Pulling the scripts out makes CI easy to add, and CI makes
the rest safe to change.
