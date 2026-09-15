# machine.md — turning any box into a working omp (the declarative machine)

The operator's global omp area is not *the* agent — it is *a build output*: reproducible
from this runbook + `machine.yml` onto any box (this desktop, the work laptop, a VPS, a
docker sandbox). Fresh install, all the extras, nothing accumulated by accident.

## The pieces

| Piece | What it is | Source of truth |
| --- | --- | --- |
| `machine.yml` | The manifest: omp version pin, runtime deps with checks, skill list, ticketing adapter slot, secrets policy | this repo |
| `install.sh --machine` | Manifest-driven install: skills symlinked, AGENTS.md block, scaffold, adapter clone + omp plugin link, secrets *gated* (never written) | this repo |
| `install.sh --doctor` | Read-only report: what's missing, what drifted. Runs before every mutation, writes nothing | this repo |
| `sandbox-test.sh` | The proof: docker container (debian + the repo mounted), fresh HOME, machine install, pinned omp via mise, `omp --print` round-trip when auth is provided | this repo |
| scaffold (`new-enclosing-folder.sh`) | The enclosing-folder stamp (comms protocol, prior-art read-only, artifacts/) | this repo |

## Ticketing = an adapter slot, not a runbook feature

Ticketing is a property of the workplace, not the repo. `machine.yml` holds exactly one
active adapter per machine; the runbook never bakes one in.

| Adapter | Skills | Extension | Secrets | Where |
| --- | --- | --- | --- | --- |
| `none` | — | — | — | personal repos, no ticket system |
| `gh-issues` | TODO: write on first forge | — | `gh auth login` (interactive) | personal repos using GitHub issues |
| `shortcut` | ships in the extension repo | omp-shortcut (`omp plugin link`, pinned commit) | `SHORTCUT_API_TOKEN` (export; create at app.shortcut.com → settings → API tokens) | work (NRC) |

Rules the adapters inherit:

- omp-shortcut is **one implementation** of the slot, not the slot itself. Its repo is
  cloned to `~/.omp/adapters/<name>` at the manifest's pinned commit — an upstream pull
  is a deliberate manifest change, never a silent behavior shift.
- The shortcut adapter is work-laptop-only. A personal box keeps `active: none` (or
  `gh-issues`); the extension must not be installed there.
- A new ticketing system (Jira, ...) = a new adapter definition in `machine.yml`,
  two-implementation rule still applies: abstract the slot only after the second real
  adapter is proven.

## Fresh-box sequence (work laptop, VPS, sandbox — same steps)

1. **Pre-reqs by hand:** git + curl (the manifest gates on the full `runtime_deps` list
   and names each check). Secrets are interactive by policy: `gh auth login`,
   `export SHORTCUT_API_TOKEN` — the installer checks presence and prints the how-to,
   never writes values.
2. **Get the runbook:** `git clone https://github.com/paddyodab/agent-runbook` (or copy
   the repo to the box — it is the source of truth for everything installed).
3. **Install:** `./install.sh --machine`. Refusals are the contract: a foreign skill dir
   or a differing scaffold names its exit path; reconcile, re-run.
4. **omp:** the manifest pins the version (`omp.install_hint` carries the mise command).
   `mise use -g github:can1357/oh-my-pi@<pin>`; shim path:
   `~/.local/share/mise/shims` on PATH.
5. **Doctor:** `./install.sh --doctor --machine` — must end "nothing missing, nothing
   drifted". If it lists a missing secret, that is the honest state until step 1's
   exports happen; re-run after.
6. **Prove it (sandbox or the real box):** `./sandbox-test.sh` — proves in a container:
   machine install green, pinned omp runs, scaffold lands. Step 4 (`omp --print`) skips
   without auth; with `OMP_AUTH` passed in it proves the full model round-trip.
7. **Enclosing folder (if this box hosts work):** `new-enclosing-folder.sh` — stamps the
   comms protocol, `prior-art/` (clones made read-only: `chmod -R a-w`, reference never
   work target), `artifacts/` (named-file access only, never scanned), worktree rule for
   multi-agent parallelism.

## Proven

- Junk-HOME machine install ×N: skills ×3 symlinked both bases, AGENTS block, scaffold
  with PATH gate, idempotent re-run.
- Doctor: truthful both directions (missing secret reported with hint; silent when
  set); writes **nothing** (verified: no files created under a bare HOME).
- Shortcut adapter in junk HOME: pinned clone at `536e3bd`, `omp plugin link` OK,
  missing-token warning with how-to.
- Docker sandbox (debian stable-slim): full steps 1–3 green in ~30 s; step 4 requires
  auth passthrough by design.
- Scaffold: junk-folder run green; prior-art write refused (`Permission denied` on
  touch and on `git commit`), undo path (`chmod -R u+w`) verified; `artifacts/` present;
  session-start bootstraps.
- bash 3.2 caveat: installer parses machine.yml with awk only (no yaml lib); format is
  the contract — `REFUSED: ... manifest format drift` if the parse comes back empty.