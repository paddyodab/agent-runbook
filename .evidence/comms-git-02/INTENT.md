# intent-comms-git-02 — comms-sync (import/export/remote/status) with hook self-heal

Unit 2 of ROADMAP.md (comms-as-git transport tier). Sealed 2026-09-29, session
patdabney/20260929-02 (reopened). Predecessor: `.evidence/comms-git-01/` (unit 1, the
hook + repo-at-scaffold, commit bff5be1).

## Problem

Cross-node comms transport today = 4 manual git commands per direction plus the hook
self-heal the operator must remember. Clones don't inherit hooks; a forgotten re-stamp
means the credential gate silently doesn't run on the new node. Divergence has exactly
one legitimate semantic conflict (two users creating the same `<user>/<date>-<NN>` —
the shared date-seq namespace) and today there is no named recipe for it.

## Proposed outcome

One script, `comms-sync`, in the runbook root, installed via the SAME PATH gate as
scaffold + migrator (install.sh §3 pattern), refusing/cmp-fence over a foreign file:

- `comms-sync import [<comms-path>]` — default `./comms` (or cwd if it IS comms);
  refuses when no remote is set (names `remote <url>`); `git pull --ff-only`
  (+ loud diverge hatch naming the exact recovery commands); re-stamps the hook if
  missing (calls the SAME stamp logic as migrate-user-comms.sh §3b in spirit — one
  copy of the hook source resolution: extract from the scaffold heredoc if scaffold
  is next to this script, else from the tracked `hooks/pre-push` copy in the comms
  tree itself); optionally `--resume` flag invokes `./comms/session-start.sh --resume`
  after a successful pull (the session-boundary pairing).
- `comms-sync export [<comms-path>]` — refuses when no remote; status-dirty check →
  commit-if-needed with a printed message convention (`session data: <summary>` —
  NOT opinionated); hook self-heal BEFORE pushing (missing/stale → stamp, matching
  migrate §3b semantics: active copy + tracked copy cmp-equal); `git push --atomic`
  (the pre-push hook runs here); reports ahead/behind after.
- `comms-sync remote <url> [<comms-path>]` — refuses when a remote already exists
  AND differs (re-wiring is a deliberate `git remote set-url` by hand — refuse-to-guess);
  verifies the URL is reachable (ls-remote) before writing; prints the tracking setup.
- `comms-sync status [<comms-path>]` — per-repo: branch, ahead/behind vs upstream,
  dirty file count, hook present (+cmp vs tracked copy).

Divergence recipe (the one semantic conflict): if `pull --ff-only` fails because
BOTH sides advanced, import REFUSES with a printed recipe:
  1. `mv comms/<user>/<date>-NN /tmp/collide`
  2. `git pull --ff-only` (now fine)
  3. `mv /tmp/collide comms/<user>/<date>-NN.<node>`
  4. session scripts treat the suffixed folder as a distinct session (sequence
     numbers tolerate gap+suffix; find patterns match `[0-9]{8}-[0-9]{2}` so the
     suffixed name is EXCLUDED — deliberate: a collision rename is a foreign
     session, read but not counted; comms/README documents this)
The refusal NAMES these commands; it never executes them.

## Proof obligations (.evidence/comms-git-02/, real runs, structured JSON)

1. **01-export-import.json** — two clones of ONE comms repo (bare fixture remote +
   the real GitHub repo): node A seals an innocent session, `comms-sync export`;
   node B `comms-sync import` → sealed handoffs present, newest-sealed resolution
   identical on both nodes (same `git log` tips).
2. **02-divergence.json** — both nodes create `u1/20260929-01` independently →
   import REFUSES naming the rename recipe; operator executes the recipe by hand →
   merge succeeds; both nodes converge (the rejection-path proof).
3. **03-self-heal.json** — clone's `.git/hooks/pre-push` deleted → `export` self-heals
   (stamps, cmp-equal to tracked copy) THEN pushes; a leaky commit via the healed
   node is still REFUSED (self-heal is not a bypass).
4. **04-status-remote.json** — `status` reports branch/ahead/dirty accurately
   (fixture: hand-crafted states); `remote` refuses to overwrite an existing
   different URL; `remote` verifies reachability (ls-remote) before writing.
5. **05-bash32-docker.json** — same two-node flow under bash 3.2 (git provisioned)
   — export→import + self-heal proven in the container.
6. **regression** — 28-assertion gate green host + bash 3.2 after the change
   (the gate does not drive comms-sync directly; unit-2's proofs are this bundle's
   scripts, run against BOTH the bare-fixture remote and the real remote).

## Invariants

- Intentional firing only: no daemon, no cron, no hooks that fire comms-sync; it is
  always a human/agent explicit command at a session boundary (map-level decision).
- Never invents state: no merge with strategy other than ff; the diverge path
  REFUSES and names commands (operator executes; the collision rename is a semantic
  merge only humans do).
- One resolver: comms-sync resolves the hook source the same way migrate §3b does
  (scaffold heredoc if available; else comms/hooks/pre-push tracked copy). No second
  extraction idiom.
- Refusals name hatches: missing remote → names `comms-sync remote <url>`;
  diverged → names the rename recipe; already-wired → names `git remote set-url`.
- bash 3.2 portable (no mapfile, `|| true` on find, no `;&`).

## Affected systems

- New `comms-sync` (runbook root)
- `install.sh` (tool-install block + doctor check — added to the existing
  `for dexec` loop, `comms-sync` source = `$HERE/comms-sync`)
- README ("Comms-as-git" section: five subcommands) + machine.md (step 3 gains
  `comms-sync clone`-era note? NO — clone stays plain git + migrate; documented,
  not built. machine.md references comms-sync remote in step 3's wiring.)

## NOT-list

- No automatic firing (cron/daemon/inotify) on the prose tier, ever.
- No `clone` subcommand (plain git clone + migrate covers it; recipe documented
  in comms/README, not code — forge-before-abstract: build it when a second node
  actually onboards).
- No per-tier S3/artifacts wrapper (parked unit D).
- No merge conflict resolution, no history rewrite, no pattern-set changes (v1).
- No doctor changes beyond the tool-parity loop entry.

## Open questions

- (none) Remote URL convention settled by operator 2026-09-29: `<slug>-comms`
  (recorded in conversation.md reopened block; unit-2 remote prints it as the
  suggested name, but never constructs URLs itself).

## Next steps

1. Write `comms-sync` (bash-3.2 portable; refusals name hatches).
2. Installer: PATH-gate block + doctor `for dexec` addition.
3. Two-node proofs fixture + real-remote spot check; evidence bundle.
4. README/machine.md doc duty; commit; push (operator go).