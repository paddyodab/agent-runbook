# PROOF — sandbox-kit-01 (template + omp sandbox kit, by-the-book forge)

Mode: inline seed unit (eng-playbooks, existing-codebase door — the repo runs, we extend
its artifact set; verify surface = sbx CLI + live sandbox, the app here is the sandbox).

## Mode
Inline (no delegation): single-context unit (template/ + kit/omp/), operator watching.
This is the seed unit the m:003/m:004 plan called for — forge before abstract.

## Artifacts
- 01-template-build.json — image build + build-time gates (incl. one caught bug: version
  string was `omp/…` not `oh-my-pi/…`; the build refused, the gate worked)
- 02-kit-validate.json — `sbx kit validate` VALID (v2); parser rejected the v1-style
  `files:` block → static files moved to `files/` tree per SPEC-v2 §5.8
- 03-live-smoke.json — `sbx create ./kit/omp` + exec checks; all 8 checks observed pass

## Lane review
Single lane; no cross-file collisions. Diff scope: template/, kit/, .evidence/,
machine.md mirror-contract note, README table row. No other behavior touched.

## Gate notes
Gate = this session's operator (foreman role) re-observed every check output directly in
the transcript: sbx kit validate VALID, sbx create green, 8/8 exec checks pass. Claims in
the JSONs are quoted from tool output, not summarized.

## Verdict
PASS with 2 open questions carried (profile-file location convention; credential
bindings on first real run). Neither blocks unit 2 (delegated lane through the kit).
