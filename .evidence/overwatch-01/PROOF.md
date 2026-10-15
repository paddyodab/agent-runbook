# PROOF — overwatch-01

Mode: inline (single context edit: new `overwatch` script + session-start hook +
installer + docs). No lanes. Session of record: comms/patdabney/20261014-05.

## What was built

- `overwatch` (runbook root, executable): rebuild / status / why <sha|path|symbol> /
  turns <uuid> [--all] / related <text> / tie <uuid|folder>. Bash 3.2-safe,
  shellcheck clean, jq-heavy, pointers-only. Deps: git, sqlite3, jq (required),
  rg optional (degrades: grep fallback for comms corpus, no code-hit class).
- Tie model implemented: cwd exact-match → enclosing folder; handoff slot-0 UUID
  stamp authoritative; pre-stamp folders derive from transcript-window ∩ comms-folder
  evidence epochs (folder mtime + comms-repo commit epochs); ambiguous overlap keeps
  BOTH candidates flagged `ambiguous:true` (proven in junk-HOME fixture); work-repo
  commits tie by author-date inside transcript windows (`git log --all`).
- One writable path: `comms/.overwatch-index.jsonl` (gitignored, derived, per-node).
  Read-only everywhere else (sqlite `-readonly` with tmp-copy fallback on lock).
- Live `comms/session-start.sh` + scaffold mirror: ONE fail-soft rebuild block after
  the prior-art refresh; absent tool → intro line, rc unchanged (both arms proven
  host-side). Scaffold mirror byte-parity at anchored bounds (380/732, 19175 bytes).
- install.sh: §3d-3 PATH-gate install block (same refuse-fence class), doctor dexec
  parity loop entry, uninstall line. machine.yml: sqlite3+jq required, rg optional.
- Docs: README (tool list + "The query surface (overwatch)" section), machine.md
  (pieces table row), ROADMAP (unit record updated with build note + operator picks).

## Bugs found while building (all fixed + re-proven)

1. **`"$r.git"` adjacent-path check** — repo detection looked for `work/<repo>.git`
   (adjacent), never matching real in-repo `.git`; three sites fixed to `$r/.git`.
   Caught by the comms-sha `why` arm (comms repo never resolved).
2. **`--rawfile` binds a STRING, not an array** — `[0]` unwrap broke on real jq;
   fixed to pipe the string through `tsv` directly. (Earlier confusion: the box's
   shim `jq` is jaq 3.1.1; real jq 1.8.2 at /usr/bin — both converge after fix.)
3. **Missing `-n` on the join invocation** — `jq -r -f join.jq` with no stdin read
   zero records; the emitted index was silently empty. Fixed (`jq -n -r`).
4. **`map(...)` array-vs-stream emission** — the join emitted ONE JSON array of
   encoded lines instead of a JSONL stream; `.[]` streaming after `sort_by` fixed.
5. **Field-name drift in `sessions_for_epoch`** — filter used `.ws/.we` against
   index lines carrying `window_start/window_end`; containment always missed.
6. **`--argjson A 0` truthiness** — jq `if 0` is TRUE; `--all` gating never
   collapsed; switched to `--arg A` string compare ("1").
7. **TSV field order in print_session_block** — read order mismatch shifted
   window fields into the wrong slots.
8. **Preamble excerpt leaked template HTML comments** — comment-block state machine
   added (skip `<!--` … `-->`), excerpt now shows only the operator's ask lines.
9. **tie folder-path matching** — absolute fixture paths didn't resolve; realpath
   normalization added (relative `comms/*/*`, absolute `$ROOT/comms/…`, unique
   suffix all accepted).

## Pre-existing bug found by regression duty (fixed, not mine)

`comms-lifecycle-test.sh` YESTERDAY/MW_YESTERDAY fallbacks used `date -u` → on a
UTC-4 host after 16:00 local, "UTC yesterday" == local TODAY → chronology arms
collapsed into ties → 5 gate failures. Reproduced at the UNTOUCHED reference clone
(@41bb340) with a reference-built junk fixture BEFORE concluding anything about
overwatch; fixed (local `date -d "@epoch-86400"`) in both gate copies (reference repo
gets the same fix committed on its branch separately — this unit's branch carries the
work copy). 32/32 both hosts after the fix.

## Evidence

- 01-rebuild-index.json — rebuild idempotent (5/5), pointers-only grep clean,
  gitignored, tie counts (2 stamp / 3 window / 0 ambiguous), 11 commit rows.
- 02-why-commits.json — ground truth: bb58e65/3c39219/e0d4b07/2c80008 →
  comms/patdabney/20261014-02 + titled session 01a13b8d (session-tie-01 precedent);
  comms-repo sha answered with transport-plumbing label.
- 03-why-symbol.json — `herdr_preamble_pane_setup` -S hit set + hint; clean-empty
  rc=0 arms for symbol + path.
- 04-turns.json — this session's uuid: first turn = session-start ask; collapsed
  (0 toolResult bodies) vs --all (70) gating proven; absent uuid rc=0;
  junk-HOME JSONL-only env prints correctly (companion dir not required).
- 05-related.json — "session-tie": session/commit/code/comms hits, tie-annotated;
  untracked term → clean empty; no-rg degrade proven via PATH without rg.
- 06-tie.json — tie by uuid (20261014-03 footprint: stamp, commits incl. PR #6/#7,
  ask excerpt, pointers); tie by folder (20261014-01 pre-slot-0 → [window]);
  ambiguous-overlap junk fixture → both sessions, both folders, `[window/ambiguous]`.
- 07-regression.json — lifecycle 32/32 host + alpine:3.19 docker; shellcheck clean
  (touched scripts); doctor honest both directions (drift named, not silently green).
- 08-mirror-byte-parity.json — anchored splice cmp rc=0, 19175 == 19175 bytes.

## Gate notes

- `/usr/bin/jq` is real jq 1.8.2; PATH's first `jq` may be jaq — script works under
  both (join semantics verified with real jq; related/filters verified under jaq).
- The gate's fixture staging copies the WHOLE comms/ tree minus session dirs — a
  live-folder run must not be read as a code verdict without comparing the reference
  baseline (the 5-fail set was environmental, per above).
- `related` comms-corpus hits print match COUNT as the detail column (grep -c);
  ranked by weight then key. Fine for v1; ranking upgrade is a recorded later lane.

## Verdict

PASS — intent's proof obligations 01–08 satisfied; every command exercised live;
ground-truth join (20261014-02 commits → comms folder + title) reproduced via the CLI;
fences held (no daemon, no automatic firing, pointers-only, read-only sources,
one writable derived path).