# intent-artifacts-sync-01 — Unit D: the objects tier (artifacts/ ↔ S3-or-rsync)

Unit D of ROADMAP.md, unparked (trigger fired by operator, session
patdabney/20261001-02). Sibling of comms-sync (unit 2, `.evidence/comms-git-02/`) —
same grammar, same discipline. Operator decisions this session: S3 target is wired
LATER (build now, `remote s3://…` when a bucket exists); auth decided AT DEPLOY
(wrapper stays auth-agnostic).

## Problem

artifacts/ has no transport leg. The shared-context loop (EC2 ⇄ laptop ⇄ git/s3)
needs it: comms travels via `comms-sync` (git), work repos carry their own remotes,
and artifacts/ — survey spreadsheets, decks, exports — currently moves by
remembered rsync, which is how nodes drift. Design provenance (ROADMAP trail): S3 =
object tier (export/backup), never a live workspace; electivity is the design;
intentional firing only.

## Proposed outcome

One script, `artifacts-sync`, runbook root, installed via the SAME PATH gate as
scaffold/comms-sync/fresh-box (install.sh §3 pattern):

- `artifacts-sync export [<dir>]` — mirror the folder UP to the wired target.
  Default dir: `./artifacts` (or cwd if it IS artifacts). Target resolution (in
  order): `--target <uri>` flag (one-shot), the `<dir>/.sync-target` file (ONE
  URI — written only by `remote`), `ARTIFACTS_SYNC_TARGET` env. Never guesses
  otherwise: no target → refuse, name the `remote` hatch.
- `artifacts-sync import [<dir>]` — mirror DOWN from the wired target. Missing
  target content = the remote is canonical: seed the folder from it (no prompt).
  Empty local folder + unwired target on EXPORT = refuse (an export with nothing
  canonical would invent canonicality); `--seed <explicit-target>` is the
  deliberate first lift (refuses to guess — the operator names the URI in the
  command itself).
- `artifacts-sync remote <uri> [<dir>]` — wire: verify reachability (s3:
  `aws s3 ls <uri>`; path: `test -d`), then atomically write `<dir>/.sync-target`.
  Refuses an existing DIFFERENT URI (re-wiring is deliberate: `--force` or hand
  edit); same-URI re-wire = idempotent no-op. `--force` on unverifiable (a bucket
  not yet creatable from this box) is allowed and LOUD.
  - `s3://<bucket>` (no prefix) is refused as ambiguous → names the exact
    re-wire with a trailing slash (`s3://<bucket>/` = bucket root).
- `artifacts-sync status [<dir>]` — wired target, reachability, object counts
  both sides, name-only diff (missing-in-dir / missing-in-target lists).

## The mirror fences (the core semantic)

Mirroring is destructive-looking; the fences make every destruction deliberate.
Fence granularity: names are LEAF FILES (relative paths incl. subdirs; S3 objects
have no real directories), compared across both sides. Empty directories do not
travel in v1 (documented; a dir becomes real when its first file lands). On ANY
leaf-file-level divergence (a file exists on only one side):

1. export/import REFUSE. The refusal prints, never executes, the recipe:
   `artifacts-sync --force <name1> [name2…] <dir>` — one-shot mirror of exactly
   the named victims (s3: `aws s3 sync --delete` scoped to the names; local:
   `rsync` the names per direction). After it runs, those names are in sync on
   BOTH sides; nothing else moved.
2. `--force` without names = REFUSE (too broad); `--force` with an unknown name
   = REFUSE (typo protection, names the valid choices).
3. Same-name-different-content = NOT a divergence (mirroring overwrites it
   silently — that is what sync means; newer-wins is a rabbit hole refused by
   design). Deleted-on-one-side = divergence (the fence's whole job).

This mirrors the comms-sync divergence contract: refuse + name the recipe + the
operator executes it deliberately.

## S3 plumbing semantics (proven over moto, not assumed)

- Export: `aws s3 sync <dir> <s3uri> --delete --dryrun` first; the dryrun's
  delete list feeds the fence BEFORE anything destructive; real run only when
  no divergence (or post-`--force`).
- Import: `aws s3 sync <s3uri> <dir>` + first `--dryrun` similarly.
- Prefix boundary: the wired URI ALWAYS carries its trailing slash (enforced at
  `remote` time); every sync command passes the EXACT stored URI — no flag
  re-derivation, no second URI idiom.
- `aws s3 sync` has no --exclude marker file; exclusions live at the TARGET
  layer (a `.gitignore`-style convention is the NOT-list's future unit, not
  now) — v1 mirrors everything wired.

## Proof obligations (.evidence/artifacts-sync-01/, real runs, structured JSON)

1. **01-roundtrip.json** — two local nodes + one target dir; export A→T,
   import T→B; B converges (hash equality incl. subdirs + spaces in names).
2. **02-fences.json** — delete-on-one-side → refusal names the exact `--force`
   recipe; running it mirrors exactly the victims; second run = clean;
   `--force` no-names refuses; unknown name refuses.
3. **03-moto-s3.json** — moto server in docker (real S3 API): wire (s3://…
   with trailing slash), export, import into a second "node dir", fence fires
   on s3-side delete, `--force` reconciles; prefix-boundary case (a peer
   prefix's objects never touched).
4. **04-hatches.json** — unwired export/import/status refusals name `remote`;
   `aws` missing → named hatch; `ftp://` scheme refused; re-wire to a different
   URI refused with the exact command.
5. **05-bash32-docker.json** — local-mode export/import/fences under bash 3.2.
6. **regression** — 32-assertion comms gate green (host + bash 3.2 docker);
   shellcheck clean; installer doctor green (tool loop now includes
   artifacts-sync).

## Invariants

- Intentional firing only: no daemon/cron/watch/comms-hook ever invokes this.
- One URI idiom: the wired `.sync-target` string is passed through verbatim —
  no code path re-derives or normalizes it after the `remote` fence.
- Refusals name hatches: unwired → `remote <uri>`; diverged → the `--force`
  recipe; re-wire → named command; ambiguity → the corrected wire command.
- Never invents canonicality: an unwired export refuses (seeding is explicit).
- bash 3.2 portable (no mapfile/assoc arrays/`;&`; `|| true` on find pipes).
- Electivity: artifacts only — the tool refuses comms/, prior-art/, work/ as
  the working dir (their tiers have their own transports).

## Affected systems

- New `artifacts-sync` (runbook root)
- `install.sh` §3 PATH-gate block (§3e, after fresh-box) + uninstall line +
  doctor `for dexec` loop entry
- `machine.yml` — `aws` runtime dep (optional: true — laptop may run local mode)
- README — "The objects tier (artifacts-sync)" section + tree line
- machine.md — § Shared-context box: artifacts deploy recipe (bucket + wire +
  first lift), auth shapes section (all VERIFY-AT-DEPLOY until a live bucket),
  lockdown amendment: artifacts/ needs `g+w` now (drop-target on the box when
  Dustin or pd drops a survey mid-session) — recorded as a deliberate change to
  the shared-comms-01 result.

## Constraints

- bash 3.2 (BSD/EC2-safe), no new deps beyond the aws CLI when s3 mode is used.
- No interactive prompts anywhere (refusals + recipes instead).

## What this unit is NOT

- No automatic firing of any kind (cron/daemon/watch/inotify/comms hook).
- No comms/, prior-art/, or work/ transport; no per-tier generalization beyond
  the artifacts context; no mega-orchestrator over comms-sync.
- No exclusions/marker-file conventions (v1 mirrors all); no size/time tuning.
- No bucket creation, no Terraform, no real-credential auth choice (machine.md
  documents shapes; all VERIFY-AT-DEPLOY), no E2E-encryption layer, no
  versioning/lifecycle/restore drills.
- No doctor comms-folder sweep (unit 4's separate job).
- No `aws` CLI vendoring/bundling — dep checked, named hatch when missing
  (fresh-box apt recipe gets the awscli line at deploy time when s3 mode is
  chosen, documented in machine.md, not built here).

## Open questions

- (none — target-wiring deferred by operator decision 2026-10-01; auth decided
  at deploy; both recorded in ROADMAP Unit D header.)

## Next steps (each verifiable)

1. Write `artifacts-sync` (bash-3.2; fences before plumbing).
2. install.sh §3e block + doctor loop + uninstall line; machine.yml dep entry.
3. Proof bundle 01–06 per obligations; shellcheck.
4. README + machine.md doc duty; commit; push offer (operator go).