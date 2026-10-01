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
  artifacts/      S3 prefix sync, elective    (PARKED - unit D trigger-gated)
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

### Unit D (PARKED — trigger-gated) — artifacts S3 wrapper

- **Do not build until:** the first laptop-only artifact exists AND would
  be synced. Trigger recorded here; this unit does not exist on the map
  otherwise. (S3 auth unproven on both nodes; electivity is the design.)

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

## Sequencing & lanes

1 → 2 → (3 ∥ 4) → D(trigger); unit 5 (fresh-box, 20260930) is independent —
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