# PROOF — comms-git-01 (scaffold bakes comms/ as a git repo + credential pre-push hook)

Mode: inline seed unit (ROADMAP unit 1; no delegation — single context: scaffold + migrator
+ one gate). Session patdabney/20260929-02.

## What changed (this commit, work/agent-runbook-cg1-lane → merge to work/agent-runbook)
- `scaffold/new-enclosing-folder.sh`: comms/ stamped as a git repo at creation — initial
  commit (README, scripts, templates/, hooks/pre-push, .gitignore), hook ACTIVE at
  `.git/hooks/pre-push` + tracked copy at `comms/hooks/pre-push`; git-missing refuse;
  follow-up print names the deliberate remote wiring.
- `pre-push` hook (new, single source = the scaffold heredoc): scans ADDED lines of
  pushed refs (`<remote-oid>..<local-oid>`; all-zero remote = whole history), shape
  patterns v1 (AWS / gh PAT ×5 / fine-grained PAT / Slack / Anthropic / generic
  assignment), Excuse filter for literal examples; refuses exit 1 naming file:line +
  the `--no-verify` escape; self-scan clean.
- `migrate-user-comms.sh`: §3b — idempotent `git init` when `.git` absent; re-stamps the
  hook whenever missing or stale (tracks comms/hooks/pre-push AND .git/hooks/pre-push).
- `comms-lifecycle-test.sh`: §11 — 8 new assertions (repo valid, history exists, tracked
  hook, active hook, parity, refuse+explain+name-line+escape, positive control) → 28 total.
- Doc duty same diff: scaffold README heredocs (enclosing + protocol) + AGENTS heredoc +
  LIVE mirrors (comms/README.md, AGENTS.md — cmp-equal) + runbook README tree line +
  machine.md fresh-box line (below).

## Proof obligations vs artifacts
| Obligation | Artifact | Result |
| --- | --- | --- |
| fresh scaffold → valid repo, 1 commit, hook exec | 01-scaffold-init.json | PASS |
| hook refuses each pattern arm, names file+line | 02-hook-refuse.json + gate | PASS |
| positive control: innocent push passes | 02 + gate | PASS |
| `--no-verify` escape works | 04-no-verify.json + b32 proof | PASS |
| migrate init + idempotent + self-heal | 03-migrate-init.json | PASS |
| bash 3.2 docker suite | 05-bash32-docker.json + raw txts | PASS |
| regression: comms gate both interpreters | gate-host.txt / gate-bash32.txt | 28/28 both |

## Gate notes
- Extended gate green: host bash 5.3 28/28, docker bash 3.2 28/28 (same harness; filler
  was already awk-only).
- Hook invocation in the gate subshells into the REPO cwd (mirrors git's own hook
  invocation). Calling the hook by absolute path from another cwd finds no repo and
  skips every ref silently — that trap is now documented in the gate comment.
- REAL-PUSH proof on the scaffolded fixture: leak commit at comms tip → `git push` fails
  with the refusal; remote ref verified UNCHANGED after refusal; then `--no-verify`
  advanced remote (escape reality check).
- The old multi-line PATTERNS blob had a LEADING EMPTY ARM (grep newline-separates
  patterns; an empt leading arm matches EVERY line) — caught in prototype because every
  innocent line "matched." Rewrote as a single-line alternation. This failure mode is
  documented in the hook comment.
- bash-3.2 docker: image has NO git/grep — the proof provisions `apk add git grep`
  (documented; real targets are macOS w/ git, Ubuntu w/ machine.md steps).
- Live enclosing folder migrated this session: comms/ is now a git repo (initial commit
  5321177), hook active; git status clean; gate re-run against the live folder 28/28 with
  the run root md5-checked clean (fixture staging by design).

## NOT done (per intent NOT-list)
- No remote wiring anywhere (unit 2 `comms-sync remote`).
- No comms-sync script (unit 2 — import/export machinery this hook self-heal previews).
- No doctor changes (unit 4).
- No installer changes (scaffold/migrator already PATH-gated).

## Verdict
PASS. Unit 1 done; gate extended to 28 both interpreters; priors re-proven (18 old
assertions green within the 28). Ready for unit-2 lanes (comms-sync) + unit-3 docs lane
in parallel (disjoint files).