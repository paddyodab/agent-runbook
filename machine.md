# machine.md — shared-context box (AWS) deployment runbook

One EC2 box hosts ONE shared enclosing folder (`/srv/<slug>/`); pd and dw work it over
SSH with herdr. Two herdr servers (one per user) — never one shared server: pane/agent
IDs are scoped per server, and sharing happens at the filesystem layer, not the herdr
layer.

## Layout on the box

```
/srv/<slug>/                  <- the enclosing folder (NOT a git repo)
  comms/                      <- user-keyed sessions: comms/<user>/<YYYYMMDD>-<NN>/
  artifacts/                  <- survey spreadsheets, TGI leadership docs
  prior-art/                  <- read-only reference clones
  work/<repo>/                <- edit copies (git-checked)
```

Permissions (boring Unix; proven in .evidence/shared-comms-01/04):
- one shared group (e.g. `shared`); both users in it
- `chmod g+rX` tree-wide, `find -type d -exec chmod g+s` (setgid), `g+w` on comms/
- `umask 002` in each user's shell profile → anything either user creates is
  group-writable by the other

## Deprovision to provision (order matters)

1. **EC2**: Ubuntu LTS, small (t3.micro class is plenty; this is I/O-light). Security
   group: SSH (22) from the office/home IPs only — nothing else needs ingress.
2. **Users + group**:
   ```bash
   sudo addgroup shared
   sudo adduser --ingroup shared pd
   sudo adduser --ingroup shared dw
   ```
3. **Enclosing folder**: create via the scaffold ON THE BOX (install.sh puts
   `new-enclosing-folder.sh` on PATH), or rsync an existing folder up (next step).
   Then:
   ```bash
   sudo chown -R root:shared /srv/<slug>
   sudo chmod -R g+rX /srv/<slug>
   sudo find /srv/<slug> -type d -exec chmod g+s {} +
   sudo chmod -R g+w /srv/<slug>/comms /srv/<slug>/work
   ```
4. **Seed content from the work laptop** (the "state of the state": Snowflake spec,
   artifacts/, prior-art/):
   ```bash
   rsync -av --exclude '.agent' ~/path/to/local/folder/ pd@<ec2-host>:/srv/<slug>/
   ```
   ⚠️ Named-before-sync rule: anything laptop-only (payroll-ish, personal, not-yet-
   shared) must be moved OUT of the folder before the first rsync. artifacts/ becomes
   group-readable on arrival.
5. **Per-user omp + agent-runbook** (run as each user):
   ```bash
   sudo -iu pd
   git clone <agent-runbook-repo-url> ~/agent-runbook && cd ~/agent-runbook
   ./install.sh --machine          # machine.yml pins + dep checks + adapter
   ./install.sh --doctor --machine # then: nothing missing, nothing drifted
   ```
   Each user gets their own `~/.omp` (credentials in omp's agent.db are per-user).
6. **Keep herdr servers alive after SSH logout** (per user):
   ```bash
   sudo loginctl enable-linger pd
   sudo loginctl enable-linger dw
   # as the user: start the headless server once; it persists across SSH sessions
   herdr server
   ```
   VERIFY AT DEPLOY (first-probe item): herdr socket paths are per-user (XDG runtime
   dir). If two users' sockets collide, the per-user isolation assumption is broken —
   check `herdr api status` as each user before declaring the box done.
7. **From each laptop — connect**:
   ```bash
   herdr machine add       # saves the SSH profile; prepares the remote server
   herdr --remote <target> # interactive attach to the remote herdr server
   # or drive the remote agent from a local pane:
   herdr --machine <label> agent prompt <name> "status" --wait --timeout 120000
   ```
   Guardrails (from `herdr --skill`): only add/remove machine profiles when the user
   asks; setup asks before stopping an incompatible remote server (default No); a
   connection failure does not prove a mutation was not applied — inspect remote
   state before retrying.

## Session protocol on the box (what changes for the users)

- `cd /srv/<slug>` first; `./comms/session-start.sh` keys sessions to your OS user
  automatically: `comms/<user>/<YYYYMMDD>-<NN>/`.
- The canonical state is CROSS-USER: the newest sealed handoff anywhere in `comms/`
  is what the next session resumes from. Seal your own sessions; seal a colleague's
  abandoned draft only deliberately (`./comms/session-end.sh <user>/<YYYYMMDD>-<NN>`).
- Ledger is per-user (`~/.agent/learnings.md`); cross-user seals write to the
  SEALING user's ledger.
- Smoke on the box (both users): fresh start → intro names `comms/<user>/<today>-01`;
  while your session is open the OTHER user can still fresh-start; bare seal with no
  session of your own refuses naming the prefixed salvage command.

## What this runbook deliberately does NOT cover

- S3/IAM/snowflake access patterns from the box (work-specific; the Snowflake staging
  spec lives in artifacts/ — named-file access only).
- omp-remote (separate project).
- Anything fancier than SSH+users+group (the primitive is proven; justify additions
  against a real shortfall).