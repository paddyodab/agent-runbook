# PROOF — artifacts-sync-01 (Unit D: the objects tier)

Mode: inline (single script + installer tool loop + docs; no delegation — one
context, one file, contract pinned in INTENT.md before code).
Session patdabney/20261001-02. Trigger: operator scoped the "s3 thing" in the
session intro (shared-context loop: EC2 ⇄ laptop ⇄ git/s3 — artifacts was the
missing leg). Operator decisions: target wired later; auth decided at deploy.

## What changed (work/agent-runbook)
- `artifacts-sync` (new, runbook root): export/import/remote/status + scoped
  `--force` reconciliation; targets = `s3://bucket/prefix/` (real aws s3 sync
  plumbing) or a local filesystem path (plain coreutils — no aws needed);
  wire file `.sync-target` written only by `remote`, gitignore-fenced,
  excluded from mirrors.
- `install.sh`: §3d copy block (same PATH gate + cmp refuse-fence), doctor
  `for dexec` entry, uninstall line.
- `machine.yml`: `aws` as optional runtime dep (s3 mode only).
- README: tree line + "The objects tier (artifacts-sync)" section.
- machine.md: step 9 (bucket recipe, wire/first lift, auth shapes — all
  VERIFY-AT-DEPLOY), step 5 lockdown amended (`artifacts/` now g+w —
  deliberate delta to shared-comms-01's result).
- ROADMAP: Unit D unparked (trigger recorded), topology line updated.

## Obligations vs artifacts
| # | Obligation | Artifact | Result |
| --- | --- | --- | --- |
| 1 | two nodes + target roundtrip (subdirs, spaces) | 01-…txt (34/35 PASS incl. this) + smoke | PASS |
| 2 | fences refuse + name recipe; --force scoped-exact; overwrite-not-fence | 01-…txt | PASS |
| 4 | refusal hatches (unwired, scheme, bare bucket, re-wire, electivity, env) | 01-…txt | PASS |
| 3 | S3 API semantics over real API (moto in docker, no creds) | 03-moto-s3.json.txt (20/20) | PASS |
| 5 | bash 3.2 docker local-mode flow (real interpreter) | 05-bash32-docker.txt (9/9) | PASS |
| 6 | regression: 32-assertion comms gate host + bash3.2 (git provisioned), doctor green, cmp parity | regression-gate-*.txt | PASS (32/32 both) |

## Gate notes / design deltas vs the intent
- **aws CLI v1 empty-listing semantic (found by moto, would have broken real
  buckets):** `aws s3 ls s3://bucket/empty-prefix/` returns rc=1 with EMPTY
  stderr — moto shows an empty prefix listing is SUCCESS, not failure. The
  wrapper now treats rc=1 + empty output as reachable-but-empty (`s3_ls`);
  without this, `remote` would refuse to wire a fresh empty prefix and every
  first export would have died at the reachability check.
- **Bare-bucket guard needed an s3-specific pattern:** `s3://bucket` contains
  `/` (the scheme's own `//`), so the generic `*/*` slash-check matched
  everything; the boundary check is now `s3://*/*` (past the `//`). Found in
  the moto flow (04's host run couldn't see it — no aws CLI there).
- **The wire file never rides the pipe:** `aws s3 sync` happily uploaded
  `.sync-target` to the bucket; both sync directions now `--exclude
  ".sync-target"` (and local mirror lists never emit it).
- **Fence granularity is LEAF FILES** (S3 objects have no real directories):
  a dir-level name diff would false-fence every normal subdirectory. Empty
  dirs don't travel in v1 — documented in INTENT + README.
- **Recipes are paste-clean**: names shell-quoted (spaces survive), and when
  the fence was reached via a one-shot `--target`, the recipe carries that
  `--target` so an unwired node can execute it verbatim (proven in 03).
- Proof-script sequencing bugs (5 of them) were found and fixed by
  re-deriving each from the tool's actual state — every tool refusal that
  looked like a failure was correct-per-state; zero tool bugs among them.
- `install.sh --doctor` drift-detection caught the installed copy going stale
  mid-session (the cmp fence + deliberate rm + reinstall — the 2026-09-08
  lesson #9 firing again).

## NOT done (per intent NOT-list)
- No S3 sync of comms/, prior-art/, work/ (electivity enforced + proven).
- No exclusions beyond the wire file; no bucket automation; no real-credential
  auth (machine.md documents shapes, VERIFY-AT-DEPLOY); no versioning/
  lifecycle; no doctor comms-folder sweep (unit 4's job).

## Verdict
PASS. All six obligations green; priors re-proved (32/32 comms gate, host +
bash 3.2 docker); shellcheck clean on all runbook-root scripts (0 findings
artifacts-sync/comms-sync/fresh-box/install/scaffold); doctor green; installed
copy byte-identical. Push offer to operator per finish line.