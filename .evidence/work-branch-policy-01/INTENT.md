# INTENT — work-branch-policy-01 (20261014-02)

## Problem
`work/` tickets have been committing to `main` (agent-runbook so far); other repos
under `work/` will likely forbid direct-to-main. The policy existed nowhere — agent
behavior depended on per-session memory. Operator ask (preamble.txt 20261014-02):
bake feature-branch behavior into agent-runbook so every new enclosing folder
inherits it.

## Proposed outcome
One branch-policy paragraph, byte-identical in three places (cmp verified):
1. runbook `AGENTS.md` — work-copies section
2. enclosing `AGENTS.md` (live, this folder)
3. scaffold `new-enclosing-folder.sh` AGENTS heredoc (stamped into every new folder)
Text: every change to a `work/<repo>` checkout lands on a feature branch
(`feature/<unit-or-slug>`) created before the first edit; commit on the branch,
never main/master; merge to main is the operator's deliberate act (push + PR, or an
explicit local merge they request) — never an agent's own initiative. Per-repo
stricter rules stay repo-local; this is the floor.

## Proof obligations
1. three texts cmp-equal (work AGENTS vs enclosing AGENTS vs scaffold heredoc)
2. junk-build scaffold → stamped AGENTS.md carries the paragraph
3. dogfood proof: this session's work/agent-runbook changes live on
   `feature/prior-art-refresh-branch-policy`, branch created before first edit,
   zero commits on main this session
4. lifecycle gate 32/32 host + bash:3.2 docker (AGENTS heredoc touched by unit)
5. installer cutover: AGENTS marked block refreshed, doctor honest after

## Invariants
- the paragraph is one edit unit: change in all three places or none
- scaffold stamping carries it automatically (no post-scaffold hand-edit needed)

## Affected systems
- runbook AGENTS.md, scaffold AGENTS heredoc, live enclosing AGENTS.md, ROADMAP

## NOT-list
- No enforcement hook (comms/ owns hooks; policy text only in this unit)
- No branch-name linter, no CI wiring
- No retroactive rewrite of existing main history
- No per-repo rule overrides (repos may be stricter, never looser)
- No installer changes (AGENTS block refresh already exists)

## Open questions
None.