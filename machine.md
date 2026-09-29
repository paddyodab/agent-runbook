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

## Shared-context box (multi-user, AWS) — deployment runbook

One box hosts ONE shared enclosing folder (`/srv/<slug>/`); pd and dw work it over SSH
with herdr. Two herdr servers (one per user) — never one shared server: pane/agent IDs
are scoped per server, and sharing happens at the filesystem layer, not the herdr layer.

```
/srv/<slug>/                  <- the enclosing folder (NOT a git repo)
  comms/                      <- user-keyed sessions: comms/<user>/<YYYYMMDD>-<NN>/
  artifacts/                  <- survey spreadsheets, TGI leadership docs
  prior-art/                  <- read-only reference clones
  work/<repo>/                <- edit copies (git-checked)
```

Permissions (boring Unix; proven in `.evidence/shared-comms-01/04`):
- one shared group (e.g. `shared`); both users in it
- `chmod g+rX` tree-wide, `find -type d -exec chmod g+s` (setgid), `g+w` on comms/
- `umask 002` in each user's shell profile → anything either user creates is
  group-writable by the other

Deprovision to provision (order matters):

**Decisions (answered 2026-09-28):** region **us-east-1**; remote entry = **company VPN**
(same pattern as the established accounts: a vpn security group attached to the instance,
source = the VPN's egress CIDR — one rule, no per-laptop IPs); **devops owns root MFA**
(and, by the same pattern, instance + sg attachment + budget alert); backups stay
**experimental-simple**: EBS snapshots, S3 sync offered as an optional spin-off/export,
prod-grade ceremony (audit logging, restore drills, nightly S3) deferred until this
survives two real users.

1. **EC2**: us-east-1, Ubuntu LTS, t3.small class (t3.micro's 1 GiB is fragile with two
   simultaneous omp agents + herdr servers; treat size as an observed capacity decision
   after a two-user session, not a permanent architecture). This is I/O-light. Security
   group: TCP 22 only. No HTTP/S, no database, no public application endpoint.

   **SSH source (the decided mechanism, not a generic CIDR):** source =
   the company VPN's **AWS-managed prefix list** (`pl-gpvpn-pool-subnets`, shared
   into this account via Resource Access Manager — reference it by ID, never copy
   CIDRs) attached as the SG rule's source. Two acceptance checks at deploy,
   because the SG rule alone does not move packets: (a) ROUTE — the VPN's
   transit-gateway/VPN attachment in the pre-prod VPC actually routes to this
   subnet both directions (this is exactly the current timeout class); (b) the
   subnet NACLs allow 22 in / ephemeral out. A correctly configured SG with no
   route is indistinguishable from a wrong SG until something dials.
2. **Users + group**:
   ```bash
   sudo addgroup shared
   sudo adduser --ingroup shared pd
   sudo adduser --ingroup shared dw
   ```
3. **Enclosing folder**: create via the scaffold ON THE BOX (install.sh puts
   `new-enclosing-folder.sh` on PATH), or rsync an existing folder up.
4. **Seed content from the work laptop FIRST — while pd still owns the tree**
   (the "state of the state": Snowflake staging spec, artifacts/, prior-art/):
   ```bash
   # ON THE BOX: pd owns /srv/<slug> until step 5; SSH in and rsync as pd
   rsync -av --exclude '.agent' ~/path/to/local/folder/ pd@<ec2-host>:/srv/<slug>/
   ```
   ⚠️ Named-before-sync rule: anything laptop-only must be moved OUT of the folder
   before the first rsync — artifacts/ becomes group-readable on arrival.
   (Order matters — the laptop review caught it: applying step 5's root- ownership
   + read-only reference perms BEFORE seeding would leave pd unable to create
   files in artifacts/, prior-art/, or the folder root, breaking this transfer.)
5. **Ownership + permission lockdown, AFTER the seed** (proven in
   `.evidence/shared-comms-01/04`):
   ```bash
   sudo chown -R root:shared /srv/<slug>
   sudo chmod -R g+rX /srv/<slug>
   sudo find /srv/<slug> -type d -exec chmod g+s {} +
   sudo chmod -R g+w /srv/<slug>/comms /srv/<slug>/work
   ```
   Result: comms/ and work/ are group-writable (the protocol needs it); artifacts/
   and prior-art/ settle read-only for the group (reference, never a work target);
   fresh top-level entries require sudo — by design (a new top-level dir is a
   deliberate layout change, not an accident).
6. **Per-user omp + agent-runbook** (as each user):
   ```bash
   sudo -iu pd
   git clone <agent-runbook-repo-url> ~/agent-runbook && cd ~/agent-runbook
   ./install.sh --machine && ./install.sh --doctor --machine
   ```
   Each user gets their own `~/.omp` (omp credentials in agent.db are per-user).

   **Model auth — GitHub Copilot (per-user, device flow):** as each user, on the box:
   ```bash
   omp login github-copilot   # prints URL + device code; complete it in a browser
                              # on YOUR laptop (github.com/login/device) — no browser
                              # needed on the box itself
   omp usage                  # verify: shows the authenticated account + limits
   ./install.sh --doctor --machine   # re-run for a clean bill
   ```
   Each user logs in with their OWN GitHub account holding a Copilot seat
   (attribution + offboarding = seat management). Two omp homes, one shared
   omp install — never a shared credential store. If org policy DENIES the
   integration ids omp uses (403), an org admin must allow `copilot-chat` or
   `copilot-developer-cli` (`COPILOT_INTEGRATION_ID` pins one). If seat pooling
   is ever a hard requirement, omp's `auth-broker`/`auth-gateway` (credential
   vault + forward proxy, `OMP_AUTH_BROKER_URL`) is the designed path — but it
   adds a service; per-user seats avoid it.
7. **Keep herdr servers alive after SSH logout** (per user):
   ```bash
   sudo loginctl enable-linger pd && sudo loginctl enable-linger dw
   # as the user, once: herdr server   (headless; persists across SSH sessions)
   ```
   VERIFY AT DEPLOY (first-probe item): herdr socket paths are per-user (XDG runtime
   dir). If two users' sockets collide, the per-user isolation assumption is broken —
   check `herdr api status` as each user before declaring the box done.
8. **From each laptop — connect**:
   ```bash
   herdr machine add       # saves the SSH profile; prepares the remote server
   herdr --remote <target> # interactive attach to the remote herdr server
   herdr --machine <label> agent prompt <name> "status" --wait --timeout 120000
   ```
   Guardrails (from `herdr --skill`): only add/remove machine profiles when the user
   asks; setup asks before stopping an incompatible remote server (default No); a
   connection failure does not prove a mutation was not applied — inspect remote state
   before retrying.

Migrating EXISTING enclosing folders (work laptop, old folders): run the migration
script once per folder —
```bash
./migrate-user-comms.sh <enclosing-folder>   # or run inside the folder with no arg
```
It moves flat pre-fork sessions into `comms/<user>/`, replaces stale single-user
scripts with the current ones (extracted from this repo's scaffold), stamps
missing templates, and is idempotent (second run = check-only). Old unsealed drafts
stay drafts; ledgers are NOT rewritten (absolute-path keyed — old digests keep their
old address; new appends key on the new one).

Session protocol on the box (what changes for the users): `cd /srv/<slug>` first;
`./comms/session-start.sh` keys sessions to your OS user automatically
(`comms/<user>/<YYYYMMDD>-<NN>/`). Canonical state is CROSS-USER: newest sealed handoff
anywhere in `comms/` is what the next session resumes from — ordered by DATE-SEQ across
users, never by user name (same date-seq from different users = deterministic user-name
tie-breaker, documented in comms/README.md; NOT chronology). Ledger is per-user; a
cross-user seal writes the digest to the SEALING user's ledger. Smoke (both users):
fresh start → intro names `comms/<user>/<today>-01`; the OTHER user can still
fresh-start while yours is open; bare seal with no session of your own refuses naming
the prefixed salvage command.

Acceptance on the host: `./comms-lifecycle-test.sh /srv/<slug>` — 18 assertions in a
disposable /tmp fixture staged from the folder's comms/ scaffold (the run never
mutates the named folder — live ones are safe to point at), incl. the cross-user
CHRONOLOGY scenario: a late-alphabet user's older handoff must lose to an
early-alphabet user's newer one — the path-sort regression the pre-AWS probe
caught. If seeding from an existing folder instead of fresh scaffolding, run
`./migrate-user-comms.sh /srv/<slug>` first.

Protocol proofs: `./comms-lifecycle-test.sh <enclosing-folder>` (two fake users,
18 assertions, disposable /tmp fixture; green on bash 5.3 host and stock bash 3.2
in docker), evidence in `.evidence/shared-comms-01/`.

Not covered here (deliberate): **S3 as the live filesystem** — the comms protocol is
POSIX (find/grep/mv/awk, setgid, chmod, OS-user attribution) and an object store has
none of that (Mountpoint-for-S3 drops the metadata the protocol relies on); the box +
EBS gives POSIX semantics for free, and "spin off a shared context" =
`aws s3 sync /srv/<slug>/comms/ s3://<bucket>/<slug>/` as an optional export command.
EBS snapshots are the experimental-simple backup; nightly S3, restore drills, and
audit logging wait until this survives two real users. Also out: omp-remote (separate
project), Kubernetes/EFS/RDS/web UI (V0 out of scope), anything fancier than
SSH+users+group (the primitive is proven; justify additions against a real shortfall).