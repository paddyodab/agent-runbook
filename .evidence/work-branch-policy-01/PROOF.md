# PROOF — work-branch-policy-01 (2026-10-14)

Mode: inline unit, no delegation. Documentation-contract unit; proofs are byte
comparisons + dogfooding + the standing gates.

## Result: PASS

| # | Obligation | Result |
| --- | --- | --- |
| 1 | three texts cmp-equal | PASS — work AGENTS.md L73-78 == enclosing AGENTS.md L47-52 == scaffold heredoc L1224-1229 (diff clean ×2) |
| 2 | junk build carries paragraph | PASS — /tmp/junk-hp5/junk-hp5/AGENTS.md contains "Branch policy: feature-branch work, never main." |
| 3 | dogfood | PASS — branch `feature/prior-art-refresh-branch-policy` created before first edit this session; unit changes commit to the branch; zero commits on main this session (`git log origin/main..main` unchanged) |
| 4 | lifecycle gate | PASS — 32/32 host + 32/32 docker bash:3.2 (scaffold AGENTS heredoc is stamped by the gate's junk builds) |
| 5 | installer cutover | PASS — see cutover note; doctor honest |

## Dogfood state (this session)
- work/agent-runbook: `feature/prior-art-refresh-branch-policy` holds
  scaffold/ROADMAP/AGENTS + evidence changes; main untouched at 2b6c213.
- The standalone checkout ~/Documents/GitHub/agent-runbook (same repo, same origin)
  still sits on main — it is not a work/ copy, no ticket ran against it.

## Files touched
- work/agent-runbook/AGENTS.md (work-copies section + new paragraph)
- scaffold/new-enclosing-folder.sh (AGENTS heredoc + same paragraph)
- enclosing AGENTS.md (live) — same paragraph
- ROADMAP.md — unit recorded

## Standing decision recorded
"Stricter repo rules stay repo-local" and "merge to main is the operator's
deliberate act" are now in the map (ROADMAP unit NOT-list), not just prose.