# PROOF — vendored-skills-01

Mode: inline (single-context edit: vendoring + installer/manifest wiring + docs).
No lanes. Session of record: comms/patdabney/20261015-01.

## What was built

- `skills/diagram-design/` vendored from prior-art/diagram-design (the diagram-design
  plugin repo's packaged skill, v2.6): SKILL.md + 60 references + 5 scripts + 215
  assets+examples (5.7M, 286 files). Provenance header added to SKILL.md per the
  turborepo vendoring convention; `Update by re-vendoring here, then re-run install.sh`.
- `machine.yml`: skill entry + optional dep `python3` (verify/self_check scripts).
- `install.sh`: classic `SKILL_DIRS` += diagram-design. Machine mode needed no code
  change — the manifest awk parse is list-driven (proven: 5 skills parsed).
- `sandbox-test.sh` / `sbx-test.sh`: diagram-design symlink assertion added.
- Docs: README (tree line + prose bullet), machine.md (pieces table row), ROADMAP
  (unit vendored-skills-01 with proof obligations, marked satisfied here).

## Latent gap found and fixed (regression duty doing its job)

overwatch-01 made sqlite3 + jq REQUIRED manifest deps, but `sandbox-test.sh`'s docker
bootstrap never installed them — step 2's install REFUSED in-container ("required
runtime dep missing: sqlite3", then jq). The manifest gate was working; the proof
image was stale vs the manifest. Fixed by adding sqlite3 + jq + python3 to the
container apt layer. The refusal is itself evidence the dep gate fires (02 artifact).

## Bugs found while building

None in the new wiring. Two expected doctor reports verified truthful: on the live
box, installed skills "drift" to the reference clone (merge + reinstall is the
cutover, per the machine-tier standing rule) and diagram-design "missing" until then.

## Verification (artifacts)

| # | Claim | Result |
| --- | --- | --- |
| 01 | fresh-HOME machine install symlinks diagram-design to BOTH roots | PASS |
| 02 | docker machine install green incl new symlink; dep-refuse gate proven, bootstrap fixed | PASS |
| 03 | lifecycle gate 32/32 host + bash 3.2 docker `bash -n` clean on edited scripts | PASS |
| 04 | skill functional: self_check.py PASS on shipped asset; mermaid_extract.py digests sample | PASS |

## Verdict

PASS. Cutover plan: merge → reference clone ff → `install.sh --doctor` (reference is
the install source) → `install.sh --machine` re-run flips live symlinks to merged main.