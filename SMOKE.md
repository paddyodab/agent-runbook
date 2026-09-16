# SMOKE.md — hit-the-ground-running checklist

Run in a **fresh agent session** after `./install.sh`, in any repo (or a scratch dir).
All five session checks must pass. If one fails, fix before trusting the toolkit.
Machine-mode checks (6–10) apply when the box was set up with `install.sh --machine`.

| # | Check | Pass when |
| --- | --- | --- |
| 1 | **Skills discovered.** Ask the agent: "which skills do you have that mention bro-mode or eng-playbooks?" | bro-mode, eng-playbooks, and fan-out-lanes named; descriptions match this repo. |
| 2 | **Chat register holds.** Watch any substantive reply. | Answer first, no preamble/recap/closer, lists ≤5, one next action when open. |
| 3 | **Mind channel works.** Ask something that needs depth (e.g. "compare two approaches for X"). | Depth lands in a mind note (`comms/<session>/mind/` or `.mind/`), chat cites it `m:NNN`, chat stays short. |
| 4 | **Drill-in works (herdr only).** Say "mind" while inside herdr. | A pane opens with the note rendered (glow); "unmind" closes it. Without herdr: the path is given in chat instead. |
| 5 | **Door classification works.** Say: "I've got a bug report for my running app" — then "I want to start a new CLI tool." | First answer follows bugfix (reproduce-first); second follows new-codebase (intent-first, hand-do unit, forge verify-<app>). Escalations named, not improvised. |
| 5b | **Fan-out canary (herdr).** With herdr up, ask: "run a fan-out canary only — no real unit." | A short pane runs, wait completes, skill refuses real lanes without sealed intent + verify-<app>. `HANDOFF.template.md` is cited. Without herdr: skill names degraded mode. |

Notes:

- Check 3 without an enclosing folder writes `.mind/` — gitignore it (installer doesn't
  touch your repo's gitignore deliberately; add `.mind/` yourself when first used).
- A failed check is a bug in this repo, not in your machine. Fix here, re-install,
  re-smoke.

## Machine-mode checks (fresh box / after `install.sh --machine`)

| # | Check | Pass when |
| --- | --- | --- |
| 6 | **Skills match the manifest.** `ls -la ~/.omp/agent/skills/` | bro-mode, eng-playbooks, fan-out-lanes, turborepo are symlinks into the runbook repo. |
| 7 | **Doctor is honest and clean.** `./install.sh --doctor --machine` | "nothing missing, nothing drifted" — or the report names exactly what's absent (e.g. a secret), and it IS absent. |
| 8 | **Adapter matches the machine.** Personal box: adapter `none`/`gh-issues`, no shortcut extension (`omp plugin list`). Work box: shortcut cloned at the pinned commit under `~/.omp/adapters/` and linked. |
| 9 | **Sandbox proof (container).** `./sandbox-test.sh` on a docker host | All steps green; step 4 (`omp --print`) SKIPs without auth by design. |
| 9b | **Sandbox proof (sbx microVM).** `./sbx-test.sh` where Docker Sandboxes is installed | All steps green; step 5 SKIPs without auth by design. |
| 10 | **Version pin holds.** `omp --version` | Matches `machine.yml` `omp.version` exactly. |
