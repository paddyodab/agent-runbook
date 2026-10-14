# INTENT — preamble-01: the operator's opening ask as a stamped template

## Problem

The operator's opening ask for a session arrives in chat (lost at session end) or as a
hand-typed `intro.txt`/`preamble.txt` the operator adds to every session folder by hand.
Three of the last four sessions carry one as an informal convention. The ask is the
load-bearing WHY for a session — `conversation.md` and the handoff record conclusions,
never the original ask in the operator's own words — and a TUI is cramped for composing
it (files are comfortable to edit, reorder, link; the operator said this plainly).

## Proposed outcome

`preamble.txt` becomes a first-class, template-stamped protocol file:

1. `comms/templates/preamble.txt` — header + how-to-use comment; stamped EMPTY into
   every fresh session folder by `session-start.sh` (plain `cp`; no `{{DATE-SEQ}}`).
2. Conditional intro routing: when the stamped preamble has real content (any line
   beyond the template's own header + comment block), `session-start.sh`'s printed
   manifest lists it READ FIRST — the ask routes through the existing anti-over-read
   mechanism; an unfilled preamble stays silent.
3. Convention documented in the three homes: `comms/README.md` (rule + tree + row),
   the enclosing AGENTS.md block, the scaffold's embedded mirrors.
4. **Real bugfix found by this unit's junk lifecycle** (session-end.sh:159): the
   title-fill sed used `/` delimiters while `$SESS` is `<user>/<date-seq>` — every
   template-titled handoff (a folder created WITHOUT session-start, a README-documented
   path) died with `sed: unknown option to 's'` and never sealed. Pipe delimiters fix
   it.

## Proof obligations

- `prove-preamble.sh` (committed at `comms/prove-preamble.sh`): 8-assertion junk
  lifecycle — stamp byte-parity, silence-when-empty, READ-FIRST-when-filled (addenda
  preserved), seal-succeeds-with-preamble, unfilled-preamble-seals (never gated),
  README rows present, template intact. GREEN host + docker `bash:3.2`.
- Scaffold parity: build `new-enclosing-folder.sh` into a junk parent; `cmp` every
  protocol file (scripts, README, 3 templates, .gitignore, hook) byte-identical to
  live; AGENTS.md identical modulo the `<folder-slug>` header line; scaffolded
  session-start shows the READ FIRST notice on a filled preamble.
- Full lifecycle suite (`comms-lifecycle-test.sh`) green host + bash-3.2 (regression
  duty: the title-fix must not break the other eleven scenarios).
- Byte-parity of heredoc mirrors extracted from the scaffold file itself.

## Invariants

- An unfilled preamble never gates a seal, never appears in the intro.
- A filled preamble is never rewritten by any script (stamped empty; operator owns it).
- The original ask is append-only after the session starts (addenda fine).

## Affected systems

- live `comms/` (this enclosing folder): templates, session-start.sh, session-end.sh,
  README.md, AGENTS.md (folder root).
- scaffold mirror: `work/agent-runbook/scaffold/new-enclosing-folder.sh` (README +
  both scripts + preamble-template heredocs, AGENTS.md heredoc conventions paragraph).

## Bounded contexts

- **comms protocol** (scripts + templates + docs): owns stamp, detect, seal semantics.
- **scaffold mirror** (heredocs): derives from live, byte-parity-gated. Split so
  live-first editing never fights heredoc escaping; the `cmp` gate is the boundary
  contract (two homes, one truth — lesson 2026-09-08 #5 applied at design time).

## Constraints

- bash 3.2 portable (no mapfile/associative arrays; awk state machines, no sed -i).
- Staging-dir atomic scaffold; junk-parent proofs never touch live folders.
- No gate changes to session-end's completeness fence (preamble is never sealed).

## NOT-list

- No session-end completeness section for preamble (it must never block sealing).
- No auto-linking from conversation.md/handoff to preamble beyond the written
  trace-back convention (comments carry it; no machinery).
- No renaming of prior sessions' `intro.txt` files; the template name is canonical
  going forward only.
- No comms-sync/artifacts-sync changes (units 2/D untouched).

## Open questions

- (resolved with operator) name: `preamble.txt` over `intro.txt` — avoids colliding
  with the script's own "Session intro" term; canonical name for prior informal files.
- (resolved with operator) intro notice: yes, conditional READ FIRST routing.

## Next steps

- lifecycle suite host + bash-3.2; commit both tiers; offer push finish line.