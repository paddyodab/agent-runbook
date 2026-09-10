# SMOKE.md — hit-the-ground-running checklist

Run in a **fresh agent session** after `./install.sh`, in any repo (or a scratch dir).
All five must pass. If one fails, fix before trusting the toolkit.

| # | Check | Pass when |
| --- | --- | --- |
| 1 | **Skills discovered.** Ask the agent: "which skills do you have that mention bro-mode or eng-playbooks?" | Both named; their descriptions match this repo. |
| 2 | **Chat register holds.** Watch any substantive reply. | Answer first, no preamble/recap/closer, lists ≤5, one next action when open. |
| 3 | **Mind channel works.** Ask something that needs depth (e.g. "compare two approaches for X"). | Depth lands in a mind note (`comms/<session>/mind/` or `.mind/`), chat cites it `m:NNN`, chat stays short. |
| 4 | **Drill-in works (herdr only).** Say "mind" while inside herdr. | A pane opens with the note rendered (glow); "unmind" closes it. Without herdr: the path is given in chat instead. |
| 5 | **Door classification works.** Say: "I've got a bug report for my running app" — then "I want to start a new CLI tool." | First answer follows bugfix (reproduce-first); second follows new-codebase (intent-first, hand-do unit, forge verify-<app>). Escalations named, not improvised. |

Notes:

- Check 3 without an enclosing folder writes `.mind/` — gitignore it (installer doesn't
  touch your repo's gitignore deliberately; add `.mind/` yourself when first used).
- A failed check is a bug in this repo, not in your machine. Fix here, re-install,
  re-smoke.