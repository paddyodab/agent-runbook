# INTENT — overwatch-01

> Session of record: comms/patdabney/20261014-04 (operator preamble + design
> dialogue in chat). Design analysis: that session's mind/001-overwatch-design.md.
> Precedent probe: .evidence/session-tie-01/ (tie set, slug rule 18/18,
> session-tie-01 handoff slot-0 stamp).

## Problem

The operator's recurring questions (preamble 20261014-04):

1. "How did we come to make this code change on <date>? Who made it? What were
   they thinking?" — git carries who + what; comms carries why (preamble =
   ask, conversation.md = reasoning, handoff = state, mind/ = depth), but
   NOTHING JOINS them. The analyst today is a human archaeologist.
2. "What did we work on a couple of weeks ago related to <commit hash | class |
   idea name>?" — same gap in reverse.

All raw material exists read-only (proven 20261014-03 + re-verified 20261014-04):

- omp transcripts: `~/.omp/agent/sessions/<cwd-slug>/<ts>_<uuid>.jsonl`
  (+ companion dir with tool logs); slug rule = `"-"+cwd minus $HOME, "/"→"-"`.
- `~/.omp/agent/history.db`: `session_titles` (id→title), `session_recaps`
  (id, cwd, recap, ts) — distilled state per session, zero transcript parsing.
- comms corpus per enclosing folder: preamble, conversation.md, handoff
  (slot 0 carries the UUID since session-tie-01), mind notes.
- work-repo commits: full local history in every `work/<repo>` clone on every
  node (GitHub-hosted; remote API is NOT needed for the local-history join —
  correction this session: operator uses GitHub, not GitLab; `gh` is OPTIONAL,
  only for PR titles on merged refs).

## Proposed outcome + invariants

**`overwatch` CLI** (runbook root, PATH-gated install like comms-sync/fresh-box/
artifacts-sync/glow-pane) answering from a DERIVED index:

- `rebuild [<enclosing-folder>]` — rescan → `comms/.overwatch-index.jsonl`
  (JSONL; titles carry emoji, TSV would break on pipes). Per omp session line:
  `uuid, window_start, window_end, cwd_slug, cwd, title (from history.db),
  recaps[], comms_folders[], work_repos[]: {repo, commits[]: {sha, date, subject,
  author}}`.
- `status` — index exists? mtimes vs sources; entry counts per tie class. Read-only.
- `why <sha|path|symbol>` — commit list via `work/<repo> git log --all --<match>`
  → containing transcript window(s) → print: commit, author, date, session title
  + uuid + transcript path, comms folder(s), the folder's preamble excerpt,
  pointer set (handoff / conversation.md / mind/ paths — pointers, never excerpts
  beyond the preamble first lines).
- `turns <uuid> [--all]` — parse the transcript JSONL, print user+assistant text
  in order (tool results collapsed by default). Printed, never persisted.
- `related <text|symbol>` — ranked hits across: comms corpus (rg), session
  titles + recaps (history.db), index commit subjects, work-repo code hits
  (`rg` file:line only) — each hit annotated with its tie links.
- `tie <session-uuid | comms-folder-path>` — one session's full footprint:
  ask (preamble excerpt), commits + changed files, distilled files, neighbors.

Invariants:

- **Read-only everywhere**: index + queries never mutate any source. Rebuild
  writes ONLY `comms/.overwatch-index.jsonl` (gitignored — derived, never
  canonical; every node rebuilds its own: sub-second here, no transport value
  in a committed snapshot).
- **Pointers only**: the index and `why`/`tie` output never carry transcript
  excerpts or comms prose beyond a short preamble first-lines excerpt (operator's
  own words, already push-gated). Turn text PRINTS on `turns` and never persists.
  Transport tier stays clean by construction, not by scan.
- **Declared discovery**: work repos + comms folders are DISCOVERED from the
  enclosing folder only (comms/<user>/* session folders; work/* git repos,
  listed in index with their head). No daemon, no home-grown discovery beyond
  the enclosing folder boundary — matches unit-4's declared-hint philosophy.
- **Derived ties fall back gracefully**: no handoff stamp (pre-20261014-03) →
  map by transcript window ∩ comms-folder git-commit date/folder mtimes; overlap
  → BOTH candidate sessions kept and marked ambiguous (never guess).
- **No omp cooperation needed**: history.db and transcripts are read as plain
  files; sqlite3 read via `sqlite3` binary (open `-readonly`; copy to tmp on
  -wal lock failure). Absent sources (no omp, no work/) → index exists with
  empty sections; `status` says so. Fail-soft.
- **bash 3.2-safe**, shellcheck clean (comms-git-01 precedent).

## What "good" looks like (proof artifacts, `.evidence/overwatch-01/`)

1. `01-rebuild-index.json` — rebuild on THIS folder: ≥4 sessions indexed with
   real titles from history.db; index JSONL valid; second rebuild idempotent
   (same entry count); index lines carry zero transcript/comms prose bodies
   (automated grep of forbidden substrings — by-construction check).
2. `02-why-commits.json` — ground-truth join: session 20261014-02's commits
   (bb58e65, 3c39219, e0d4b07, 2c80008 — proven inside that session's transcript
   window in session-tie-01) resolve via `why` to comms/patdabney/20261014-02
   + the titled session; `why <sha>` for a comms-repo-only sha still answers
   (transport-plumbing marker, WORK-repo emphasis stated).
3. `03-why-symbol.json` — `why <symbol>` (e.g. a name shipped in one unit)
   finds its commits + units; a NONEXISTENT symbol → clean empty answer (rc 0,
   "no hits" — a report, not an error).
4. `04-turns.json` — `turns` on this session's uuid prints user+assistant
   sequence (spot-assert first turn contains the session-start ask); `--all`
   includes tool text; absent uuid → clean empty + rc 0; tool-log companion dir
   is NOT required (fail-soft when only JSONL exists).
5. `05-related.json` — ranked search: known term from this folder ("overwatch")
   returns comms hits + session titles + commit subjects; tie-annotated.
   Untracked-term → empty set, never noise (threshold honest).
6. `06-tie.json` — `tie <uuid>` for session 20261014-03 prints footprint
   (PR #6+#7 commits, ask excerpt, pointer paths); `tie <folder>` for THIS
   folder's 20261014-01 (pre-slot-0) resolves by window (marked derived);
   ambiguous-overlap arm from synthetic two-overlapping-transcripts fixture
   (junk HOME run root; ledger-isolated) → both kept + `ambiguous: true`,
   never a silent pick.
7. `07-regression.json` — comms lifecycle gate 32/32 host AND bash:3.2 docker;
   shellcheck clean; installer doctor green on this box with the runbook copy
   carrying the unmerged feature branch (drift named, not silently green).
8. `PROOF.md` — verdict + notes (evidence labels written by humans — trace
   before claiming a bug).

## Bounded contexts (boundary contracts)

- **new `overwatch`** (runbook root) — owns ALL index/query logic; the only
  writer of `comms/.overwatch-index.jsonl`.
- **comms/session-start.sh (LIVE + scaffold mirror)** — gains ONE fail-soft
  block: after prior-art refresh, rebuild the index ONLY when `overwatch` is on
  PATH (absent → intro line `(overwatch: not installed — rebuild skipped)`,
  rc stays 0). Mirror contract: live canonical → scaffold heredoc re-splice →
  cmp byte-parity at anchored bounds (grep the `cat >` line + exact terminator;
  never remembered line numbers — 20261014-03 finding).
- **install.sh** — PATH-gate block (§3 pattern), doctor dexec entry, uninstall
  line. Same refuse-fence class as comms-sync.
- **README.md + machine.md** — overwatch section (query surface, index format,
  pointers-only rule), machine.yml deps (dep checks: git, sqlite3, jq;
  `rg`+`gh` optional → degrades: related search without code hits, why without
  PR titles — named, not silent).
- **ROADMAP.md** — unit record + topology note (index tier = derived, per node).
- **this enclosing folder** — index gitignore line via unit's own one-time
  setup (`comms/.gitignore` + `!.overwatch-index.jsonl`? NO — gitIGNORE the
  index: `comms/.gitignore` gains `.overwatch-index.jsonl`).

Coupling points: session-start (fail-soft hook), install.sh (PATH gate), machine.yml
(deps). Revisit triggers: omp transcript schema change (session record), history.db
schema change, comms slot-0 format change.

## Constraints

- bash 3.2-safe in all shipped scripts; POSIX awk (no gawkisms).
- Never automatic firing: index refresh is (a) fail-soft at session-start, and
  (b) explicit `rebuild`. Nothing watches.
- Read-only on sources; the ONE writable path is `comms/.overwatch-index.jsonl`
  (+ tmp during rebuild).
- HOME-isolated proof runs (junk ledger lesson, 20261014-03): any proof run that
  could touch session scripts sets HOME inside the run root.
- The provenance fence for the installed copy stays as-is (version-age ancestor
  refusal named in 20261014-03 findings is a separate candidate unit — NOT here).

## Open questions

- None blocking design (defaults chosen with operator this session): declared
  discovery (not auto-glob), user+assistant turns, name `overwatch`,
  index untracked-in-comms, GitHub-remote posture (gh optional).

## NOT-list

- No overwatch daemon/agent/always-on process; no fs watcher; no cron.
- No omp/homeroom writes: no history.db/agent.db schema or data changes.
- No transcript excerpts, comms prose, or mind-note content IN the index or any
  output file (turns print to stdout only; preamble excerpt only via `why`).
- No committed index snapshot in comms history; no .sync-target style transport.
- No re-derivation of the slug rule in a second place (overwatch imports the
  same rule; if session-start exposes it as a helper, reuse — don't fork).
- No prior-art/ or artifacts/ indexing (contents stay read-when-named;
  prior-art HEADS ONLY, artifacts/ entirely out of v1).
- No remote API calls in v1 (GitHub REST/GraphQL; gh becomes optional plumbing
  in a later unit if PR titles are wanted on merged refs).
- No comms-sync/artifacts-sync/fresh-box/sandbox changes; no ROADMAP governance
  changes beyond the unit record; no session-end changes.
- No Windows/other-OS port work (Linux/omarchy box; portable-by-interpretation
  only via the bash 3.2 duty).

## Next steps

- Branch exists (`feature/overwatch-01`, work copy @41bb340). Build order:
  overwatch script → live session-start hook → scaffold mirror re-splice +
  cmp → install.sh PATH gate + doctor + uninstall → docs (README, machine.md,
  machine.yml, ROADMAP record) → proof artifacts 01–08 → commit → offer
  push/PR (operator's explicit go, per runbook floor).