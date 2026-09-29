# intent-comms-git-01 — scaffold bakes comms/ as a git repo + credential pre-push hook

Unit 1 of ROADMAP.md (comms-as-git transport tier). Sealed 2026-09-29, session
patdabney/20260929-02. This file IS the intent contract; proof artifacts follow in
this directory.

## Problem

`comms/` travels as loose files only: nothing transports it between nodes, nothing
prevents prose-tier credentials (a gh token pasted into a handoff, a Copilot key in
a dropped note) from leaving via push. ROADMAP unit 1 makes the comms protocol tree
a git repo at scaffold time and gates every push with a credential scanner.

## Proposed outcome

`scaffold/new-enclosing-folder.sh` init's `comms/` as a git repo with ONE initial
commit (README, session-start.sh, session-end.sh, templates/ ×2, `.gitignore`,
`hooks/pre-push`) and stamps the credential-scanner `pre-push` hook executable.
`migrate-user-comms.sh` performs the same init idempotently on existing folders:
init when `.git` is absent; stamp the hook when the repo exists but the hook is
missing (clones don't inherit hooks — this is the same self-heal comms-sync
export will later own, wired early for the test to drive).

The repo is the comms protocol only (README/scripts/templates/hooks/.gitignore).
Session folders are committed as they form — `session-end.sh` and the session
scripts are REPO CONTENT, not ignored state; the .gitignore excludes only throwaway
fixture/scratch classes (`*.tmp`, `.stderr`, mind-note scratch is fine). No remote
wiring at scaffold time (no URL to guess — ROADMAP NOT-list; the follow-up print
names `comms-sync remote <url>` / `git remote add origin …`).

### Hook mechanics (from m:006 item 2, fixed for correctness)

Pre-push reads stdin lines `<local-ref> <local-oid> <remote-ref> <remote-oid>`.
For a DELETED ref (local-oid all-zero) there is nothing to scan → allow. Otherwise
scan the added lines of every NEW commit on every pushed ref:

- input: `git rev-list <remote-oid>..<local-oid>` on stdin refs (new-push case:
  remote-oid is all-zero → scan the whole new history), then
  `git diff --stdin <oid>^ <oid>` / `git diff-tree -p --root -m --stdin` piping
  patch text, grep pattern set against ADDED lines only (`^\+`), skipping the
  `+++` file headers.
- Pattern set v1 (case-insensitive):
  - `AKIA[0-9A-Z]{16}` — AWS key id
  - `gh[pousr]_[A-Za-z0-9]{36,}` — GitHub PAT
  - `github_pat_[A-Za-z0-9_]{22,}` — fine-grained PAT
  - `xox[baprs]-[A-Za-z0-9-]{10,}` — Slack token
  - `sk-(ant-)?[A-Za-z0-9_-]{20,}` — Anthropic / sk- keys
  - `(api[_-]?key|secret|token|passwd|passw?d)[[:space:]]*[=:][[:space:]]*['"][^'"]{8,}` — generic assignment (skips lines containing `example|placeholder|<your|xxxx`)
- Refusal: names file+line (best effort, from the diff hunk header), prints the
  offending line prefix, exit 1.
- Override hatch preserved: `git push --no-verify` (documented in hook refusal
  text as the escape, per protocol style).

### Byte-parity / mirror duty

The hook body ships as one scaffold heredoc `cat > "$STAGE/comms/.githooks/pre-push"`,
extracted and cmp-gated by the lifecycle test like the other stamped files. The
migrator extracts the SAME heredoc (marker `hooks/pre-push`) — one source, two
consumers, the 2026-09-09 "one resolver" rule.

## Proof obligations (gate + evidence bundle .evidence/comms-git-01/)

Driven by real runs; structured JSON per artifact:

1. **01-scaffold-init.json** — fresh scaffold → `comms/.git` exists, `git -C comms
   status --porcelain` clean after the initial commit, `git -C comms log --oneline`
   = one commit, hook file executable.
2. **02-hook-refuse.json** — in the scaffolded comms repo, craft two commits: (a)
   an innocent handoff fill (positive control) → hook allows (fake-remote push
   path, exit 0); (b) a handoff line carrying a fake token (`AKIA`-shaped dummy +
   `ghp_`-shaped dummy) → hook REFUSES, exit 1, naming the file; the offending
   commit never lands on the remote side (push dies at the hook).
3. **03-migrate-init.json** — pre-fork-style folder (comms/ already populated, no
   `.git`) → migrate init's the repo + stamps hook + commits protocol files;
   re-run migrate → no-op (no new commit, hook untouched); folder WITH repo but
   hook deleted → migrate re-stamps the hook (self-heal proof).
4. **04-no-verify.json** — `git push --no-verify` carries the credential commit
   across (loud escape preserved; the override must exist and must WORK, otherwise
   the gate's refusal path is a lie about reality).
5. **05-bash32-docker.json** — full unit-1 lifecycle (init + commit + refuse +
   positive control + migrate no-op) under bash 3.2 + git 2.49 in the container.
   NOTE: the `bash:3.2` image has NO git preinstalled — provisioned with
   `apk add git` in the proof (the class of machine unit-1 targets is Ubuntu;
   macOS ships git; bare-metal Alpine is out of scope).
6. **regression** — the 18-assertion comms lifecycle gate (now 20) green on host
   bash 5.3 AND docker bash 3.2, with the two new assertions (comms-is-repo,
   hook-fires-and-refuses) live in the standard gate.

## Invariants

- Refuse-to-guess preserved: no `git remote add` at scaffold/migrate time; the
  hook refuses rather than silently redacting (scanner, not sanitizer).
- The comms repo contains ZERO credential material in its INITIAL commit (scanner
  scans its own history on first push — the pattern set must not match the
  hook's own source; patterns are written to avoid self-match, verified in the
  gate).
- bash 3.2 portable: no `;&`, no assoc arrays, `{ find … || true; } \| …` guard.
- Single git repo per comms/ (nested repos from session drops stay out —
  .gitignore + hooks at comms root only).

## Affected systems

- `scaffold/new-enclosing-folder.sh` (comms/ stamping + git init + hook heredoc)
- `migrate-user-comms.sh` (init + hook stamp self-heal)
- `comms-lifecycle-test.sh` (gate: +2 assertions → 20)
- `README.md` + `machine.md` (doc duty, same diff)

## NOT-list

- No remote wiring / URL guessing (unit 2's `comms-sync remote`).
- No comms-sync script yet (unit 2 — import/export/diverge machinery).
- No S3/artifacts work (parked unit D).
- No doctor changes (unit 4).
- No installer changes (scaffold/migrator already PATH-gated).
- No hook pattern tuning beyond the v1 set above (extend on first false result).
- No history-rewrite tooling; a leaked credential is handled by the proven
  omp-remote force-push playbook, not new code.

## Open questions

- (none blocking) Hook self-match in the gate: assert the initial commit pushes
  clean — this IS the no-false-positive control, proven in artifact 02 part (a).

## Next steps

1. Scaffold: add hooks/pre-push heredoc + .gitignore + git-init block in finish().
2. Migrator: init-if-missing + stamp-hook-if-missing idempotent block.
3. Gate: extend to 20 assertions (repo-valid + hook-fires on the fixture root).
4. Run gates: host 5.3 + docker 3.2 (+ git), capture bundle.
5. Doc duty (README "What's inside" + git-transport paragraph; machine.md
   fresh-box line), commit, offer push/PR per finish-line.