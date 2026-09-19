# kit/omp — the omp sandbox kit (Docker Sandboxes, schema v2)

The sandbox rendering of machine.yml. `kind: sandbox` — defines the omp agent
for Docker Sandboxes the way machine.yml defines it for bare metal.

- `spec.yaml` — the kit manifest (image, entrypoint, credentials, network,
  environment, install check, agentInstructions)
- `files/home/.omp/agent/` — the AGENTS.md marked block + skills, extracted
  from this repo (see scripts below); never hand-edited here
- `../../template/Dockerfile` — builds `paddyodab/sbx-omp:<version>`, the
  image this kit's `sandbox.image` points at

## Regenerate the payload from the repo (canonical source)

```bash
cd kit/omp
mkdir -p files/home/.omp/agent/skills
sed -n '/BLOCK:BEGIN:agent-runbook/,/BLOCK:END:agent-runbook/p' ../../AGENTS.md \
  > files/home/.omp/agent/AGENTS.md
rm -rf files/home/.omp/agent/skills/*
for s in bro-mode eng-playbooks fan-out-lanes turborepo; do
  cp -r ../../skills/$s files/home/.omp/agent/skills/$s
done
```

## Validate + smoke

```bash
sbx kit validate ./kit/omp
sbx kit inspect ./kit/omp
# local template (no registry needed):
docker build --build-arg OMP_VERSION=18.2.0 -t paddyodab/sbx-omp:18.2.0 template/
docker image save paddyodab/sbx-omp:18.2.0 -o /tmp/sbx-omp.tar
sbx template load /tmp/sbx-omp-18.2.0.tar
# create + inspect:
sbx create ./kit/omp --name smoke ~/sandbox-agents/smoke .
sbx exec smoke -- bash -lc 'omp --version; ls ~/.omp/agent/skills/'
sbx rm -f smoke
```

## Mirror contract

machine.yml is canonical for what a machine gets (versions, deps, adapter,
secrets policy). The kit derives: `args.omp_version` ↔ `machine.omp.version`,
`args.adapter` ↔ `adapters.active`, credentials ↔ `adapters.*.secrets`,
network allow-list ↔ the domains the pinned deps need. Changes land in
machine.yml first, then the kit — never the reverse.
