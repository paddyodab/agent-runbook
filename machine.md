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
| `sbx-test.sh` | Same proof in a real Docker Sandbox microVM (`sbx create shell`), virgin HOME, machine install, pinned omp, optional `omp --print` | this repo |
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
   without auth; with `OMP_AUTH` passed in it proves the full model round-trip. For a
   real Docker Sandbox microVM, use `./sbx-test.sh` (same steps; needs `sbx` authenticated).
7. **Enclosing folder (if this box hosts work):** `new-enclosing-folder.sh` — stamps the
   comms protocol, `prior-art/` (clones made read-only: `chmod -R a-w`, reference never
   work target), `artifacts/` (named-file access only, never scanned), worktree rule for
   multi-agent parallelism.

## Sandbox rendering of this manifest (kit/omp + template/)

machine.yml is canonical for what a machine gets. The **sandbox projection** of the same
manifest is `kit/omp/` (a Docker Sandboxes kit, `kind: sandbox`, schema v2) over
`template/Dockerfile` (the omp image). The mirror contract: changes land in machine.yml
first, the kit derives from it — never the reverse.

| machine.yml | kit/omp/spec.yaml |
| --- | --- |
| `machine.omp.version` | `args.omp_version` (pattern-pinned) → template build arg |
| `runtime_deps` (git, gh, glow) | baked in the template image (apt + mise layer) |
| `skills:` | `kit/omp/files/home/.omp/agent/skills/` (regenerate recipe in kit README) |
| `adapters.active` + `adapters.*.secrets` | `args.adapter` + `credentials:` (proxy-managed: real secrets stay on the host, injected at egress) |
| `secrets_policy: manual-interactive` | superseded in-sandbox by credential bindings (`sbx secret set` + first-run approval) — secrets never enter the VM |

Sandbox-first work (any box with Docker Desktop + `sbx`):

1. `sbx kit validate ./kit/omp` — must say VALID.
2. Template: `docker build --build-arg OMP_VERSION=<pin> -t paddyodab/sbx-omp:<pin> template/`
   then `docker image save` + `sbx template load` (or push to a registry).
3. `sbx create ./kit/omp --name <sandbox> <workspace> .` — the omp agent runs in the
   microVM; `sbx exec <sandbox> -- omp --version` matches the pin.
4. Per-domain behavior = mixins stacked with `--kit` (`kit/mixins/<domain>/`), forged when
   a real domain demands one (forge before abstract).

Proven (unit sandbox-kit-01, `.evidence/sandbox-kit-01/`): template build with in-image
pin gate; kit VALID under sbx v0.43.0 (schema v2); live `sbx create` smoke 8/8 checks —
omp pinned, skills + AGENTS block landed, kit args rendered, credentials proxy-sentinels,
agentInstructions present; `omp --print` transport OK, auth absent by design (proxy
binding is the auth path, configured on first real run).

## Proven

- Junk-HOME machine install ×N: skills ×3 symlinked both bases, AGENTS block, scaffold
  with PATH gate, idempotent re-run.
- Doctor: truthful both directions (missing secret reported with hint; silent when
  set); writes **nothing** (verified: no files created under a bare HOME).
- Shortcut adapter in junk HOME: pinned clone at `536e3bd`, `omp plugin link` OK,
  missing-token warning with how-to.
- Docker container (debian stable-slim via `sandbox-test.sh`): full steps 1–3 green in
  ~30 s; step 4 requires auth passthrough by design.
- Docker Sandbox microVM (`sbx-test.sh`): same proof under `sbx create shell`; workspace
  dir must pre-exist (script mkdir's under `~/sandbox-agents/`).
- Scaffold: junk-folder run green; prior-art write refused (`Permission denied` on
  touch and on `git commit`), undo path (`chmod -R u+w`) verified; `artifacts/` present;
  session-start bootstraps.
- bash 3.2 caveat: installer parses machine.yml with awk only (no yaml lib); format is
  the contract — `REFUSED: ... manifest format drift` if the parse comes back empty.

## Field-report fixes (2026-09-18)

Work-laptop first real run surfaced three runbook gaps, all closed:

- **Skill-load scheme:** the AGENTS block said nothing about how skills load; the laptop
  agent tried `rule://eng-playbooks` (rule ids, not skills) and got "Unknown rule". The
  block now names `skill://<name>` as the load path.
- **work/ folder:** operator said "you'll need to create a work folder" and it was
  ignored — no written convention existed. Now: AGENTS block + scaffold README/AGENTS
  template all say ticket work clones to `work/<repo>`, never writes prior-art; operator
  layout instructions are acceptance criteria.
- **Finish line:** a proven fix ended the turn with no push/PR offer. AGENTS block +
  bugfix door reference now require offering the remote step (exact commands ready,
  never pushing without explicit go).