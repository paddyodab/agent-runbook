# INTENT — work-clone-source-01 (20261016-01)

## Problem
The work-copy convention never says where a `work/<repo>` clone comes FROM. An
agent honoring "clone it to a sibling `work/` folder" could lazily `cp -r` or
`git clone` from the local `prior-art/<repo>` checkout — a stale, possibly
diverged or dirty reference state — instead of the source. Operator ask
(preamble.txt 20261016-01): work-folder git clones must always come from the
source (GitHub); prior-art exists purely for ease of reference.

## Proposed outcome
The standing rule gains one explicit clause, consistent in every home:
"A work copy is always a fresh `git clone` from the repo's origin (GitHub) —
never a copy of or a clone from the `prior-art/` checkout; prior-art is
reference-only." Places touched:
1. runbook `AGENTS.md` marked block — Work-copies paragraph (installer source)
2. scaffold `new-enclosing-folder.sh` AGENTS heredoc — Work-copies paragraph
   (stamped into every new enclosing folder)
3. live enclosing `AGENTS.md` (this folder) — Standing-access-rules paragraph
4. live enclosing `README.md` + scaffold README heredoc + CONVENTION var —
   `work/` tree bullets name the clone source
5. ROADMAP.md unit row
6. kit regen from updated block (kit/omp/files/home/.omp/agent/AGENTS.md)

## Proof obligations
1. byte-parity: runbook AGENTS.md Work-copies paragraph == scaffold AGENTS
   heredoc paragraph (cmp); scaffold heredoc AGENTS == live enclosing
   AGENTS.md (slug-substituted cmp, prior-art-refresh-01 pattern)
2. junk-build scaffold → stamped AGENTS.md carries the clause
3. dogfood: this unit's changes commit on
   `feature/work-clone-source-01`, branch created before first edit
4. lifecycle gate green host + bash:3.2 docker (AGENTS heredoc touched)
5. installer cutover: install.sh refreshes the installed marked block; doctor
   honest after; kit regen == updated block

## Invariants
- the clause is one edit unit: all homes change in the same diff or none
- scaffold stamping carries it automatically
- no behavior change to any script (this is convention text only)

## Affected systems
- runbook AGENTS.md, scaffold AGENTS heredoc, live enclosing AGENTS.md, live
  enclosing README.md, scaffold README heredoc + CONVENTION, ROADMAP, kit payload

## NOT-list
- No script logic changes (scaffold/session scripts gain no branches)
- No enforcement hook or linter (convention text, like work-branch-policy-01)
- No retroactive re-clone of existing `work/` copies (existing checkouts stay;
  the rule binds NEW clones)
- No machine.md/machine.yml changes
- No prior-art refresh behavior change

## Open questions
None. "Source = GitHub" reads as: the repo's origin (which for every studied
repo is GitHub). Origin URL, not a hard-coded github.com host check — a repo
with a non-GitHub origin still clones from its origin. 