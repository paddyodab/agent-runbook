# PROOF — work-clone-source-01 (2026-10-16)

Mode: inline unit, no delegation. Documentation-contract unit (work-branch-policy-01
shape); proofs are byte comparisons + scaffold junk-build + the standing gates.

## Result: PASS

| # | Obligation | Result |
| --- | --- | --- |
| 1 | runbook AGENTS ↔ scaffold heredoc Work-copies paragraph parity | PASS — paragraph text identical (edit applied to both; scaffold AGENTS heredoc is the enclosing-folder AGENTS, whose Standing-access-rules paragraph carries the enclosing wording; junk-build stamp == heredoc, cmp clean) |
| 2 | scaffold AGENTS heredoc ↔ live enclosing AGENTS.md | PASS — `diff` clean (slug-substituted), incl. the new clause line pair |
| 3 | scaffold README heredoc ↔ live enclosing README | PASS — rendered with the scaffold's own substitution method (`eval` heredoc expansion, FOLDER/PURPOSE/CONVENTION) → `diff` clean |
| 4 | junk build carries the clause | PASS — /tmp/agent-runbook-junk AGENTS.md L44 + README.md L15 (tree bullet) + L47 (This-folder bullet) all carry it; stamped AGENTS == heredoc cmp clean |
| 5 | dogfood | PASS — branch `feature/work-clone-source-01` created before first edit; single commit `3252728`; main untouched |
| 6 | lifecycle gate | PASS — 33/33 host on live agent-runbook-next root; 33/33 host on junk build; bash:3.2 `bash -n` clean on scaffold + isolated CONVENTION var |
| 7 | installer + kit cutover | PASS — install.sh re-ran (block appended/refreshed); `--doctor` → "nothing missing, nothing drifted"; installed ~/.omp/agent/AGENTS.md block cmp-equal to repo block; kit payload re-locked to pure block regen (cmp clean) |

## The bash-3.2 trap this unit hit (finding)

The scaffold's `CONVENTION=$'...\n...'` ANSI-quoted assignment already carried ONE
escaped apostrophe (`folder\'s`). Adding the clause's `repo's` — a SECOND `\'` —
made `bash -n` fail on bash 3.2 (`syntax error near unexpected token '(', line 30`)
while host bash 5.3 still parsed it. Isolated minimal repros passed; only the real
line failed. Fix: the CONVENTION wording avoids the second apostrophe entirely
("a fresh git clone from its origin (GitHub)"). Heredoc homes (AGENTS/README) are
data — unaffected — so those keep the full wording incl. `repo's`.

## Wording matrix (deliberate)

- Bash-string home (CONVENTION var, both trees): "a fresh git clone from its origin
  (GitHub)" — apostrophe-free for bash 3.2.
- Heredoc/prose homes (AGENTS.md marked block, scaffold AGENTS heredoc, live
  enclosing AGENTS.md, README This-folder bullets): "a fresh `git clone` from the
  repo's source (origin on GitHub) — never a copy of, or a clone from, the
  `prior-art/` checkout; prior-art exists for ease of reference only."
- Rule content identical in every home: fresh clone, from origin/GitHub, never
  prior-art.

## Files touched
- work/agent-runbook/AGENTS.md (Work-copies paragraph)
- work/agent-runbook/scaffold/new-enclosing-folder.sh (AGENTS Standing-access-rules,
  README This-folder bullet, CONVENTION var)
- work/agent-runbook/ROADMAP.md (unit row)
- work/agent-runbook/kit/omp/files/home/.omp/agent/AGENTS.md (block regen)
- live agent-runbook-next AGENTS.md + README.md (back-synced same wording)
- .evidence/work-clone-source-01/ (INTENT.md + PROOF.md)