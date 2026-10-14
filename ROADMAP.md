# ROADMAP.md — comms-as-git tier (multi-node context transport)

Governance: this map governs the comms-transport build in `work/agent-runbook`.
Map changes at intent time, never at code time. Units touch only their listed
contexts. Proof artifacts are written before implementation; no obligations →
no delegation. Regression duty: every unit's proof re-proves the priors (the
18-assertion comms lifecycle gate is the standing index; green on bash 5.3 host
AND bash 3.2 docker after every unit).

Design provenance (kick-around trail, m:001–m:006 in
`comms/patdabney/20260929-01/mind/`): the enclosing folder is the unit of
isolation; syncs are per-tier; intentional firing only (never automatic) on
the prose tier; S3 = object tier (export/backup), never live workspace; git
remote (GitHub, private) = canonical home for comms history.

## Topology being built (the true north)

```text
<idea>/ (enclosing folder, NOT a repo)
  comms/          git repo ↔ GitHub private   ← the build target
  work/<repo>/    per-repo git ↔ GitHub       (exists; untouched)
  prior-art/      NOT synced (re-clone)       (unchanged)
  artifacts/      S3 prefix sync, elective    (UNPARKED 20261001-02 → unit D)
  README/AGENTS   provisioned by scaffold     (unchanged)
Nodes: EC2 (pd/dw working copies) + Pat Dev + Dustin Dev (clones) + future
herdr-dev instances (each single-user). Canonical state = the remote;
no node is special. Session boundaries are the only sync firing points.
```

## Units

### Unit 1 — scaffold bakes comms/ as a git repo + credential pre-push hook

- **Problem:** comms/ travels as loose files only; nothing prevents prose-tier
  credentials from leaving via push.
- **Outcome:** `scaffold/new-enclosing-folder.sh` init's `comms/` as a git repo
  with an initial commit (README, session-start.sh, session-end.sh, templates/
  ×2, hooks/, .gitignore) and stamps `comms/.git/hooks/pre-push` (credential
  scanner); `migrate-user-comms.sh` performs the same init idempotently on
  existing folders and stamps the hook when repo exists but hook is missing.
- **Proof obligations:**
  - fresh scaffold → comms/ is a valid repo, one commit, hook executable
  - hook REFUSES a pushed commit carrying any of the pattern set (AKIA,
    `ghp_`/`github_pat_`, Slack `xox*-`, Anthropic `sk-ant-`, generic
    `key|secret|token = "…"` ≥8 chars) — refusal names file+line; exit 1;
    positive control: an innocent handoff pushes clean
  - `--no-verify` overrides (loud escape preserved)
  - migrate on a pre-fork folder (no .git) → init lands, history starts at
    migrate commit; re-run → no-op
  - **regression duty: comms-lifecycle gate 18/18 host + bash 3.2 docker**
- **Contexts touched:** scaffold/, migrate-user-comms.sh,
  comms-lifecycle-test.sh (assertions only)
- **NOT:** remote wiring (no URL guessing), installer changes, sync wrapper,
  S3, hook pattern tuning beyond the v1 set
- **Done when:** gate extended (+2 assertions: repo-valid, hook-fires) green
  both interpreters; evidence bundle `.evidence/comms-git-01/` complete.

### Unit 2 — comms-sync (import/export/remote/status) with hook self-heal

- **Problem:** 4 manual git commands across two repos per transport; clones
  don't inherit hooks (stamp-and-forget breaks on every new clone).
- **Outcome:** `comms-sync` script in runbook root, installed via the same
  PATH gate as scaffold/migrator:
  - `import` = pull `--ff-only` (+ loud diverge hatch naming the exact
    `--rebase`-style command), re-stamp hook if missing, then optionally
    invoke `session-start.sh --resume` when resuming
  - `export` = dirty-check + commit-if-needed + push `--atomic` (pre-push hook
    runs here); refuses mid-seal? No — explicit: export AFTER seal is the
    expected order, but refuses nothing (documented, not fenced)
  - `remote <url>` / `status` (ahead/behind/dirty per tier)
- **Proof obligations:**
  - two clones of one comms repo; export from A, import into B → sealed
    handoffs present, newest-sealed resolution identical on both nodes
  - **divergence case:** independent `20260929-01` on both nodes → import
    REFUSES with the rename recipe (the one semantic conflict), then renamed
    merge succeeds — this is the rejection-path proof
  - hook missing in clone → export self-heals (stamps) then pushes
  - installed via PATH gate; `--doctor` (after unit 4 merges? sequence with
    unit 4) reports presence
- **Contexts touched:** new comms-sync, install.sh (PATH-gate block only),
  README, machine.md
- **NOT:** automatic firing of any kind, cron, daemon, remote-side merge
  logic, per-session granularity
- **Depends on:** unit 1 (hook exists to self-heal).

### Unit 3 — machine.md AWS deltas: gh + egress + SSM door

- **Problem:** AWS box is bare Ubuntu (not the sandbox image): gh isn't
  baked; egress unverified; no no-VPN access door.
- **Outcome:** machine.md § Shared-context-box gains:
  1. gh install line (apt/mise) in the fresh-box pre-reqs
  2. egress verify step at deploy: `curl -sI https://api.github.com` through
     default route (failure → named devops ticket class)
  3. per-user gh device-flow auth recipe + `gh auth setup-git` (mirrors the
     Copilot recipe; never pooled)
  4. SSM door recipe (instance profile + `AmazonSSMManagedInstanceCore` +
     ssh ProxyCommand host-alias; VERIFY: herdr machine-add honors
     ProxyCommand) as the no-VPN fallback alongside SSH-over-VPN
- **Proof obligations:** docs-only unit — each new step carries a real
  command; the SSM recipe is labeled VERIFY-AT-DEPLOY where unproven on this
  box (no live instance access yet).
- **Contexts touched:** machine.md only.
- **NOT:** Terraform/console automation, budget changes, VPN ticket work
  (devops-owned), artifacts S3.
- **Depends on:** nothing (can parallel unit 2 — disjoint files).

### Unit 4 (optional, merge-window with 2) — doctor reports comms-git state

- **Problem:** doctor doesn't know comms/ is a repo; false-green on a
  folder whose comms/ lost its repo/hook/remote.
- **Outcome:** install.sh doctor (both modes) adds a per-enclosing-folder
  sweep (path hint via env or manifest `context_folders:` — NOT a home-grown
  discovery daemon): comms/ repo exists, hook present+executable, remote set,
  ahead/behind summary.
- **NOT:** implicit folder discovery outside the declared hint.
- **Depends on:** units 1–2 for semantics to check.

### Unit D — artifacts-sync: the objects tier (artifacts/ ↔ S3-prefix-or-rsync target)

- **Trigger FIRED (operator, session 20261001-02):** the shared-context loop is
  now real — EC2 ↔ laptop work needs artifacts as the third transport leg
  (comms rides git via comms-sync; work repos carry their own remotes;
  artifacts/ travels nothing today). Operator decisions 2026-10-01: target
  wired later when a bucket exists; auth decided at deploy (wrapper is
  auth-agnostic — profile passthrough + refusal hatch).
- **Problem:** artifacts/ (survey spreadsheets, decks, exports) has no
  transport leg; rsync-by-memory is the current plan, which is how drift
  happens between the laptop and the EC2 box.
- **Outcome:** `artifacts-sync` in the runbook root (PATH-gated like
  comms-sync), sibling grammar:
  - `import [<dir>]` / `export [<dir>]` — mirror a folder ↔ its wired target;
    default dir `./artifacts` (or cwd if it IS artifacts). Target resolution:
    the file `<artifacts>/.sync-target` (one URI, written ONLY by `remote`),
    falling back to `ARTIFACTS_SYNC_TARGET` env. Never guesses from flags.
  - `remote s3://<bucket>[/<prefix>]` / `remote <path>` — wire the target;
    refuses an existing DIFFERENT target (re-wire is deliberate); verifies
    reachability first (`aws s3 ls` / `test -d`, `--force` skips verify for a
    not-yet-existing bucket/path); writes `.sync-target` + appends a fence line
    to the folder's `.gitignore`.
  - Mirror fences (refuse, always name the recipe): target without trailing
    slash = prefix boundary ambiguity → names the exact `remote` re-wire;
    uncommitted new target → `remote` first; missing target → import seeds the
    canonical copy, export requires an explicit `--seed`; `--force name1
    [name…]` = deliberate one-shot mirror of exactly the named victims
    (post-run, those names are in sync on BOTH sides; nothing else moved).
  - `status [<dir>]` — wired? target, reachability, per-object counts both
    sides, name-only diff (unified: missing-in-dir, missing-in-target).
  - s3 target = `aws s3 sync --dryrun` plumbing (both directions); local path
    = `rsync -a` (no AWS needed — the two-node EC2↔laptop loop runs today).
- **Proof obligations (`.evidence/artifacts-sync-01/`):**
  1. two local "nodes" (two dirs + a third as target) round-trip via the
     wrapper: export A→T, import T→B, B converges (incl. subdirs + spaces).
  2. both mirror fences refuse with named recipe; `--force` mirrors exactly
     the named victims and nothing else.
  3. S3 API semantics (prefix boundary, no-trailing-slash, delete-on-mirror)
     proven over a REAL aws-s3-API server — moto in docker (no real creds
     needed), the wrapper's actual plumbing end-to-end.
  4. refusal hatches: no wired target (import/export/status), `aws` missing,
     non-s3/non-path scheme, re-wiring a different target.
  5. bash 3.2 docker flow in local mode.
  6. **regression duty:** 32-assertion comms gate green host + bash-3.2
     docker; shellcheck clean; installer doctor green.
- **Contexts touched:** new `artifacts-sync`, install.sh (§3 PATH-gate block +
  doctor dexec entry + uninstall line), machine.yml (aws optional dep),
  README (objects-tier section), machine.md (§ Shared-context box: deploy
  recipe + lockdown `g+w` delta + auth-shapes VERIFY-AT-DEPLOY).
- **NOT:** automatic firing (cron/daemon/watch/comms hooks), comms/ and
  prior-art/ and work/ sync (this tool is artifacts-bound; other tiers keep
  their transport), content-level E2E encryption (S SSE-S3 is in-machine.md;
  richer key mgmt = future unit on real need), versioning/lifecycle/restore
  drill wiring, real-credential auth choice (decided at deploy, machine.md
  documents the shapes, all VERIFY-AT-DEPLOY until run on a live bucket),
  bucket creation automation, doctor comms-folder sweep (unit 4's separate
  job, untouched), anything in the comms scripts.
- **Done when:** six obligation artifacts complete + PROOF verdict PASS;
  ROADMAP topology line unparked; machine.md carries the deploy recipe.

### Unit 5 — fresh-box.sh: the one-command box-day bootstrap

- **Problem:** Friday's EC2 box-day (ssm-user, intro.txt history) burned ~10 anomalous
  manual steps before `install.sh --machine` could run: `mkdir -p ~/Documents/GitHub`,
  clone the runbook, `sudo apt install gh`, `mkdir -p ~/.local/bin`, PATH export
  (+ `~/.bashrc` append), omp installer, herdr installer — every one a
  remember-it-again cost, for the operator AND for dw's onboarding. machine.md
  narrates these but nothing executes them.
- **Outcome:** `fresh-box.sh` in the runbook root (PATH-gated install like
  scaffold/comms-sync/migrator): the idempotent pre-install step for a bare
  Ubuntu-class box. In dependency order: git+curl+gh via apt (gh added only when apt
  lacks it — official keyring recipe, idempotent: existing source.list + keyring skip
  the re-add); `~/Documents/GitHub` dir; runbook clone (refuses to guess over an
  existing non-repo checkout, `git pull --ff-only` refresh of an existing one);
  `~/.local/bin` dir; PATH statement **absent → append the export line to
  `~/.bashrc` idempotently (marker comment); present → skip** (`--check` reports);
  omp (per-machine.yml `omp.install_hint`, executed only when the binary is missing);
  herdr (official installer when missing). Then it PRINTS the follow-on commands it
  never runs (runbook install + doctor, gh/omp auth — interactive or device-flow);
  runs nothing interactive.
- **Proof obligations (`.evidence/fresh-box-01/`, structured JSON):**
  1. `--check` on a bare box: accurate missing-list; **zero filesystem mutation**
     (junk HOME, `find -newer` snapshot — the doctor-is-read-only rule applied to a
     bootstrap); doctor-style bill at the end.
  2. full run in bash-3.2-safe mode on a scratch HOME: dirs created, PATH line
     appended exactly once, re-run = no-op (idempotent), `--check` after = green.
  3. **docker debian:stable-slim e2e** (fresh user, real network): missing gh →
     apt keyring + source + install lands (`gh --version` OK); runbook clone +
     `install.sh --machine`-preconditions green; `--check` before/after honest.
  4. **regression duty:** 32-assertion comms gate, host + bash-3.2 docker, plus
     shellcheck clean; installer doctor still green on this box.
- **Contexts touched:** new `fresh-box.sh`, `install.sh` (§3d install block +
  §2b doctor loop entry + uninstall line + "run again after export" NOTE UX),
  README (tree + fresh-box line), machine.md (§Shared-context box step 5b).
- **NOT:** no sudo-less assumption (apt with sudo, non-root fail = named hatch);
  no apt alternatives when the platform isn't Debian-class (echo + named hatch);
  no per-tool version pins for gh/omp/herdr (version discipline lives in
  machine.yml pins/doctor); no remote wiring, no clone of anything but the
  runbook; no shell-profile editing beyond the missing-PATH line;
  `machine-add`/VPN/SSM/proxy (transport layer, unit 3's VERIFY items) out of
  scope; not called from install.sh (dependency order is fresh-box → install).
- **Depends on:** nothing (machine.yml already carries the omp install_hint).

### Unit preamble-01 — preamble.txt: the operator's opening ask as a stamped template

- **Problem:** the ask arrives in chat (lost at seal) or as a hand-typed intro.txt the
  operator adds to every session folder by hand; three of the last four sessions carry
  one informally. The ask is the WHY of a session — handoffs/conversation record
  conclusions, never the original ask in the operator's words — and a TUI is cramped
  for composing it.
- **Outcome:** `comms/templates/preamble.txt` stamped EMPTY into every fresh session
  folder; filled preamble routes into session-start's printed manifest READ FIRST
  (awk: header/comments/blanks skipped — silent when empty); addenda-only ownership;
  never gates sealing. Documented in comms/README + enclosing AGENTS block.
- **Bugfix found by the unit:** session-end title-fill sed used `/` delimiters with a
  slash-bearing `$SESS` — every template-titled handoff (folders created without
  session-start) refused every seal with `sed: unknown option to 's'`. Pipe
  delimiters; covered by the suite's seal scenarios.
- **Proof:** `comms/prove-preamble.sh` 8/8 host + bash-3.2; lifecycle 32/32 host +
  bash-3.2 (git provisioned per comms-git-01 precedent); scaffold mirror byte-parity
  (all protocol files + AGENTS.md modulo slug), scaffolded end-to-end notice proven.
  Evidence: `.evidence/preamble-01/`.

### Unit herdr-pane-01 — herdr pane surfaces: preamble editor pane + glow viewer

- **Problem:** the preamble road-test in `agent-runbook-next/comms` (live prototype,
  2026-10-14) proved two herdr-pane capabilities the scaffold/installer don't ship:
  (a) inside herdr, session-start should open the stamped preamble in an editor pane
  so the operator types the ask instead of composing in a TUI; (b) any markdown
  (assessments, mind notes, handoffs) should be renderable in a `glow:` pane.
  Prototype proven live (pane list/process-info/idempotent/outside-herdr fail-soft).
- **Outcome:** mirror contract — live comms is canonical, product repo embeds it:
  - `scaffold/new-enclosing-folder.sh`: session-start heredoc gains the herdr
    preamble-pane hook; comms/README heredoc gains the hook bullet; scaffold stamps
    `comms/glow-pane.sh` (new heredoc, extracted from the live prototype); scaffold
    now also creates `work/` (empty) — the edit-copies tier every enclosing folder
    needs by convention.
  - `glow-pane.sh` in runbook root, PATH-gated install (same refuse-fence class as
    comms-sync/fresh-box/artifacts-sync), doctor dexec entry, uninstall line.
  - `migrate-user-comms.sh`: refreshes `comms/glow-pane.sh` (session scripts already
    covered) from the scaffold for old folders.
  - runbook AGENTS block: mind-notes display line (glow-pane) — live
    `~/.omp/agent/AGENTS.md` already carries it.
- **Proof obligations:** junk-parent scaffold build → cmp ALL protocol files +
  glow-pane.sh byte-identical (session-start hook present, work/ created);
  lifecycle gate host + bash-3.2 green; glow-pane outside-herdr fallback renders
  stdout; installer doctor honest on this box (drift is named, not silently green).
- **NOT:** no auto-open of arbitrary files beyond preamble + explicit glow-pane.sh
  invocation; no session-end changes; no herdr server management; no automatic
  firing on the prose tier (glow-pane runs only when invoked); editor probe stays
  vi/nvim fallback (no Windows editor list).
- **Depends on:** nothing (prototype exists live; scaffold mirror is mechanical).

### Unit prior-art-refresh-01 — session-start refreshes prior-art from origin (20261014-02)

- **Problem:** `prior-art/` repos go stale between sessions; an agent referencing one
  reads last-fetch state, not the latest. The operator's ask (preamble 20261014-02):
  session-start should fetch/ff-pull each prior-art repo so references are current.
- **Outcome:** live `comms/session-start.sh` gains a fail-soft prior-art refresh block
  before the intro print: per repo with origin — fetch, dirty-check, ff-only pull
  (`origin HEAD`); per-repo status lines appended to the intro (refreshed <head> /
  DIRTY pull skipped / DIVERGED ff refused / no origin left as-is). No repo is ever
  mutated beyond ff: diversions are named, never resolved, by the script. Mirror
  contract: scaffold session-start heredoc re-spliced from live (byte-parity, cmp);
  doc duty in comms/README "Outside comms" + enclosing README heredoc.
- **Proof obligations (`.evidence/prior-art-refresh-01/`):** fixture arms — refreshed
  (behind → fast-forwarded, head matches origin), DIVERGED (local head kept, refusal
  named), DIRTY (fetch only, pull skipped, tree untouched), no-remote (left as-is),
  empty/missing prior-art (intro unchanged, rc=0), non-repo dir skipped; lifecycle
  gate 32/32 host + bash:3.2; scaffold junk-build byte-parity incl. session-start.
- **Contexts touched:** live comms/session-start.sh + comms/README.md (this enclosing
  folder), scaffold heredocs (session-start, README), ROADMAP.
- **NOT:** no rebase/force resolve (divergence is named, never auto-fixed); no push of
  any kind from prior-art; no non-git prior-art content sync; no session-start flag
  to skip (fail-soft covers every failure); no changes to session-end.
- **Depends on:** nothing (prior-art/ exists in every scaffolded folder since 20260907).

### Unit work-branch-policy-01 — feature-branch floor baked into the enclosing contract (20261014-02)

- **Problem:** `work/` tickets have been committing to `main` (agent-runbook's only
  remote policy so far); other repos under `work/` will likely forbid that, and the
  policy existed nowhere — agent behavior depended on per-session memory.
- **Outcome:** one branch-policy paragraph, byte-identical in three places (cmp
  verified): runbook AGENTS.md (work-copies section), enclosing AGENTS.md heredoc +
  live enclosing AGENTS.md — "every change lands on a feature branch
  (`feature/<unit-or-slug>`) created before the first edit; commit on the branch,
  never main/master; merge to main is the operator's deliberate act". Scaffold bakes
  it into every new enclosing folder at stamp time.
- **Proof obligations (`.evidence/work-branch-policy-01/`):** three texts cmp-equal;
  junk-build scaffold → stamped AGENTS.md carries the paragraph; this session's own
  work/agent-runbook commits landed on `feature/prior-art-refresh-branch-policy`
  (dogfood: branch exists before first edit, no main commit this session); lifecycle
  gate + doctor green after cutover.
- **Contexts touched:** runbook AGENTS.md, scaffold AGENTS heredoc, this enclosing
  folder's AGENTS.md, ROADMAP.
- **NOT:** no enforcement hook (git hooks live in comms/, not work repos — policy
  text only); no branch-name linter; no CI wiring; no retroactive rewrite of the
  existing main history; per-repo stricter rules stay repo-local (this is the floor).
- **Depends on:** nothing.

### Unit session-tie-01 — omp session id ↔ comms folder ↔ work-repo commits (20261014-03)

- **Problem:** the agentic-session tie (overwatch feasibility, operator preamble
  patdabney/20261014-03) had to be DERIVED (cwd-slug + time-window containment).
  Nothing in comms/ is stamped with the omp session UUID; the WORK-repo commit ids
  live only in handoff prose (fine, but undocumented as the tie mechanism).
- **Outcome:** handoff template "How to resume" gains slot 0 — `0. omp agent
  session id: <uuid>` (ONE line — two-line draft defeated the session-end
  completeness fence: its continuation line counted as content); session-start
  intro prints `Session id: <newest transcript uuid for this cwd-slug>` (fail-soft
  `(unknown)` outside omp); session-end fence excludes the untouched slot line as
  boilerplate; scaffold heredocs re-spliced, cmp byte-parity at anchored bounds.
  Slug rule proven 18/18: `"-"+cwd minus $HOME, "/"→"-"`.
- **Proof:** junk arms A/B/C (untouched refuses; id-only refuses; stamped+filled
  seals) in `.evidence/session-tie-01/03-seal-fence.json`; lifecycle 32/32 host +
  bash:3.2 docker. NOT: no overwatch build; no auto-fill of the id by session-end
  (agent-cooperative stamp); no session-end auto-commit.
- **Depends on:** nothing.

### Unit preamble-pane-sealed-01 — preamble pane: sealed-skip + real duplicate guard (20261014-03)

- **Problem:** the pane hook's idempotency guard matched `pane list` for a
  pane label, but this herdr build surfaces no labels (12 keys, verified) —
  the guard never fired; a post-seal `--resume` verification run re-opened
  the preamble pane (operator-visible). Also operator rule: a SEALED session
  should never re-open the ask at all.
- **Outcome:** in `herdr_preamble_pane_setup` (live canonical, scaffold
  heredoc mirror byte-parity): (1) sealed handoff → return 0 before any pane
  work; (2) label filter → cwd match (`.cwd? == $SESS_DIR`, queryable this
  build). Draft behavior unchanged (fresh draft opens exactly one pane).
- **Proof:** junk arms in real herdr (draft opens / same-draft no-dupe /
  sealed opens nothing / live sealed `--resume` opens nothing) —
  `.evidence/preamble-pane-sealed-01/`; lifecycle 32/32 host + bash:3.2.
- **NOT:** no session-end changes; no glow-pane changes; no `--resume` flow
  change beyond the hook; no label/report-metadata usage (fields absent).
- **Depends on:** nothing.

### Unit overwatch-01 — overwatch CLI: the why/what query surface over a derived index (20261014-04)

- **Problem:** the operator's questions — "how did we come to make this change
  (who, what were they thinking)?" and "what did we work on related to this
  commit/class?" — have all material present (transcripts, history.db
  titles/recaps, comms corpus, work-repo commits) but nothing JOINS it; today
  the join is human archaeology. Overwatch is deliberately NOT an agent or
  daemon: batch CLI + derived index, fires only when invoked (design note:
  comms/patdabney/20261014-04/mind/001-overwatch-design.md).
- **Outcome:** `overwatch` CLI (runbook root, PATH-gated install) over
  `comms/.overwatch-index.jsonl` (gitignored, derived, per-node): rebuild /
  status / why <sha|path|symbol> / turns <uuid> [--all] / related <text> /
  tie <uuid|folder>. Tie resolution: handoff slot-0 UUID authoritative,
  transcript-window ∩ comms-folder dates derived (ambiguity kept, never
  guessed), work-repo commits by author-date inside transcript windows
  (`git log --all`); history.db titles/recaps joined read-only; session-start
  gains ONE fail-soft `overwatch rebuild` hook (only when installed).
- **Proof obligations:** `.evidence/overwatch-01/` 01–08 per INTENT
  (rebuild idempotent + pointers-only body check; WHY-join ground truth = the
  20261014-02 commits bb58e65/3c39219/e0d4b07/2c80008 resolving to
  comms/patdabney/20261014-02; symbol-why incl. clean-empty arm; turns on this
  session's uuid; related ranked hits; tie on 20261014-03 + derived-window arm
  for pre-slot-0 20261014-01 + synthetic ambiguous-overlap junk-HOME arm;
  lifecycle 32/32 host + bash:3.2; shellcheck; doctor honest).
- **Contexts touched:** new `overwatch`, comms/session-start.sh (live + scaffold
  mirror), install.sh, README.md, machine.md, machine.yml, ROADMAP.
- **NOT:** no daemon/watcher/cron (never automatic on the prose tier); no omp
  writes; no transcript/comms prose in index or output files (turns print only);
  no committed index snapshot; no prior-art/artifacts/ indexing; no remote
  API (GitHub REST/GraphQL; gh only optional plumbing in a later unit); no
  session-end changes; no sandbox/comms-sync changes.
- **Depends on:** session-tie-01 (slot-0 stamp is an authoritative tie source;
  pre-stamp folders resolve derived — both paths proven).

## Sequencing & lanes

1 → 2 → (3 ∥ 4) → D; unit 5 (fresh-box, 20260930) is independent —
touch-listed contexts only, lanes may slot beside any of them. Unit 1 is the
seed unit (hand-done inline;
gate re-proves the comms priors). Units 2 and 3 touch disjoint files →
parallelizable lanes; 4 slots after 2's shape settles (doctor needs the
wrapper's semantics). verify-<app> for this repo = comms-lifecycle-test.sh
(already forged) + the new assertions; no new gate needed.

## Standing fences (carried)

- Never push without operator's explicit go.
- Hooks don't survive clones — self-heal is in comms-sync, nowhere else.
- No automatic firing on the prose tier, ever (map-level decision, m:006).
- Artifacts never ride the comms repo (blobs) and comms never rides S3
  (POSIX verdict).
- AWS VPN↔VPC routing remains devops-owned and outside this map's scope.